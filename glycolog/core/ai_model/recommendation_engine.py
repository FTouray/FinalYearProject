import joblib
import numpy as np

from ai_model.data_processing import preprocess_data


def load_models():
    """
    Load pretrained models from disk.
    """
    wellness_model = joblib.load("ai_model/model_weights/wellness_model.pkl")
    glucose_model = joblib.load("ai_model/model_weights/glucose_model.pkl")
    return wellness_model, glucose_model


def predict_wellness(wellness_model, data):
    """
    Predict the wellness score for a user based on the data.
    """
    X, _ = preprocess_data(data, target_column=None)  # No target column for prediction
    predictions = wellness_model.predict(X)
    return predictions


def predict_glucose(glucose_model, data):
    """
    Predict glucose levels based on questionnaire and log data.
    """
    X, _ = preprocess_data(data, target_column=None)
    predictions = glucose_model.predict(X)
    return predictions


def generate_recommendations(data):
    """
    Generate personalized recommendations based on glycaemic response, symptoms, and glucose levels.
    """
    recommendations = []

    # **Detect high glycaemic response meals**
    if data["glycaemic_response_score"].mean() > 5:
        recommendations.append(
            "Your body reacts strongly to high GI foods. Consider switching to low-GI alternatives."
        )

    # **Identify frequent glucose fluctuations**
    if data["glycaemic_variability"].mean() > 30:
        recommendations.append(
            "Your glucose levels fluctuate frequently. Adjust meal timing and portion sizes."
        )

    # **Detect post-meal glucose spikes**
    if data["post_meal_glucose_spike"].mean() > 50:
        recommendations.append(
            "Post-meal glucose spikes detected. Reduce high-carb intake or increase fiber intake."
        )

    # **Track skipped meals' impact**
    if data["meal_impact"].mean() > 50:
        recommendations.append(
            "Your skipped meals and high GI foods might be impacting glucose control."
        )

    return recommendations
