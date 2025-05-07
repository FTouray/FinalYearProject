from django.conf import settings
from django.utils.timezone import now
from core.models import ExerciseCheck, GlucoseLog, MealCheck, QuestionnaireSession
import pandas as pd
import shap
import joblib
import os
from django.db.models import Avg, Count
from datetime import timedelta
from collections import defaultdict
import numpy as np 
import calendar

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
    "hour_of_day": "time of day",
    "day_of_week": "day of the week"
}

MODIFIABLE_FACTORS = {
    "glucose_level", "weighted_gi", "skipped_meals", "exercise_duration", "stress"
}

# Thresholds for interpretation
GLUCOSE_THRESHOLDS = {
    "low": 70,
    "high": 140
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

def convert_glucose(val, unit):
    return val / 18.0 if unit == 'mmol/L' else val

def interpret_glucose(val):
    if val < GLUCOSE_THRESHOLDS["low"]:
        return f"which is considered low (hypoglycemic)"
    elif val > GLUCOSE_THRESHOLDS["high"]:
        return f"which is considered high (hyperglycemic)"
    else:
        return f"which is within the normal range"
    

def weekday_label(avg_val):
    day_idx = int(round(avg_val)) % 7  # ensures 0–6
    return calendar.day_name[day_idx]

def interpret_feature(feature, val, symptom, unit='mg/dL'):
    val = float(val)

    if feature in {"glucose_level", "avg_glucose_3d"}:
        converted = convert_glucose(val, unit)
        unit_label = "mmol/L" if unit == 'mmol/L' else "mg/dL"
        label = f"Glucose was around {converted:.1f} {unit_label}"

        if val < GLUCOSE_THRESHOLDS["low"]:
            return f"{label}, which is low. Consider snacks or reviewing insulin timing."
        elif val > GLUCOSE_THRESHOLDS["high"]:
            return f"{label}, which is high. Watch carbs or consult your care team."
        else:
            return f"{label}, within the normal range. Keep up the consistency!"

    elif feature == "weighted_gi":
        if val > 70:
            return f"Meals had a high glycaemic index (avg: {val:.1f}), which can cause sugar spikes. Try switching to lower-GI foods."
        elif val < 50:
            return f"Meals were mostly low GI (avg: {val:.1f}), which helps stabilize energy — great job!"
        else:
            return f"Meals had a moderate GI (avg: {val:.1f}). Keep watching how different foods affect you."

    elif feature == "skipped_meals" and val >= 2:
        return f"Skipped meals were frequent (avg: {val:.1f}/day), which could lead to crashes or hunger swings."

    elif feature == "exercise_duration":
        if val < 15:
            return f"Activity was very low (avg: {val:.1f} mins). Even light walks may help reduce symptoms."
        elif val >= 30:
            return f"Activity was high (avg: {val:.1f} mins). If symptoms follow exercise, consider lighter sessions or more recovery."
        else:
            return f"Moderate activity (avg: {val:.1f} mins) logged. Track if symptom timing links to movement."

    elif feature == "stress" and val >= 2:
        return f"Stress was elevated (avg: {val:.1f}). Try stress-reduction strategies — even 5-minute breaks help."

    elif feature == "hour_of_day":
        return f"Symptom was mostly logged around {val:.1f}h. Consider patterns in your routine at that time."

    elif feature == "day_of_week":
        return f"Often occurs on {weekday_label(val)}s. Think about weekly cycles that might influence this."

    else:
        return f"{EXPLANATION_LABELS.get(feature, feature).capitalize()} averaged {val:.1f}. Review if it could relate to your symptoms."


def explain_symptom_causes(user, n_sessions=30):
    import logging
    logging.basicConfig(level=logging.DEBUG)

    model_path = os.path.join(settings.BASE_DIR, "ml_models", f"user_model_{user.id}.pkl")
    meta_path = os.path.join(settings.BASE_DIR, "ml_models", f"user_model_{user.id}_meta.pkl")

    if not os.path.exists(model_path) or not os.path.exists(meta_path):
        logging.warning(f"🚫 Model or meta file not found for user {user.id}")
        return []

    try:
        models = joblib.load(model_path)  # symptom -> classifier
        trained_symptoms = joblib.load(meta_path)
        logging.debug(f"🧠 Trained symptoms: {trained_symptoms}")

        sessions = QuestionnaireSession.objects.filter(user=user, completed=True).order_by("-created_at")[:n_sessions]
        logging.debug(f"📊 Found {len(sessions)} sessions")

        if not sessions:
            return [{"symptom": "No data", "reason": "Not enough recent symptom logs to analyze."}]

        symptom_data = defaultdict(list)
        all_dates = defaultdict(list)

        for session in sessions:
            symptom = session.symptom_check.first()
            glucose = session.glucose_check.first()
            meal = session.meal_check.first()
            exercise = session.exercise_check.first()

            if not all([symptom, glucose, meal, exercise]):
                logging.debug(f"⚠️ Skipping incomplete session {session.id}")
                continue

            reported_symptoms = parse_symptoms(symptom.symptoms)
            if not reported_symptoms:
                logging.debug(f"⚠️ No symptoms found in session {session.id}")
                continue

            created_at = session.created_at
            start_time = created_at - timedelta(days=3)
            avg_glucose = GlucoseLog.objects.filter(
                user=user, timestamp__range=(start_time, created_at)
            ).aggregate(avg=Avg("glucose_level"))["avg"] or glucose.glucose_level

            features = {
                "glucose_level": glucose.glucose_level,
                "weighted_gi": meal.weighted_gi,
                "skipped_meals": len(meal.skipped_meals),
                "exercise_duration": exercise.exercise_duration,
                "stress": int(symptom.stress or 0),
                "avg_glucose_3d": avg_glucose,
                "total_skipped_meals": 0,
                "hour_of_day": created_at.hour,
                "day_of_week": created_at.weekday(),
            }

            for sym in trained_symptoms:
                if sym.lower() in reported_symptoms:
                    symptom_data[sym].append(features)
                    all_dates[sym].append(created_at.date())

        # Check which symptoms were reported in the last 3 sessions
        recent_sessions = sessions[:3]
        recent_symptoms = set()
        for session in recent_sessions:
            symptom = session.symptom_check.first()
            if symptom:
                parsed = parse_symptoms(symptom.symptoms)
                recent_symptoms.update(s.capitalize() for s in parsed.keys())

        results = []
        today = now().date()

        for symptom_name in trained_symptoms:
            if symptom_name not in recent_symptoms:
                logging.debug(f"⏭ Skipping {symptom_name}: not reported in last 3 sessions")
                continue

            feature_list = symptom_data.get(symptom_name, [])
            if not feature_list:
                logging.debug(f"⏭ Skipping {symptom_name}: no data")
                continue

            X_df = pd.DataFrame(feature_list)
            model = models.get(symptom_name)
            if not model:
                logging.warning(f"⚠️ No model found for {symptom_name}")
                continue

            explainer = shap.TreeExplainer(model)
            shap_vals = explainer.shap_values(X_df)

            if isinstance(shap_vals, list):
                shap_matrix = shap_vals[1] if len(shap_vals) > 1 else shap_vals[0]
            elif shap_vals.ndim == 3 and shap_vals.shape[2] == 2:
                shap_matrix = shap_vals[:, :, 1]
            elif shap_vals.ndim == 3 and shap_vals.shape[0] == 2 and shap_vals.shape[1] == len(X_df):
                shap_matrix = shap_vals[1]
            else:
                shap_matrix = shap_vals

            if shap_matrix.shape != X_df.shape:
                logging.error(f"❌ SHAP matrix mismatch for {symptom_name}: {shap_matrix.shape} vs {X_df.shape}")
                continue

            avg_shap = pd.DataFrame(abs(shap_matrix), columns=X_df.columns).mean().sort_values(ascending=False)

            explanations = []
            for feature in avg_shap.head(3).index:
                val = X_df[feature].mean()
                explanation = interpret_feature(feature, val, symptom_name.lower())
                explanations.append(explanation)

            symptom_count = len(all_dates[symptom_name])
            recent = sum(1 for d in all_dates[symptom_name] if (today - d).days <= 14)
            earlier = sum(1 for d in all_dates[symptom_name] if (today - d).days > 14)

            trend_note = ""
            if recent > earlier:
                trend_note = "This symptom has increased in frequency recently."
            elif recent < earlier:
                trend_note = "You've reported this symptom less often in the past two weeks."

            behavior_trigger = ""
            if not ExerciseCheck.objects.filter(session__created_at__gte=now() - timedelta(days=5)).exists():
                behavior_trigger = "You haven't logged any exercise in the past 5 days."

            full_reason = (
                f"{symptom_name} may be triggered by "
                + ", ".join(e.replace("Your", "").replace("This symptom was", "logged") for e in explanations)
                + (f" {trend_note}" if trend_note else "")
                + (f" {behavior_trigger}" if behavior_trigger else "")
            )

            results.append({
                "symptom": symptom_name,
                "reason": full_reason
            })
            logging.debug(f"✅ Explanation for {symptom_name}: {full_reason}")

        return results

    except Exception as e:
        logging.exception(f"🔥 Fatal model-level exception for user {user.id}")
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

    # Dynamic trend deltas
    midpoint = len(df) // 2
    if midpoint >= 3:
        first_half = df.iloc[:midpoint]
        second_half = df.iloc[midpoint:]

        for col in ['skipped_meals', 'weighted_gi', 'stress', 'exercise_duration', 'avg_glucose_3d']:
            delta = second_half[col].mean() - first_half[col].mean()
            if col == 'skipped_meals' and delta < -0.5:
                trend_feedback.append("You’ve reduced skipped meals recently. This could be helping stabilize hunger or glucose-related symptoms.")
            elif col == 'stress' and delta < -0.5:
                trend_feedback.append("Reported stress levels are decreasing, which may be easing symptoms like fatigue or irritability.")
            elif col == 'exercise_duration' and delta > 5:
                trend_feedback.append("Your recent increase in physical activity may be supporting better symptom control.")
            elif col == 'weighted_gi' and delta < -5:
                trend_feedback.append("Your recent meals have had a lower glycaemic index, which may help prevent spikes in fatigue or thirst.")
            elif col == 'avg_glucose_3d' and delta < -10:
                trend_feedback.append("Your 3-day average glucose levels have come down, which may reduce symptom intensity.")

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
