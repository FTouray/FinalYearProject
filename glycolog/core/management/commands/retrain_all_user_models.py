import pandas as pd
import joblib
import os
from django.db.models import Avg
from sklearn.ensemble import RandomForestClassifier
from sklearn.multioutput import MultiOutputClassifier
from django.core.management.base import BaseCommand
from django.utils.timezone import now, timedelta
from core.models import (
    CustomUser, QuestionnaireSession, SymptomCheck, GlucoseCheck,
    MealCheck, ExerciseCheck, GlucoseLog, PredictiveFeedback
)
from core.ml_utils import explain_predicted_symptoms, generate_trend_insights, SYMPTOMS 

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
        users = [CustomUser.objects.get(id=options['user_id'])] if options['user_id'] else CustomUser.objects.all()

        for user in users:
            self.stdout.write(f"\n👤 Processing user: {user.username}")
            self.handle_single_user(user, model_version)

    def handle_single_user(self, user, model_version):
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
            self.stdout.write(f"❌ Not enough data for {user.username} ({len(data)} entries)")
            return

        df = pd.DataFrame(data)
        X = df.drop(columns=SYMPTOMS)
        Y = df[SYMPTOMS]

        model = MultiOutputClassifier(RandomForestClassifier(n_estimators=100, random_state=42))
        model.fit(X, Y)

        os.makedirs("ml_models", exist_ok=True)
        model_path = f"ml_models/user_model_{user.id}.pkl"
        joblib.dump(model, model_path)
        self.stdout.write(f"✅ Model saved to {model_path}")

        explanations = explain_predicted_symptoms(user, model_path, n_sessions=3)
        shap_count = 0
        for result in explanations:
            if not PredictiveFeedback.objects.filter(user=user, insight=result['reason']).exists():
                PredictiveFeedback.objects.create(
                    user=user,
                    insight=result['reason'],
                    model_version=model_version,
                    feedback_type='shap'
                )
                shap_count += 1
                self.stdout.write(f"✅ Saved: {result['reason']}")
            else:
                self.stdout.write(f"⚠️ Skipped duplicate: {result['reason']}")

        self.stdout.write(f"📈 Total SHAP insights saved: {shap_count}")


        trend_texts = generate_trend_insights(user, df, sessions)
        trend_count = 0
        for text in trend_texts:
            if not PredictiveFeedback.objects.filter(user=user, insight=text).exists():
                PredictiveFeedback.objects.create(
                    user=user,
                    insight=text,
                    model_version=model_version,
                    feedback_type="trend"
                )
                trend_count += 1
                self.stdout.write(f"💡 Saved trend insight: {text}")
            else:
                self.stdout.write(f"⚠️ Skipped duplicate trend: {text}")

        self.stdout.write(self.style.SUCCESS(
            f"✅ Trained and saved predictive feedback for {user.username} — SHAP: {shap_count}, Trends: {trend_count}"
        ))
