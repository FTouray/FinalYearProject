from datetime import timedelta
from django.utils.timezone import now
from django.db.models import Avg, Sum, Count
import openai  
from core.models import AIHealthTrend, FitnessActivity, CustomUser

def generate_ai_recommendation(user, fitness_data):
    """
    Generates AI-based health recommendations using OpenAI GPT.
    Supports **individual** user insights.
    """

    # Format fitness data into a readable summary
    fitness_summary = "\n".join(
        [f"{activity.activity_type} for {activity.duration_minutes} mins on {activity.start_time.strftime('%Y-%m-%d')}"
         for activity in fitness_data]
    ) if fitness_data else "No recent fitness data available."

    # Construct OpenAI prompt
    prompt = f"""
    The user has diabetes and their recent health activities are as follows:

    {fitness_summary}

    Based on this data:
    - Suggest improvements to their fitness routine.
    - Provide personalized exercise recommendations.
    - Ensure all recommendations are diabetes-friendly and promote glucose stability.

    Present recommendations in bullet-point format.
    """

    # Call OpenAI API
    response = openai.ChatCompletion.create(
        model="gpt-4",
        messages=[
            {"role": "system", "content": "You are an AI fitness coach specializing in diabetic health recommendations."},
            {"role": "user", "content": prompt},
        ],
    )

    # Extract AI response
    ai_response = response["choices"][0]["message"]["content"]
    
    return ai_response

def generate_health_trends(user=None, period_type="weekly"):
    """
    Analyze **both** individual and system-wide health trends over a specified period (weekly/monthly).
    - If `user` is provided, it analyzes **only that user**.
    - If `user` is None, it generates **system-wide trends**.
    """
    end_date = now().date()
    start_date = end_date - timedelta(days=7) if period_type == "weekly" else end_date - timedelta(days=30)

    # Get the user filter or analyze all users together
    user_filter = {"user": user} if user else {}

    # Aggregate data for the period
    avg_glucose = FitnessActivity.objects.filter(
        **user_filter, activity_type="Glucose Measurement", start_time__date__range=[start_date, end_date]
    ).aggregate(Avg("glucose_level"))["glucose_level__avg"]

    avg_steps = FitnessActivity.objects.filter(
        **user_filter, start_time__date__range=[start_date, end_date]
    ).aggregate(Sum("steps"))["steps__sum"]

    avg_sleep = FitnessActivity.objects.filter(
        **user_filter, start_time__date__range=[start_date, end_date]
    ).aggregate(Avg("total_sleep_hours"))["total_sleep_hours__avg"]

    avg_heart_rate = FitnessActivity.objects.filter(
        **user_filter, start_time__date__range=[start_date, end_date]
    ).aggregate(Avg("heart_rate"))["heart_rate__avg"]

    total_exercise_sessions = FitnessActivity.objects.filter(
        **user_filter, activity_type="Exercise", start_time__date__range=[start_date, end_date]
    ).count()

    # Construct OpenAI prompt for trend analysis
    trend_prompt = f"""
    The {'entire system' if user is None else 'user'} has diabetes and their recent {period_type} health trends are as follows:

    - Average Glucose Level: {avg_glucose if avg_glucose else 'N/A'}
    - Total Steps: {avg_steps if avg_steps else 'N/A'}
    - Average Sleep Duration: {avg_sleep if avg_sleep else 'N/A'} hours
    - Average Heart Rate: {avg_heart_rate if avg_heart_rate else 'N/A'} bpm
    - Total Exercise Sessions: {total_exercise_sessions}

    Based on this, provide:
    - Key insights on their health trends.
    - Actionable fitness and lifestyle recommendations.
    - Any potential concerns related to diabetes.

    Present insights in bullet-point format.
    """

    response = openai.ChatCompletion.create(
        model="gpt-4",
        messages=[
            {"role": "system", "content": "You are an AI fitness expert providing insights based on user health trends."},
            {"role": "user", "content": trend_prompt},
        ],
    )

    ai_summary = response["choices"][0]["message"]["content"]

    # Store insights in the database
    AIHealthTrend.objects.update_or_create(
        user=user,
        period_type=period_type,
        start_date=start_date,
        end_date=end_date,
        defaults={
            "avg_glucose_level": avg_glucose,
            "avg_steps": avg_steps,
            "avg_sleep_hours": avg_sleep,
            "avg_heart_rate": avg_heart_rate,
            "total_exercise_sessions": total_exercise_sessions,
            "ai_summary": ai_summary,
        },
    )

    return ai_summary

def generate_system_wide_health_trends():
    """
    Generate health trends across **all users** (not per individual).
    """
    return generate_health_trends(user=None, period_type="weekly"), generate_health_trends(user=None, period_type="monthly")

def generate_individual_health_trends():
    """
    Generate health trends for **each user individually**.
    """
    for user in CustomUser.objects.all():
        generate_health_trends(user=user, period_type="weekly")
        generate_health_trends(user=user, period_type="monthly")
