from datetime import datetime
import time
from googleapiclient.discovery import build
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from django.utils.timezone import now
from core.models import CustomUserToken, FitnessActivity, UserNotification
from tasks import check_inactivity

# Mapping activity types from Google Fit API
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

def fetch_fitness_data(user):
    """Fetch and process fitness-related data from Google Fit (Steps, Activity, Sleep, Heart Rate)."""
    user_token = CustomUserToken.objects.filter(user=user).first()
    if not user_token:
        return "No fitness data available."

    creds = Credentials(
        token=user_token.token,
        refresh_token=user_token.refresh_token,
        token_uri=user_token.token_uri,
        client_id=user_token.client_id,
        client_secret=user_token.client_secret,
        scopes=user_token.scopes.split(","),  # Ensure Google Fit scopes are included
    )

    if creds.expired and creds.refresh_token:
        creds.refresh(Request())

    fitness_service = build("fitness", "v1", credentials=creds)
    
    # Define the timeframe (last 24 hours)
    now_millis = int(time.time() * 1000)
    yesterday_millis = now_millis - (24 * 60 * 60 * 1000)

    # Fetch health metrics
    steps = fetch_step_count(fitness_service, yesterday_millis, now_millis)
    activities, last_activity_time = fetch_activity_sessions(fitness_service, user, yesterday_millis, now_millis)
    total_sleep_hours = fetch_sleep_data(fitness_service, yesterday_millis, now_millis)
    avg_heart_rate = fetch_heart_rate_data(fitness_service, yesterday_millis, now_millis)

    # Update last activity time for inactivity tracking
    update_last_activity_time(user, last_activity_time)

    return {
        "steps": steps,
        "activities": activities if activities else "No activity data.",
        "sleep_hours": total_sleep_hours,
        "average_heart_rate": avg_heart_rate if avg_heart_rate else "No heart rate data.",
    }

def fetch_step_count(fitness_service, start_time, end_time):
    """Fetch step count from Google Fit."""
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

def fetch_activity_sessions(fitness_service, user, start_time, end_time):
    """Fetch and store activity sessions from Google Fit."""
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

        # Update last activity time
        if not last_activity_time or start_time_dt > last_activity_time:
            last_activity_time = start_time_dt

        # Prevent duplication before storing activity
        exists = FitnessActivity.objects.filter(user=user, start_time=start_time_dt, end_time=end_time_dt, activity_type=activity_name).exists()

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

def fetch_sleep_data(fitness_service, start_time, end_time):
    """Fetch total sleep hours from Google Fit."""
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

def fetch_heart_rate_data(fitness_service, start_time, end_time):
    """Fetch average heart rate from Google Fit."""
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

def update_last_activity_time(user, last_activity_time):
    """Update last recorded activity time in database for inactivity tracking."""
    if last_activity_time:
        latest_activity = FitnessActivity.objects.filter(user=user).order_by("-start_time").first()
        if latest_activity:
            latest_activity.last_activity_time = last_activity_time
            latest_activity.save()

def send_smart_prompt(user):
    """Store smart health prompts in the database for the Flutter app to fetch."""
    inactivity_hours = check_inactivity(user)

    prompts = []

    # Inactivity Alert
    if inactivity_hours >= 6:
        prompts.append("You haven't exercised in 6+ hours. A short walk can help stabilize glucose levels.")

    # Sleep Reminder
    total_sleep_hours = fetch_sleep_data(user)
    if total_sleep_hours < 6:
        prompts.append("Your sleep pattern shows you've been getting less than 6 hours on average. Try winding down earlier tonight.")

    # Hydration Reminder
    prompts.append("Have you had water today? Staying hydrated supports your metabolism and energy levels.")

    # High Heart Rate Alert
    avg_heart_rate = fetch_heart_rate_data(user)
    if avg_heart_rate and avg_heart_rate > 100:
        prompts.append("Your heart rate has been higher than usual today. Consider taking a short break or deep breathing exercises.")

    # Habit Streaks & Motivation
    exercise_streak = FitnessActivity.objects.filter(user=user, duration_minutes__gte=30).count()
    if exercise_streak >= 5:
        prompts.append(f"You're on a {exercise_streak}-day streak of exercise. Keep it up.")

    # Store all generated prompts
    for prompt in prompts:
        UserNotification.objects.create(user=user, message=prompt, notification_type="health_alert")

    return prompts if prompts else None
