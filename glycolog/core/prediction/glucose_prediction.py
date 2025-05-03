import os
import joblib
import pandas as pd
from datetime import datetime, timedelta
from django.utils.timezone import now
from prophet import Prophet
from core.models import GlucoseLog, GlucoseCheck

def fetch_user_glucose_data(user):
    logs = GlucoseLog.objects.filter(user=user).values("timestamp", "glucose_level")
    checks = GlucoseCheck.objects.filter(session__user=user).values("timestamp", "glucose_level")

    all_data = list(logs) + list(checks)
    if not all_data:
        return None

    df = pd.DataFrame(all_data).dropna()
    df = df.rename(columns={"timestamp": "ds", "glucose_level": "y"})
    df["ds"] = pd.to_datetime(df["ds"]).dt.tz_localize(None)
    df = df.sort_values("ds")
    df = df[df["ds"] > (now().replace(tzinfo=None) - pd.Timedelta(days=90))]

    return df if len(df) >= 10 else None

def predict_glucose(user, future_hours):
    df = fetch_user_glucose_data(user)
    if df is None:
        return {
            "status": "insufficient_data",
            "message": "Not enough historical glucose data to generate predictions."
        }

    model_path = f"ml_models/user_model_{user.id}.pkl"
    if os.path.exists(model_path):
        try:
            model = joblib.load(model_path)
            recent_features = df.tail(1).drop(columns=["ds"])
            prediction = model.predict(recent_features)
            return {
                "status": "success",
                "prediction_source": "user_model",
                "predictions": prediction.tolist()
            }
        except Exception as e:
            return {
                "status": "error",
                "message": f"Failed to load personalized model: {str(e)}"
            }

    # Fallback to Prophet
    prophet_model = Prophet()
    prophet_model.fit(df)
    now_rounded = datetime.now().replace(minute=0, second=0, microsecond=0)
    future_times = [now_rounded + timedelta(hours=2 * i) for i in range(1, future_hours + 1)]
    future = pd.DataFrame({'ds': future_times})
    forecast = prophet_model.predict(future)
    predictions = forecast[['ds', 'yhat', 'yhat_lower', 'yhat_upper']]

    return {
        "status": "success",
        "prediction_source": "prophet",
        "predictions": predictions.to_dict(orient="records")
    }
