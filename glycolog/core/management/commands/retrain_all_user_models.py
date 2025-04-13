import pandas as pd
import joblib
import os
import shap
from django.db.models import Avg
from sklearn.ensemble import RandomForestClassifier
from sklearn.multioutput import MultiOutputClassifier
from django.core.management.base import BaseCommand
from django.utils.timezone import now, timedelta
from core.models import (
    CustomUser, QuestionnaireSession, SymptomCheck, GlucoseCheck,
    MealCheck, ExerciseCheck, GlucoseLog, PredictiveFeedback
)

SYMPTOMS = [
    'Fatigue', 'Headaches', 'Dizziness', 'Thirst', 'Nausea', 'Blurred Vision',
    'Irritability', 'Sweating', 'Frequent Urination', 'Dry Mouth',
    'Slow Wound Healing', 'Weight Loss', 'Increased Hunger', 'Shakiness',
    'Hunger', 'Fast Heartbeat'
]

READABLE_PHRASES = {
    "glucose_level": "after higher glucose levels",
    "weighted_gi": "after high-GI meals",
    "skipped_meals": "after skipping meals",
    "exercise_duration": "with less exercise",
    "stress": "during stressful days",
    "avg_glucose_3d": "when 3-day glucose is high",
    "total_skipped_meals": "if meals were skipped recently",
    "hour_of_day": "later in the day",
    "day_of_week": "on weekends"
}

def parse_symptoms(symptom_data):
    if isinstance(symptom_data, dict):
        return {k.lower(): v for k, v in symptom_data.items()}
    elif isinstance(symptom_data, list):
        return {
            entry["symptom"].lower(): entry.get("severity", 1.0)
            for entry in symptom_data if isinstance(entry, dict) and "symptom" in entry
        }
    return {}

class Command(BaseCommand):
    help = 'Train enhanced user models with trends and generate personalized predictive feedback.'

    def add_arguments(self, parser):
        parser.add_argument('--user_id', type=int, help='Specify a user ID to retrain model for a single user')

    def handle(self, *args, **options):
        model_version = f"v{now().strftime('%Y%m%d%H%M')}"

        if options['user_id']:
            user = CustomUser.objects.get(id=options['user_id'])
            self.handle_single_user(user, model_version)
        else:
            for user in CustomUser.objects.all():
                self.handle_single_user(user, model_version)

    def handle_single_user(self, user, model_version):
        print(f"\n\U0001F464 Processing user: {user.username}")
        sessions = QuestionnaireSession.objects.filter(user=user).prefetch_related(
            'symptom_check', 'glucose_check', 'meal_check', 'exercise_check')

        data = []
        for session in sessions:
            symptom = session.symptom_check.first()
            glucose = session.glucose_check.first()
            meal = session.meal_check.first()
            exercise = session.exercise_check.first()

            if not all([symptom, glucose, meal, exercise]):
                continue

            symptoms_dict = parse_symptoms(symptom.symptoms)
            print(f"\U0001F9EA Session {session.id} symptoms: {symptoms_dict}")

            recent_glucose_logs = GlucoseLog.objects.filter(
                user=user, timestamp__gte=now() - timedelta(days=3))
            avg_glucose = recent_glucose_logs.aggregate(avg=Avg('glucose_level')).get('avg') or 0

            past_sessions = sessions.filter(created_at__lt=session.created_at)
            meals_skipped = sum(
                len(ms.meal_check.first().skipped_meals)
                for ms in past_sessions if ms.meal_check.exists()
            )

            entry = {
                "glucose_level": glucose.glucose_level,
                "weighted_gi": meal.weighted_gi,
                "skipped_meals": len(meal.skipped_meals),
                "exercise_duration": exercise.exercise_duration,
                "stress": int(symptom.stress or 0),
                "avg_glucose_3d": avg_glucose,
                "total_skipped_meals": meals_skipped,
                "hour_of_day": session.created_at.hour,
                "day_of_week": session.created_at.weekday(),
            }
            for sym in SYMPTOMS:
                entry[sym] = int(sym.lower() in symptoms_dict)
            data.append(entry)

        if len(data) < 10:
            print(f"❌ Not enough data for {user.username} ({len(data)} entries)")
            return

        df = pd.DataFrame(data)
        X = df.drop(columns=SYMPTOMS)
        Y = df[SYMPTOMS]

        model = MultiOutputClassifier(RandomForestClassifier(n_estimators=100, random_state=42))
        model.fit(X, Y)

        os.makedirs("ml_models", exist_ok=True)
        joblib.dump(model, f"ml_models/user_model_{user.id}.pkl")
        print(f"✅ Model saved to ml_models/user_model_{user.id}.pkl")

        shap_count = 0
        for j, symptom in enumerate(SYMPTOMS):
            sub_model = model.estimators_[j]
            explainer = shap.Explainer(sub_model, X)
            shap_values = explainer(X)

            for i, row in enumerate(X.to_dict(orient="records")):
                if Y.iloc[i][symptom] == 1:
                    shap_row = shap_values[i].values
                    top_features = sorted(
                        zip(X.columns, [float(v[0]) if hasattr(v, '__getitem__') and not isinstance(v, (float, int)) else float(v) for v in shap_row]),
                        key=lambda x: abs(x[1]),
                        reverse=True
                    )[:2]

                    readable = {
                        "glucose_level": "glucose level",
                        "weighted_gi": "meal glycaemic index",
                        "skipped_meals": "meals skipped",
                        "exercise_duration": "exercise duration",
                        "stress": "stress level",
                        "avg_glucose_3d": "3-day average glucose",
                        "total_skipped_meals": "past skipped meals"
                    }

                    readable = [READABLE_PHRASES.get(name, name) for name, _ in top_features]
                    feedback_text = f"{symptom.capitalize()} is more likely " + " and ".join(readable) + "."


                    if not PredictiveFeedback.objects.filter(user=user, insight=feedback_text).exists():
                        PredictiveFeedback.objects.create(
                            user=user,
                            insight=feedback_text,
                            model_version=model_version,
                            feedback_type='shap'
                        )
                        shap_count += 1
                        print(f"✅ Saved: {feedback_text}")
                    else:
                        print(f"⚠️ Skipped duplicate feedback: {feedback_text}")

        print("📊 Evaluating rule-based patterns...")
        trend_feedback = []

        if df['hour_of_day'].ge(20).sum() >= 3 and df[['Blurred Vision', 'Headaches', 'Irritability']].eq(1).any(axis=1).sum() >= 3:
            trend_feedback.append("Symptoms like blurred vision or headaches appear more frequently during late hours, indicating potential fatigue accumulation or screen overexposure.")

        if df['day_of_week'].ge(5).sum() >= 3 and df[SYMPTOMS].eq(1).any(axis=1).sum() >= 3:
            trend_feedback.append("Symptom reporting is elevated on weekends, which may be due to irregular routines, dietary changes, or altered activity levels.")

        if df['exercise_duration'].lt(10).sum() >= 3 and df[['Fatigue', 'Dizziness', 'Blurred Vision']].eq(1).any(axis=1).sum() >= 3:
            trend_feedback.append("Lack of regular exercise appears to be linked with increased symptoms like fatigue or dizziness, suggesting physical activity may offer protective benefits.")

        if df['exercise_duration'].ge(30).sum() >= 3 and df[SYMPTOMS].sum(axis=1).mean() < 5:
            trend_feedback.append("Regular exercise sessions (30+ minutes) are associated with fewer symptom reports, suggesting a protective effect.")

        if df['skipped_meals'].ge(2).sum() >= 3 and df[['Shakiness', 'Dizziness', 'Hunger']].eq(1).any(axis=1).sum() >= 3:
            trend_feedback.append("Hypoglycemic symptoms such as shakiness or hunger may be mitigated with consistent meal timing.")

        if df['avg_glucose_3d'].le(130).sum() >= 3 and df[SYMPTOMS].sum(axis=1).mean() < 5:
            trend_feedback.append("Stable average glucose levels (<=130) are associated with lower symptom frequency.")

        if df['weighted_gi'].gt(70).sum() >= 3 and df[['Thirst', 'Fatigue', 'Frequent Urination']].eq(1).any(axis=1).sum() >= 3:
            trend_feedback.append("Meals with high glycaemic index values may be contributing to symptom spikes, while lower GI foods could offer more stable outcomes.")

        if df['weighted_gi'].gt(70).sum() >= 3 and df['skipped_meals'].ge(2).sum() >= 3:
            trend_feedback.append("Combining high-GI meals with skipped meals tends to amplify symptoms; regular balanced meals may help stabilize wellness.")

        if df['stress'].eq(1).sum() >= 3 and df[['Irritability', 'Headaches', 'Fatigue']].eq(1).any(axis=1).sum() >= 3:
            trend_feedback.append("Stress shows a consistent link with symptoms like fatigue or irritability; mindfulness or relaxation could provide relief.")

        if df['avg_glucose_3d'].gt(150).sum() >= 3:
            trend_feedback.append("Persistent elevated glucose averages are observed and may coincide with symptom severity.")

        first_half = df.iloc[:len(df)//2][SYMPTOMS].sum(axis=1).mean()
        second_half = df.iloc[len(df)//2:][SYMPTOMS].sum(axis=1).mean()
        if second_half < first_half:
            trend_feedback.append("Recent entries suggest improvement; current habits might be contributing positively to your well-being.")

        sleep_issues = sessions.filter(symptom_check__sleep_hours__lt=5).count()
        if sleep_issues >= 3:
            trend_feedback.append("Limited sleep appears repeatedly and could be affecting your glucose stability and mood regulation.")

        long_gap_and_fatigue = ExerciseCheck.objects.filter(
            session__in=sessions,
            last_exercise_time__in=["More than 5 Days Ago", "I Don’t Remember"],
            post_exercise_feeling="Tired"
        ).count()
        if long_gap_and_fatigue >= 3:
            trend_feedback.append("Long intervals without exercise seem to lead to tiredness post-activity; regular movement may ease fatigue.")

        if not trend_feedback:
            trend_feedback.append("Your logging efforts are essential — each entry helps refine insights and surface new trends.")

        for text in trend_feedback:
            if not PredictiveFeedback.objects.filter(user=user, insight=text).exists():
                PredictiveFeedback.objects.create(
                    user=user,
                    insight=text,
                    model_version=model_version,
                    feedback_type="trend"
                )
                print(f"💡 Saved trend insight: {text}")

        self.stdout.write(self.style.SUCCESS(
            f"✅ Trained and saved predictive feedback for {user.username} — SHAP: {shap_count}, Trends: {len(trend_feedback)}"
        ))
