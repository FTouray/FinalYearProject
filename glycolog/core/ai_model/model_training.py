import joblib
from sklearn.ensemble import RandomForestClassifier, GradientBoostingRegressor
from ai_model.data_processing import preprocess_data


def train_wellness_model(data):
    """
    Train a classification model to predict user wellness based on glycaemic response, glucose levels, symptoms, stress, and exercise.
    """
    # Include new features such as symptoms severity, stress, and exercise impact
    X, y = preprocess_data(data, target_column="wellness_score")

    model = RandomForestClassifier(n_estimators=200, max_depth=12, random_state=42)
    model.fit(X, y)

    joblib.dump(model, "ai_model/model_weights/wellness_model.pkl")
    return model


def train_glucose_model(data):
    """
    Train a regression model to predict glucose levels based on meals, glycaemic response, exercise, and symptoms.
    """
    X, y = preprocess_data(data, target_column="glucose_level")

    model = GradientBoostingRegressor(
        n_estimators=400, learning_rate=0.02, max_depth=6, random_state=42
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
