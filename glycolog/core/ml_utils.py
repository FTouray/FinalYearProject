from django.utils.timezone import now
from core.models import ExerciseCheck, GlucoseLog, MealCheck, QuestionnaireSession
import pandas as pd
import shap
import joblib
import os
from django.db.models import Avg
from datetime import timedelta

SYMPTOMS = [
    'Fatigue', 'Headaches', 'Dizziness', 'Thirst', 'Nausea', 'Blurred Vision',
    'Irritability', 'Sweating', 'Frequent Urination', 'Dry Mouth',
    'Slow Wound Healing', 'Weight Loss', 'Increased Hunger', 'Shakiness',
    'Hunger', 'Fast Heartbeat'
]

EXPLANATION_LABELS = {
    "glucose_level": "glucose level",
    "weighted_gi": "meal glycaemic index",
    "skipped_meals": "meals skipped",
    "exercise_duration": "exercise duration",
    "stress": "stress level",
    "avg_glucose_3d": "3-day average glucose",
    "total_skipped_meals": "past skipped meals",
}

def explain_predicted_symptoms(user, model_path, n_sessions=3):
    if not os.path.exists(model_path):
        return []

    try:
        model = joblib.load(model_path)
        sessions = QuestionnaireSession.objects.filter(
            user=user, completed=True
        ).order_by("-created_at")[:n_sessions]

        results = []
        reason_symptom_map = {}

        for session in sessions:
            symptom = session.symptom_check.first()
            glucose = session.glucose_check.first()
            meal = session.meal_check.first()
            exercise = session.exercise_check.first()

            if not all([symptom, glucose, meal, exercise]):
                continue

            # Parse symptoms into a dictionary
            feature_dict = {
                "glucose_level": glucose.glucose_level,
                "weighted_gi": meal.weighted_gi,
                "skipped_meals": len(meal.skipped_meals),
                "exercise_duration": exercise.exercise_duration,
                "stress": int(symptom.stress or 0),
                "avg_glucose_3d": GlucoseLog.objects.filter(
                    user=user, timestamp__gte=session.created_at - timedelta(days=3)
                ).aggregate(avg=Avg("glucose_level")).get("avg") or 0,
                "total_skipped_meals": MealCheck.objects.filter(
                    session__user=user, created_at__lt=session.created_at
                ).exclude(skipped_meals=[]).count(),
                "hour_of_day": session.created_at.hour,
                "day_of_week": session.created_at.weekday(),
            }

            input_df = pd.DataFrame([feature_dict])
            predictions = model.predict(input_df)

            # Generate explanations for each predicted symptom
            for i, symptom_name in enumerate(SYMPTOMS):
                if int(predictions[0][i]) == 1:
                    sub_model = model.estimators_[i]
                    explainer = shap.Explainer(sub_model, input_df) 
                    shap_values = explainer(input_df) 
                    shap_row = shap_values[0].values[0].tolist() 

                    top_features = sorted(
                        zip(input_df.columns, shap_row),
                        key=lambda x: abs(x[1]),
                        reverse=True
                    )[:2]

                    reasons = []
                    for name, val in top_features:
                        if name == "hour_of_day":
                            reasons.append("later in the day" if val > 0 else "earlier in the day")
                        elif name == "day_of_week":
                            reasons.append("on weekends" if val > 0 else "on weekdays")
                        else:
                            direction = "higher" if val > 0 else "lower"
                            label = EXPLANATION_LABELS.get(name, name)
                            reasons.append(f"{direction} {label}")

                    reasons_key = tuple(sorted(reasons))
                    reason_symptom_map.setdefault(reasons_key, []).append(symptom_name)

        # Format grouped explanations
        for reasons_key, symptom_names in reason_symptom_map.items():
            seen = set()
            unique_symptoms = []
            for s in symptom_names:
                if s not in seen:
                    seen.add(s)
                    unique_symptoms.append(s)
                    
            if len(unique_symptoms) == 1:
                symptom_text = unique_symptoms[0].lower()
            else:
                symptom_text = ", ".join(sym.lower() for sym in unique_symptoms[:-1])
                symptom_text += f" and {unique_symptoms[-1].lower()}"

            reason_text = (
                f"You might feel {symptom_text} because you had "
                + " and ".join(reasons_key)
                + ". These symptoms often appear for you when these factors are present."
            )
            results.append({"symptom": None, "reason": reason_text})

        return results

    except Exception as e:
        return [{"symptom": "Error", "reason": f"Model failed: {str(e)}"}]



def generate_trend_insights(user, df, sessions):
    from core.models import PredictiveFeedback

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

    return trend_feedback
