from datetime import time
from googleapiclient.discovery import build
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from core.models import CustomUserToken  # Adjust based on your actual structure


def fetch_google_fit_data(user):
    """Fetch user's fitness activity data from Google Fit."""
    user_token = CustomUserToken.objects.filter(user=user).first()
    if not user_token:
        return None  # No token, user hasn't connected Google Fit

    creds = Credentials(
        token=user_token.token,
        refresh_token=user_token.refresh_token,
        token_uri=user_token.token_uri,
        client_id=user_token.client_id,
        client_secret=user_token.client_secret,
        scopes=user_token.scopes,
    )

    if creds.expired and creds.refresh_token:
        creds.refresh(Request())

    fitness_service = build("fitness", "v1", credentials=creds)
    sessions = fitness_service.users().sessions().list(userId="me").execute()
    activities = sessions.get("session", [])

    activity_summary = "\n".join(
        [
            f"{activity['name']} from {activity['startTimeMillis']} to {activity['endTimeMillis']}"
            for activity in activities
        ]
    )

    return activity_summary

def get_smartwatch_data(user):
    """Fetch user's activity data from Google Fit."""
    user_token = CustomUserToken.objects.filter(user=user).first()
    if not user_token:
        return "No smartwatch data available."

    creds = Credentials(
        token=user_token.token,
        refresh_token=user_token.refresh_token,
        token_uri=user_token.token_uri,
        client_id=user_token.client_id,
        client_secret=user_token.client_secret,
        scopes=user_token.scopes.split(",")
    )

    # Refresh token if expired
    if creds.expired and creds.refresh_token:
        creds.refresh(Request())

    fitness_service = build('fitness', 'v1', credentials=creds)

    # Example: Fetching step count data for today
    data_sources = fitness_service.users().dataSources().list(userId='me').execute()
    dataset = fitness_service.users().dataset().aggregate(userId='me', body={
        "aggregateBy": [{"dataTypeName": "com.google.step_count.delta"}],
        "bucketByTime": {"durationMillis": 86400000},
        "startTimeMillis": int(time.time() - 86400) * 1000,
        "endTimeMillis": int(time.time()) * 1000
    }).execute()

    steps = dataset.get("bucket", [{}])[0].get("dataset", [{}])[0].get("point", [{}])[0].get("value", [{}])[0].get("intVal", 0)

    return f"Steps taken today: {steps}"
