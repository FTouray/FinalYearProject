from core.models import GlucoseLog, GlucoseCheck
from datetime import datetime, timedelta
from django.utils.timezone import now
from prophet import Prophet
import pandas as pd

def fetch_user_glucose_data(user):
    logs = GlucoseLog.objects.filter(user=user).values("timestamp", "glucose_level")
    checks = GlucoseCheck.objects.filter(session__user=user).values("timestamp", "glucose_level")

    all_data = list(logs) + list(checks)
    if not all_data:
        return None

    df = pd.DataFrame(all_data)
    df = df.dropna()
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

    model = Prophet()
    model.fit(df)

    now_rounded = datetime.now().replace(minute=0, second=0, microsecond=0)

    future_times = [now_rounded + timedelta(hours=2 * i) for i in range(1, future_hours + 1)]
    future = pd.DataFrame({'ds': future_times})

    forecast = model.predict(future)
    predictions = forecast[['ds', 'yhat', 'yhat_lower', 'yhat_upper']]

    return {
        "status": "success",
        "predictions": predictions.to_dict(orient="records")
    }
