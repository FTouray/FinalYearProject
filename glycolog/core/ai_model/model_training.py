import joblib
from sklearn.ensemble import RandomForestClassifier
from sklearn.ensemble import GradientBoostingRegressor

from ai_model.data_processing import preprocess_data


def train_wellness_model(data):
    """
    Train a classification model to predict user wellness based on glycaemic response, glucose, symptoms, and exercise.
    """
    # Include Glycaemic Response Score in training
    X, y = preprocess_data(data, target_column="wellness_score")

    model = RandomForestClassifier(n_estimators=150, max_depth=10, random_state=42)
    model.fit(X, y)

    joblib.dump(model, "ai_model/model_weights/wellness_model.pkl")
    return model


def train_glucose_model(data):
    """
    Train a regression model to predict glucose levels based on meals, glycaemic response, and symptoms.
    """
    X, y = preprocess_data(data, target_column="glucose_level")

    model = GradientBoostingRegressor(
        n_estimators=300, learning_rate=0.03, max_depth=6, random_state=42
    )
    model.fit(X, y)

    joblib.dump(model, "ai_model/model_weights/glucose_model.pkl")
    return model


def train_all_models(questionnaire_data):
    """
    Trains both wellness and glucose models with the latest data.
    """
    wellness_model = train_wellness_model(questionnaire_data)
    glucose_model = train_glucose_model(questionnaire_data)

    # Log retraining success
    print("Models retrained successfully!")
    return wellness_model, glucose_model
