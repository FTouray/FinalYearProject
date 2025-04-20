from core.models import GlucoseLog, GlucoseCheck
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

    periods = future_hours // 2
    future = model.make_future_dataframe(periods=future_hours, freq='2H')
    forecast = model.predict(future)

    # Format output
    predictions = forecast[['ds', 'yhat', 'yhat_lower', 'yhat_upper']].tail(periods)
    return {
        "status": "success",
        "predictions": predictions.to_dict(orient="records")
    }
