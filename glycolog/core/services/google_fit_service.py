from datetime import datetime, timedelta
import os
import time
from django.conf import settings
from googleapiclient.discovery import build
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from django.utils.timezone import now
from core.models import CustomUserToken, FitnessActivity, CustomUser, GlucoseLog
import logging
from core.ai_services import generate_health_trends, generate_ai_recommendation

logger = logging.getLogger(__name__)
GOOGLE_CLIENT_SECRET_FILE = os.path.join(settings.BASE_DIR, "config", "client_secret.json")

# **Google Fit Activity Type Mapping**
ACTIVITY_TYPE_MAP = {
    8: "Running",
    7: "Walking",
    1: "Biking",
    82: "Swimming",
    84: "Strength Training",
    94: "Walking",
    102: "Yoga",
    74: "Sleeping",
    75: "Light Sleep",
    76: "Deep Sleep",
    77: "REM Sleep",
}

def get_google_fit_credentials(user):
    """Retrieve Google Fit credentials for a user."""
    user_token = CustomUserToken.objects.filter(user=user).first()
    if not user_token:
        logger.warning(f"No Google Fit token found for user {user.username}")
        return None

    creds = Credentials(
        token=user_token.token,
        refresh_token=user_token.refresh_token,
        token_uri=user_token.token_uri,
        client_id=user_token.client_id,
        client_secret=user_token.client_secret,
        scopes=user_token.scopes.split(","),
    )

    if creds.expired and creds.refresh_token:
        try:
            creds.refresh(Request())
            # Save updated token in DB
            user_token.token = creds.token
            user_token.save()
        except Exception as e:
            logger.error(f"Error refreshing Google Fit token for {user.username}: {e}")
            return None

    return creds

def fetch_fitness_data(user):
    """Fetch and process fitness-related data from Google Fit for a user."""
    creds = get_google_fit_credentials(user)
    if not creds:
        return "No fitness data available."

    fitness_service = build("fitness", "v1", credentials=creds)

    now_millis = int(time.time() * 1000)
    yesterday_millis = now_millis - (24 * 60 * 60 * 1000)
    
    # Fetch health data
    steps = fetch_step_count(fitness_service, yesterday_millis, now_millis)
    activities, last_activity_time = fetch_activity_sessions(fitness_service, user, yesterday_millis, now_millis)
    total_sleep_hours = fetch_sleep_data(fitness_service, yesterday_millis, now_millis)
    avg_heart_rate = fetch_heart_rate_data(fitness_service, yesterday_millis, now_millis)
    latest_glucose, glucose_unit = fetch_latest_glucose_level(user)

    # Update last activity time
    update_last_activity_time(user, last_activity_time)

    # Generate AI insights
    generate_health_trends(user=user, period_type="weekly")
    generate_health_trends(user=user, period_type="monthly")

    return {
        "steps": steps,
        "activities": activities if activities else "No activity data.",
        "sleep_hours": total_sleep_hours,
        "average_heart_rate": avg_heart_rate if avg_heart_rate else "No heart rate data.",
        "latest_glucose_level": latest_glucose if latest_glucose else "No recent glucose data.",
        "glucose_unit": glucose_unit
    }
        
    
def fetch_all_users_fitness_data():
    """Fetch and update Google Fit data for all users."""
    users = CustomUser.objects.all()
    for user in users:
        fetch_fitness_data(user)
    logger.info("Google Fit data synced for all users.")


def fetch_step_count(fitness_service, start_time, end_time):
    """Fetch step count from Google Fit."""
    try:
        step_dataset = fitness_service.users().dataset().aggregate(
            userId="me",
            body={
                "aggregateBy": [{"dataTypeName": "com.google.step_count.delta"}],
                "bucketByTime": {"durationMillis": 86400000},
                "startTimeMillis": start_time,
                "endTimeMillis": end_time,
            }
        ).execute()

        return sum(
            point["value"][0]["intVal"]
            for bucket in step_dataset.get("bucket", [])
            for dataset in bucket.get("dataset", [])
            for point in dataset.get("point", [])
        )
    except Exception as e:
        logger.error(f"Error fetching step count: {e}")
        return None

def fetch_activity_sessions(fitness_service, user, start_time, end_time):
    """Fetch and store activity sessions from Google Fit."""
    try:
        sessions_result = fitness_service.users().sessions().list(userId="me").execute()
        sessions = sessions_result.get("session", [])

        last_activity_time = None
        activity_summary = []

        for session in sessions:
            activity_type = session.get("activityType")
            start_time_dt = datetime.fromtimestamp(int(session.get("startTimeMillis")) / 1000)
            end_time_dt = datetime.fromtimestamp(int(session.get("endTimeMillis")) / 1000)
            duration_minutes = (end_time_dt - start_time_dt).total_seconds() / 60
            activity_name = ACTIVITY_TYPE_MAP.get(activity_type, "Unknown Activity")

            if not last_activity_time or start_time_dt > last_activity_time:
                last_activity_time = start_time_dt

            exists = FitnessActivity.objects.filter(
                user=user, start_time=start_time_dt, end_time=end_time_dt, activity_type=activity_name
            ).exists()

            if not exists:
                FitnessActivity.objects.create(
                    user=user,
                    activity_type=activity_name,
                    start_time=start_time_dt,
                    end_time=end_time_dt,
                    duration_minutes=duration_minutes,
                )

            activity_summary.append(f"{activity_name} from {start_time_dt} to {end_time_dt}")

        return "\n".join(activity_summary), last_activity_time
    except Exception as e:
        logger.error(f"Error fetching activity sessions: {e}")
        return None, None

def fetch_sleep_data(fitness_service, start_time, end_time):
    """Fetch total sleep hours from Google Fit."""
    try:
        sleep_dataset = fitness_service.users().dataset().aggregate(
            userId="me",
            body={
                "aggregateBy": [{"dataTypeName": "com.google.sleep.segment"}],
                "bucketByTime": {"durationMillis": 86400000},
                "startTimeMillis": start_time,
                "endTimeMillis": end_time,
            }
        ).execute()

        return sum(
            (datetime.fromtimestamp(int(point["endTimeNanos"]) / 1e9) -
             datetime.fromtimestamp(int(point["startTimeNanos"]) / 1e9)).total_seconds() / 3600
            for bucket in sleep_dataset.get("bucket", [])
            for dataset in bucket.get("dataset", [])
            for point in dataset.get("point", [])
        )
    except Exception as e:
        logger.error(f"Error fetching sleep data: {e}")
        return None

def fetch_heart_rate_data(fitness_service, start_time, end_time):
    """Fetch average heart rate from Google Fit."""
    try:
        heart_rate_dataset = fitness_service.users().dataset().aggregate(
            userId="me",
            body={
                "aggregateBy": [{"dataTypeName": "com.google.heart_rate.bpm"}],
                "bucketByTime": {"durationMillis": 86400000},
                "startTimeMillis": start_time,
                "endTimeMillis": end_time,
            }
        ).execute()

        heart_rates = [
            point["value"][0]["fpVal"]
            for bucket in heart_rate_dataset.get("bucket", [])
            for dataset in bucket.get("dataset", [])
            for point in dataset.get("point", [])
        ]

        return sum(heart_rates) / len(heart_rates) if heart_rates else None
    except Exception as e:
        logger.error(f"Error fetching heart rate data: {e}")
        return None

def fetch_latest_glucose_level(user):
    """Fetch the latest glucose level from the database and convert units if necessary."""
    latest_glucose = GlucoseLog.objects.filter(user=user).order_by("-timestamp").first()
    if latest_glucose:
        glucose_level = latest_glucose.glucose_level
        unit = latest_glucose.glucose_unit

        # Convert mg/dL to mmol/L if needed
        if unit == "mg/dL":
            glucose_level = round(glucose_level / 18, 2)
            unit = "mmol/L"

        return glucose_level, unit
    return None, None

def update_last_activity_time(user, last_activity_time):
    """Update last recorded activity time for inactivity tracking."""
    if last_activity_time:
        FitnessActivity.objects.filter(user=user).update(last_activity_time=last_activity_time)
