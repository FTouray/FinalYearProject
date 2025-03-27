from datetime import timedelta
from django.utils.timezone import now
from django.db.models import Avg, Sum, Count
import openai
from core.models import AIHealthTrend, FitnessActivity, CustomUser


client = openai.OpenAI()

def generate_ai_recommendation(user, fitness_activities):
    """
    Generates AI-based health recommendations using OpenAI GPT.
    Supports **individual** user insights based on recent workouts.
    """

    if not fitness_activities:
        fitness_summary = "No recent fitness data available."
    else:
        fitness_summary = "\n".join(
            f"- {activity.activity_type} for {activity.duration_minutes:.0f} mins on {activity.start_time.strftime('%Y-%m-%d')}"
            for activity in fitness_activities
        )

    prompt = f"""
    The user has diabetes and their recent health activities are:

    {fitness_summary}

    Based on this data:
    - Suggest improvements to their fitness routine.
    - Provide personalized exercise recommendations.
    - Ensure all recommendations are diabetes-friendly and promote glucose stability.

    Return in bullet-point format.
    """

    response = client.chat.completions.create(
        model="gpt-3.5-turbo",
        messages=[
            {"role": "system", "content": "You are an AI fitness coach specializing in diabetic health advice."},
            {"role": "user", "content": prompt},
        ],
    )

    return response["choices"][0]["message"]["content"]


def generate_health_trends(user=None, period_type="weekly"):
    """
    Analyze user or system-wide health trends.
    """
    end_date = now().date()
    start_date = end_date - timedelta(days=7 if period_type == "weekly" else 30)
    user_filter = {"user": user} if user else {}

    # Pull data from FitnessActivity model
    activities = FitnessActivity.objects.filter(start_time__date__range=[start_date, end_date], **user_filter)

    avg_steps = activities.aggregate(Sum("steps"))["steps__sum"]
    avg_sleep = activities.aggregate(Avg("total_sleep_hours"))["total_sleep_hours__avg"]
    avg_hr = activities.aggregate(Avg("heart_rate"))["heart_rate__avg"]
    total_sessions = activities.exclude(activity_type="Sleep").count()

    trend_prompt = f"""
    The {'entire user base' if user is None else 'user'}'s {period_type} trends are:

    - Total Steps: {avg_steps or 'N/A'}
    - Avg Sleep: {avg_sleep or 'N/A'} hours
    - Avg Heart Rate: {avg_hr or 'N/A'} bpm
    - Exercise Sessions: {total_sessions}

    Provide:
    - Key insights and progress
    - Recommendations for improvement
    - Diabetes-specific guidance

    Use bullet points.
    """

    response = openai.ChatCompletion.create(
        model="gpt-4",
        messages=[
            {"role": "system", "content": "You are an AI health coach."},
            {"role": "user", "content": trend_prompt},
        ],
    )

    summary = response["choices"][0]["message"]["content"]

    AIHealthTrend.objects.update_or_create(
        user=user,
        period_type=period_type,
        start_date=start_date,
        end_date=end_date,
        defaults={
            "avg_steps": avg_steps,
            "avg_sleep_hours": avg_sleep,
            "avg_heart_rate": avg_hr,
            "total_exercise_sessions": total_sessions,
            "ai_summary": summary,
        },
    )

    return summary


def generate_system_wide_health_trends():
    return generate_health_trends(user=None, period_type="weekly"), generate_health_trends(user=None, period_type="monthly")


def generate_individual_health_trends():
    for user in CustomUser.objects.all():
        generate_health_trends(user=user, period_type="weekly")
        generate_health_trends(user=user, period_type="monthly")
