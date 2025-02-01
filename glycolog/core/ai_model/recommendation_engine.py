import joblib
import pandas as pd
from collections import Counter
from ai_model.data_processing import preprocess_data
from ai_model.test_analysis import (
    analyze_sentiment,
    detect_extra_information,
    extract_common_words,
)


def load_models():
    # Load pretrained models from disk
    wellness_model = joblib.load("ai_model/model_weights/wellness_model.pkl")
    glucose_model = joblib.load("ai_model/model_weights/glucose_model.pkl")
    return wellness_model, glucose_model


def convert_glucose_units(glucose_value, preferred_unit="mg/dL"):
    # Convert glucose levels to the user's preferred unit
    # The database stores glucose levels in mg/dL
    if preferred_unit == "mmol/L":
        return round(glucose_value / 18, 2)  # Convert mg/dL to mmol/L
    return glucose_value  # Keep mg/dL as is


def predict_wellness(wellness_model, data):
    # Predict the wellness score for a user based on symptoms, stress, and exercise
    X, _ = preprocess_data(data, target_column=None)  # No target column for prediction
    predictions = wellness_model.predict(X)
    return predictions


def predict_glucose(glucose_model, data, preferred_unit="mg/dL"):
    # Predict glucose levels based on meals, symptoms, stress, and exercise
    # Convert the predicted glucose levels to the user’s preferred unit
    X, _ = preprocess_data(data, target_column=None)
    predictions = glucose_model.predict(X)
    return [
        convert_glucose_units(value, preferred_unit) for value in predictions
    ]  # Convert before returning


def generate_recommendations(data, preferred_unit="mg/dL"):
    # Generate personalized recommendations based on glycaemic response, symptoms, glucose levels, stress, and exercise
    recommendations = []

    data["glucose_level"] = data["glucose_level"].apply(
        lambda x: convert_glucose_units(x, preferred_unit)
    )

    # Glycaemic Response & Meal Impact
    if data.get("glycaemic_response_score", pd.Series()).mean() > 5:
        recommendations.append(
            "Your body reacts strongly to high GI foods. Consider switching to low-GI alternatives."
        )

    if data.get("meal_impact", pd.Series()).mean() > 50:
        recommendations.append(
            "Your skipped meals and high GI foods might be impacting glucose control. Try balanced meal timing."
        )

    if data.get("post_meal_glucose_spike", pd.Series()).mean() > 50:
        recommendations.append(
            "Post-meal glucose spikes detected. Reduce high-carb intake or increase fiber intake."
        )

    # Glucose Variability & Control
    if data.get("glucose_variability", pd.Series()).mean() > 30:
        recommendations.append(
            "Your glucose levels fluctuate frequently. Adjust meal timing and portion sizes."
        )

    if data.get("low_glucose_sessions", pd.Series()).mean() > 5:
        recommendations.append(
            "Frequent low glucose detected. Monitor carb intake and consider small, frequent meals."
        )

    # Symptoms & Health Monitoring
    if data.get("severe_symptom_correlation", pd.Series()).mean() > 0.5:
        recommendations.append(
            "Your symptoms may be affecting glucose. Track patterns and discuss with a healthcare provider."
        )

    if (
        data.get("frequent_symptoms", pd.Series())
        .explode()
        .value_counts()
        .get("Fatigue", 0)
        > 3
    ):
        recommendations.append(
            "Frequent fatigue detected. Ensure hydration, nutrition, and proper sleep."
        )

    # Exercise & Activity Adjustments
    if data.get("exercise_duration_avg", pd.Series()).mean() < 20:
        recommendations.append(
            "Your exercise duration is below the recommended 30 mins. Try increasing activity levels."
        )

    if data.get("exercise_glucose_stability", pd.Series()).mean() < -0.3:
        recommendations.append(
            "Exercise seems to help your glucose stability! Keep it up."
        )

    if (
        data.get("exercise_intensity_avg", pd.Series()).mean() > 2
        and data.get("post_exercise_feeling", pd.Series())
        .value_counts()
        .get("Tired", 0)
        > 3
    ):
        recommendations.append(
            "Your workouts may be too intense. Consider lowering intensity or ensuring post-exercise recovery."
        )

    # Stress & Sleep Adjustments
    if data.get("low_sleep_sessions", pd.Series()).mean() > 5:
        recommendations.append(
            "You frequently sleep less than 6 hours. Prioritize sleep for better glucose regulation."
        )

    if data.get("stress_correlation", pd.Series()).mean() > 0.5:
        recommendations.append(
            "Stress appears to impact your glucose. Try relaxation techniques or light exercise."
        )

    # Analyze the effect of exercise on glucose levels
    if "exercise_duration" in data.columns and "glucose_level" in data.columns:
        exercise_effect = data["exercise_duration"].corr(data["glucose_level"])
        if exercise_effect and exercise_effect < -0.4:
            recommendations.append(
                "Exercise seems to lower your glucose effectively. Maintain your activity routine."
            )

    # Analyze the effect of meals on glucose levels
    if "weighted_gi" in data.columns and "glucose_level" in data.columns:
        meal_effect = data["weighted_gi"].corr(data["glucose_level"])
        if meal_effect and meal_effect > 0.5:
            recommendations.append(
                "Your glucose levels tend to rise after high-GI meals. Consider lower GI alternatives."
            )

    # Extract Insights from User Notes
    if "notes" in data.columns:
        user_notes = data["notes"].dropna().tolist()
        extracted_keywords = extract_common_words(user_notes)
        extracted_sentiment = analyze_sentiment(user_notes)
        extracted_info = detect_extra_information(user_notes)

        if extracted_keywords:
            recommendations.append(
                f"User notes highlight concerns: {', '.join(extracted_keywords)}."
            )
        if extracted_sentiment == "Frustration or Negative Sentiment":
            recommendations.append(
                "Your notes indicate frustration. Consider adjusting routine or consulting an expert."
            )
        if extracted_info:
            recommendations.extend(extracted_info)

    return recommendations
