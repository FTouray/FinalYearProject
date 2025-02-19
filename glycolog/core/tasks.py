import datetime
from django.utils.timezone import now
from django_q.tasks import schedule
from core.models import CustomUser, FitnessActivity, AIRecommendation, UserNotification
from django.db import models
from core.ai_services import generate_ai_recommendation  # AI processing

def check_inactivity(user):
    """Determine if the user has been inactive for too long."""
    latest_activity = (
        FitnessActivity.objects.filter(user=user)
        .order_by("-start_time")
        .first()
    )

    if not latest_activity:
        return 999  # No activity logged, assume very high inactivity

    inactivity_duration = (now() - latest_activity.end_time).total_seconds() / 3600  # Convert seconds to hours
    return inactivity_duration

def send_smart_prompt(user):
    """Store smart health prompts in the database for the Flutter app to fetch."""
    inactivity_hours = check_inactivity(user)

    prompts = []

    # Inactivity Alert
    if inactivity_hours >= 6:
        prompts.append("You haven't exercised in 6+ hours. A short walk can help stabilize glucose levels.")

    # Workout Motivation
    total_steps = FitnessActivity.objects.filter(user=user).aggregate(total_steps=models.Sum("steps"))["total_steps"] or 0
    if total_steps < 3000:
        prompts.append("You've been a bit inactive today. A quick 10-minute walk can boost your energy.")

    # Sleep Reminder
    total_sleep_hours = FitnessActivity.objects.filter(user=user).aggregate(total_sleep=models.Sum("total_sleep_hours"))["total_sleep"] or 0
    if total_sleep_hours < 6:
        prompts.append("Your sleep pattern shows you've been getting less than 6 hours on average. Try winding down earlier tonight.")

    # Hydration Reminder
    prompts.append("Have you had water today? Staying hydrated supports your metabolism and energy levels.")

    # High Heart Rate Alert
    avg_heart_rate = FitnessActivity.objects.filter(user=user).aggregate(avg_hr=models.Avg("heart_rate"))["avg_hr"] or None
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

def generate_health_recommendation(user):
    """Generate AI-based health insights and store them for Flutter to display."""
    latest_health_data = FitnessActivity.objects.filter(user=user).order_by("-start_time")[:5]

    if not latest_health_data:
        return "No recent fitness data available."

    ai_recommendation = generate_ai_recommendation(user, latest_health_data)

    # Store the recommendation in the database
    AIRecommendation.objects.create(user=user, recommendation_text=ai_recommendation)

    return ai_recommendation

def schedule_tasks():
    """Schedule recurring tasks for smart notifications and AI insights."""
    # Check inactivity & store prompts every hour
    schedule(
        "core.tasks.send_smart_prompt",
        schedule_type="H",
        repeats=-1  # Run indefinitely every hour
    )

    # Generate AI insights once per day
    schedule(
        "core.tasks.generate_health_recommendation",
        schedule_type="D",
        repeats=-1  # Run indefinitely every day
    )

def schedule_trend_analysis():
    """Schedule AI health trend analysis for all users."""
    for user in CustomUser.objects.all():
        schedule(
            "core.ai_services.generate_health_trends",
            user.id,
            period_type="weekly",
            schedule_type="W",
            repeats=-1  # Run indefinitely every week
        )
        
        schedule(
            "core.ai_services.generate_health_trends",
            user.id,
            period_type="monthly",
            schedule_type="M",
            repeats=-1  # Run indefinitely every month
        )