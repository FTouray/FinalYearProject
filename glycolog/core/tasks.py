from datetime import timedelta
from django.utils.timezone import now
from celery import shared_task
import subprocess
from django.db import models
from core.models import CustomUser, FitnessActivity, AIRecommendation
from core.fitness_ai import generate_ai_recommendation, generate_health_trends


def generate_health_insight_prompts(user_id=None):
    users = [CustomUser.objects.get(id=user_id)] if user_id else CustomUser.objects.all()
    for user in users:
        prompts = []
        recent_activities = FitnessActivity.objects.filter(user=user, start_time__gte=now() - timedelta(days=7))

        poor_sleep_days = [a for a in recent_activities if (a.total_sleep_hours or 0) < 5]
        low_activity_days = [a for a in recent_activities if (a.steps or 0) < 2000]

        if len(poor_sleep_days) >= 2 and len(low_activity_days) >= 2:
            prompts.append("We've noticed multiple days with poor sleep and low activity. Try light walking and hydrating.")

        today = now().date()
        today_activities = FitnessActivity.objects.filter(user=user, start_time__date=today)

        total_steps = today_activities.aggregate(models.Sum("steps"))['steps__sum'] or 0
        if total_steps < 3000:
            prompts.append("Your step count is low today. Take a quick 10-minute walk to stay active.")

        avg_sleep = today_activities.aggregate(models.Avg("total_sleep_hours"))['total_sleep_hours__avg'] or 0
        if avg_sleep < 6:
            prompts.append("You're averaging less than 6 hours of sleep. Aim for better rest tonight.")

        avg_heart_rate = today_activities.aggregate(models.Avg("heart_rate"))['heart_rate__avg']
        if avg_heart_rate and avg_heart_rate > 100:
            prompts.append("Your heart rate is elevated today. Consider deep breathing or a short rest.")

        activity_streak = FitnessActivity.objects.filter(user=user, duration_minutes__gte=30).count()
        if activity_streak >= 5:
            prompts.append(f"You're on a {activity_streak}-day streak! Keep up the great work.")


    return prompts


def generate_ai_recommendations(user_id=None):
    users = [CustomUser.objects.get(id=user_id)] if user_id else CustomUser.objects.all()
    for user in users:
        latest_activities = FitnessActivity.objects.filter(user=user).order_by("-start_time")[:10]
        if latest_activities.exists():
            recommendation = generate_ai_recommendation(user, latest_activities)
            AIRecommendation.objects.create(user=user, recommendation_text=recommendation)

@shared_task
def send_push_notification(user_id, title, message):
    print(f"PUSH to {user_id}: {title} - {message}")
    
@shared_task
def send_medication_reminder(user_id, medication_name):
    print(f"Reminder: Time to take {medication_name} for User {user_id}")
    return f"Reminder sent for {medication_name}"

@shared_task
def retrain_all_user_models_task():
    subprocess.run(["python", "manage.py", "retrain_all_user_models"])
    return "✅ User models retrained"