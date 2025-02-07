import joblib
import pandas as pd
from collections import Counter
from .data_processing import preprocess_data
from .test_analysis import (
    analyze_sentiment,
    detect_extra_information,
    extract_common_words,
)

# Global variables to cache models for efficiency
GLUCOSE_MODEL = None
MEAL_MODEL = None
WELLNESS_RISK_MODEL = None


def load_models():
    """Load pretrained models from disk and cache them for efficiency."""
    global GLUCOSE_MODEL, MEAL_MODEL, WELLNESS_RISK_MODEL
    if GLUCOSE_MODEL is None or MEAL_MODEL is None or WELLNESS_RISK_MODEL is None:
        GLUCOSE_MODEL = joblib.load("ai_model/model_weights/glucose_model.pkl")
        MEAL_MODEL = joblib.load("ai_model/model_weights/meal_model.pkl")
        WELLNESS_RISK_MODEL = joblib.load(
            "ai_model/model_weights/wellness_risk_model.pkl"
        )
    return GLUCOSE_MODEL, MEAL_MODEL, WELLNESS_RISK_MODEL


def convert_glucose_units(glucose_value, preferred_unit="mg/dL"):
    """Convert glucose levels to the user's preferred unit."""
    if preferred_unit == "mmol/L":
        return round(glucose_value / 18, 2)  # Convert mg/dL to mmol/L
    return glucose_value  # Keep mg/dL as is


def predict_glucose(glucose_model, data, preferred_unit="mg/dL"):
    """Predict glucose levels and return predictions with confidence scores."""
    X, _ = preprocess_data(data, target_column=None)
    predictions = glucose_model.predict(X)
    return [
        {
            "predicted_glucose": convert_glucose_units(value, preferred_unit),
        }
        for value in predictions
    ]


def predict_meal_impact(meal_model, data):
    """Predicts how different meals impact glucose levels."""
    X, _ = preprocess_data(data, target_column=None)
    predictions = meal_model.predict(X)
    return [{"meal_impact_score": round(value, 2)} for value in predictions]


def predict_wellness_risk(wellness_model, data):
    """Predicts wellness risk based on symptoms, exercise, and glucose trends."""
    X, _ = preprocess_data(data, target_column=None)
    predictions = wellness_model.predict(X)
    return [{"wellness_risk_score": round(value, 2)} for value in predictions]


def generate_recommendations(data, all_users_data):
    """Generate AI-powered recommendations based on user trends and general trends."""
    recommendations = []

    # Meal Adjustments
    if data.get("meal_impact_score", 0) > 50:
        recommendations.append("Consider reducing high-GI meals to stabilize glucose.")

    # Glucose Adjustments
    if data.get("glucose_variability", 0) > 30:
        recommendations.append(
            "Your glucose fluctuates frequently. Try balanced meals."
        )

    # Wellness Insights
    if data.get("wellness_risk_score", 0) > 70:
        recommendations.append(
            "High risk detected! Prioritize sleep & stress management."
        )

    # Behavioral Pattern Insights
    if data.get("exercise_duration", 0) < 20 and data.get("glucose_level", 0) > 140:
        recommendations.append(
            "You tend to have high glucose levels when you don't exercise much. Consider increasing activity levels."
        )

    if (
        data.get("meal_impact_score", 0) > 50
        and data.get("glucose_variability", 0) > 30
    ):
        recommendations.append(
            "Your glucose variability is high after high-GI meals. Opt for more fiber and protein."
        )

    if data.get("sleep_hours", 0) < 6 and data.get("glucose_level", 0) > 140:
        recommendations.append(
            "Your glucose levels tend to rise when you get insufficient sleep. Try improving sleep quality."
        )

    if data.get("stress_level", 0) > 70 and data.get("glucose_level", 0) > 140:
        recommendations.append(
            "High stress seems to correlate with elevated glucose. Consider stress management techniques."
        )

    # General Population-Based Trends
    if not all_users_data.empty:
        avg_glucose = all_users_data["glucose_level"].mean()
        avg_meal_impact = all_users_data["meal_impact_score"].mean()
        avg_wellness_risk = all_users_data["wellness_risk_score"].mean()

        if data.get("glucose_level", 0) > avg_glucose:
            recommendations.append(
                "Your glucose levels are higher than the average user. This may indicate a need for dietary adjustments, increased physical activity, or better stress management."
            )
        if data.get("meal_impact_score", 0) > avg_meal_impact:
            recommendations.append(
                "Compared to most users, your meals have a greater impact on glucose levels. Try incorporating balanced macronutrients and fiber-rich foods."
            )
        if data.get("wellness_risk_score", 0) > avg_wellness_risk:
            recommendations.append(
                "Your wellness risk score is above the average user. Consider tracking sleep, hydration, and activity levels to improve overall health."
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
