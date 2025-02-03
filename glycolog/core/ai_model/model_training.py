import os
import joblib
import pandas as pd
from sklearn.ensemble import RandomForestClassifier, GradientBoostingRegressor
from .utils import create_model_dir
from .data_processing import preprocess_data
from .feature_engineering import feature_engineering


def train_wellness_risk_model(data):
    """Predicts risk factors that lead to poor wellness."""
    print("Training Wellness Risk Model...")
    X, y = preprocess_data(data, target_column="wellness_score")

    if y is None:
        print("Skipping wellness model: 'wellness_score' missing.")
        return None

    model = RandomForestClassifier(n_estimators=200, max_depth=12, random_state=42)
    model.fit(X, y)

    create_model_dir()
    save_path = os.path.join(
        "core", "ai_model", "model_weights", "wellness_risk_model.pkl"
    )
    joblib.dump(model, save_path)
    print(f"Wellness Risk Model saved at: {save_path}")

    return model


def train_glucose_prediction_model(data):
    """Predicts glucose fluctuations based on meals, exercise, and symptoms."""
    print("Training Glucose Prediction Model...")
    X, y = preprocess_data(data, target_column="glucose_level")

    if y is None:
        print("Skipping glucose model: 'glucose_level' missing.")
        return None

    model = GradientBoostingRegressor(
        n_estimators=400, learning_rate=0.02, max_depth=6, random_state=42
    )
    model.fit(X, y)

    create_model_dir()
    save_path = os.path.join("core", "ai_model", "model_weights", "glucose_model.pkl")
    joblib.dump(model, save_path)
    print(f"Glucose Prediction Model saved at: {save_path}")

    return model


def train_exercise_impact_model(data):
    """Predicts how exercise influences glucose stability and energy levels."""
    print("Training Exercise Impact Model...")
    X, y = preprocess_data(data, target_column="exercise_impact")

    if y is None:
        print("Skipping exercise model: 'exercise_impact' missing.")
        return None

    model = GradientBoostingRegressor(
        n_estimators=200, learning_rate=0.01, max_depth=5, random_state=42
    )
    model.fit(X, y)

    create_model_dir()
    save_path = os.path.join("core", "ai_model", "model_weights", "exercise_model.pkl")
    joblib.dump(model, save_path)
    print(f"Exercise Impact Model saved at: {save_path}")

    return model


def train_meal_response_model(data):
    """Predicts how different meals impact glucose levels."""
    print("Training Meal Response Model...")
    X, y = preprocess_data(data, target_column="meal_impact")

    if y is None:
        print("Skipping meal model: 'meal_impact' missing.")
        return None

    model = GradientBoostingRegressor(n_estimators=150, learning_rate=0.05, max_depth=5, random_state=42)
    model.fit(X, y)

    create_model_dir()
    save_path = os.path.join("core", "ai_model", "model_weights", "meal_model.pkl")
    joblib.dump(model, save_path)
    print(f"Meal Response Model saved at: {save_path}")

    return model


def train_all_models(data):
    """Trains all AI models based on available data."""
    create_model_dir()
    data = feature_engineering(data)

    models = {
        "Wellness Risk Model": train_wellness_risk_model(data),
        "Glucose Prediction Model": train_glucose_prediction_model(data),
        "Exercise Impact Model": train_exercise_impact_model(data),
        "Meal Response Model": train_meal_response_model(data),
    }

    print("All models trained successfully!")
    return models
