from datetime import datetime
import time
from googleapiclient.discovery import build
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from core.models import CustomUserToken, SmartwatchActivity

# Mapping activity type codes to human-readable names
ACTIVITY_TYPE_MAP = {
    8: "Running",
    1: "Biking",
    7: "Walking",
    82: "Swimming",
    9: "Aerobics",
    10: "Badminton",
    11: "Baseball",
    12: "Basketball",
    13: "Biathlon",
    14: "Handbiking",
    15: "Mountain biking",
    16: "Road biking",
    17: "Spinning",
    18: "Stationary biking",
    19: "Utility biking",
    20: "Boxing",
    21: "Calisthenics",
    22: "Circuit training",
    23: "Cricket",
    24: "Dancing",
    25: "Elliptical",
    26: "Fencing",
    27: "Football (American)",
    28: "Football (Australian)",
    29: "Football (Soccer)",
    30: "Frisbee",
    31: "Gardening",
    32: "Golf",
    33: "Gymnastics",
    34: "Handball",
    35: "Hiking",
    36: "Hockey",
    37: "Horseback riding",
    38: "Housework",
    39: "Ice skating",
    40: "Jumping rope",
    41: "Kayaking",
    42: "Kettlebell training",
    43: "Kickboxing",
    44: "Kitesurfing",
    45: "Martial arts",
    46: "Meditation",
    47: "Mixed martial arts",
    48: "P90X exercises",
    49: "Paragliding",
    50: "Pilates",
    51: "Polo",
    52: "Racquetball",
    53: "Rock climbing",
    54: "Rowing",
    55: "Rowing machine",
    56: "Rugby",
    57: "Jogging",
    58: "Running on sand",
    59: "Treadmill running",
    60: "Sailing",
    61: "Scuba diving",
    62: "Skateboarding",
    63: "Skating",
    64: "Cross skating",
    65: "Indoor skating",
    66: "Inline skating",
    67: "Skiing",
    68: "Back-country skiing",
    69: "Cross-country skiing",
    70: "Downhill skiing",
    71: "Kite skiing",
    72: "Roller skiing",
    73: "Sledding",
    74: "Sleeping",
    75: "Light sleep",
    76: "Deep sleep",
    77: "REM sleep",
    78: "Snowboarding",
    79: "Snowmobile",
    80: "Snowshoeing",
    81: "Squash",
    82: "Stretching",
    83: "Surfing",
    84: "Swimming",
    85: "Treadmill swimming",
    86: "Table tennis",
    87: "Team sports",
    88: "Tennis",
    89: "Treadmill",
    90: "Volleyball",
    91: "Volleyball (Beach)",
    92: "Volleyball (Indoor)",
    93: "Wakeboarding",
    94: "Walking",
    95: "Walking (Fitness)",
    96: "Nording walking",
    97: "Treadmill walking",
    98: "Waterpolo",
    99: "Weightlifting",
    100: "Wheelchair",
    101: "Windsurfing",
    102: "Yoga",
    103: "Zumba",
}


def fetch_google_fit_data(user):
    """Fetch user's fitness activity data from Google Fit."""
    user_token = CustomUserToken.objects.filter(user=user).first()
    if not user_token:
        return "No smartwatch data available."

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

    activity_summary = []
    for activity in activities:
        activity_type_code = activity.get("activityType", None)
        activity_type = ACTIVITY_TYPE_MAP.get(activity_type_code, "Unknown Activity")
        start_time = activity.get("startTimeMillis", "N/A")
        end_time = activity.get("endTimeMillis", "N/A")

        activity_summary.append(f"{activity_type}: {start_time} to {end_time}")

    return (
        "\n".join(activity_summary)
        if activity_summary
        else "No activity data available."
    )

def get_smartwatch_data(user):
    """Fetch and store user's activity data from Google Fit."""
    user_token = CustomUserToken.objects.filter(user=user).first()
    if not user_token:
        return "No smartwatch data available."

    creds = Credentials(
        token=user_token.token,
        refresh_token=user_token.refresh_token,
        token_uri=user_token.token_uri,
        client_id=user_token.client_id,
        client_secret=user_token.client_secret,
        scopes=user_token.scopes.split(","),
    )

    # Refresh token if expired
    if creds.expired and creds.refresh_token:
        creds.refresh(Request())

    fitness_service = build("fitness", "v1", credentials=creds)

    # Fetch activity sessions from Google Fit
    sessions_result = fitness_service.users().sessions().list(userId="me").execute()
    sessions = sessions_result.get("session", [])

    activity_summary = []

    for session in sessions:
        activity_type = session.get("activityType")
        start_time = session.get("startTimeMillis")
        end_time = session.get("endTimeMillis")
        duration_minutes = (
            int(end_time) - int(start_time)
        ) / 60000  # Convert ms to minutes

        # Convert timestamps to datetime
        start_time = datetime.fromtimestamp(int(start_time) / 1000)
        end_time = datetime.fromtimestamp(int(end_time) / 1000)

        # Save to database
        SmartwatchActivity.objects.get_or_create(
            user=user,
            activity_type=ACTIVITY_TYPE_MAP.get(activity_type, "Unknown Activity"),
            start_time=start_time,
            end_time=end_time,
            duration_minutes=duration_minutes,
        )

        activity_summary.append(
            f"{ACTIVITY_TYPE_MAP.get(activity_type, 'Unknown Activity')} from {start_time} to {end_time}"
        )

    return "\n".join(activity_summary) if activity_summary else "No activities found."
