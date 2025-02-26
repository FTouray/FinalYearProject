import datetime
import json
from django.utils.timezone import now
from django_q.tasks import schedule
from django.db import models
from django.conf import settings
import os
from core.models import CustomUser, FitnessActivity, AIRecommendation, OneSignalPlayerID, UserNotification
from core.ai_services import generate_ai_recommendation, generate_health_trends
from core.services.google_fit_service import fetch_fitness_data  
import requests

ONESIGNAL_APP_ID = os.getenv("ONESIGNAL_APP_ID")
ONESIGNAL_API_KEY = os.getenv("ONESIGNAL_API_KEY")

def send_push_notification(user, title, message):
    """
    Send push notifications using OneSignal REST API.
    """
    player_ids = OneSignalPlayerID.objects.filter(user=user).values_list('player_id', flat=True)

    if not player_ids:
        print(f"No OneSignal Player ID for user: {user.username}")
        return

    headers = {
        "Authorization": f"Basic {ONESIGNAL_API_KEY}",
        "Content-Type": "application/json"
    }
    payload = {
        "app_id": ONESIGNAL_APP_ID,
        "include_player_ids": list(player_ids),
        "headings": {"en": title},
        "contents": {"en": message}
    }

    response = requests.post("https://onesignal.com/api/v1/notifications", json=payload, headers=headers)

    if response.status_code == 200:
        print(f"Successfully sent OneSignal notification: {response.json()}")
    else:
        print(f"Failed to send OneSignal notification: {response.json()}")

def update_fitness_data(user_id=None):
    """Fetch & update fitness data. Supports individual or all users."""
    if user_id:
        user = CustomUser.objects.get(id=user_id)
        fetch_fitness_data(user)
    else:
        for user in CustomUser.objects.all():
            fetch_fitness_data(user) 

def check_inactivity(user):
    """Determine if a user has been inactive for too long."""
    latest_activity = FitnessActivity.objects.filter(user=user).order_by("-start_time").first()

    if not latest_activity:
        return 999 

    inactivity_duration = (now() - latest_activity.end_time).total_seconds() / 3600  # Convert seconds to hours
    return inactivity_duration

def send_smart_prompt(user_id=None):
    """Store health prompts & send push notifications if inactive."""
    users = [CustomUser.objects.get(id=user_id)] if user_id else CustomUser.objects.all()

    for user in users:
        inactivity_hours = check_inactivity(user)
        prompts = []

        if inactivity_hours >= 6:
            msg = "You haven't exercised in 6+ hours. A short walk can help stabilize glucose levels."
            prompts.append(msg)
            send_push_notification(user, "Time to Move!", msg)

        total_steps = FitnessActivity.objects.filter(user=user).aggregate(total_steps=models.Sum("steps"))["total_steps"] or 0
        if total_steps < 3000:
            msg = "You've been inactive today. A quick 10-minute walk can boost your energy."
            prompts.append(msg)
            send_push_notification(user, "Stay Active!", msg)

        total_sleep_hours = FitnessActivity.objects.filter(user=user).aggregate(total_sleep=models.Sum("total_sleep_hours"))["total_sleep"] or 0
        if total_sleep_hours < 6:
            msg = "You've been getting less than 6 hours of sleep on average. Try sleeping earlier tonight."
            prompts.append(msg)
            send_push_notification(user, "Improve Your Sleep", msg)

        msg = "Have you had enough water today? Staying hydrated supports metabolism and energy levels."
        prompts.append(msg)
        send_push_notification(user, "Hydration Check", msg)

        avg_heart_rate = FitnessActivity.objects.filter(user=user).aggregate(avg_hr=models.Avg("heart_rate"))["avg_hr"] or None
        if avg_heart_rate and avg_heart_rate > 100:
            msg = "Your heart rate has been high today. Consider taking a short break or deep breathing exercises."
            prompts.append(msg)
            send_push_notification(user, "Take a Break", msg)

        exercise_streak = FitnessActivity.objects.filter(user=user, duration_minutes__gte=30).count()
        if exercise_streak >= 5:
            msg = f"You're on a {exercise_streak}-day streak of exercise. Keep it up!"
            prompts.append(msg)

        for prompt in prompts:
            UserNotification.objects.create(user=user, message=prompt, notification_type="health_alert")

    return prompts if prompts else None

def generate_health_recommendation(user_id=None):
    """Generate AI-driven health insights. Supports specific users & all users."""
    users = [CustomUser.objects.get(id=user_id)] if user_id else CustomUser.objects.all()

    for user in users:
        latest_health_data = FitnessActivity.objects.filter(user=user).order_by("-start_time")[:5]

        if not latest_health_data:
            continue

        ai_recommendation = generate_ai_recommendation(user, latest_health_data)

        AIRecommendation.objects.create(user=user, recommendation_text=ai_recommendation)

def schedule_tasks():
    """Schedule recurring AI insights & smart prompts for all users."""
    
    schedule("core.tasks.update_fitness_data", schedule_type="H", repeats=-1)  # Every 6 hours
    schedule("core.tasks.send_smart_prompt", schedule_type="H", repeats=-1)  # Every hour
    schedule("core.tasks.generate_health_recommendation", schedule_type="D", repeats=-1)  # Every day

    for user in CustomUser.objects.all():
        schedule("core.tasks.update_fitness_data", user.id, schedule_type="H", repeats=-1)
        schedule("core.tasks.send_smart_prompt", user.id, schedule_type="H", repeats=-1)
        schedule("core.tasks.generate_health_recommendation", user.id, schedule_type="D", repeats=-1)

def schedule_trend_analysis():
    """Schedule AI health trend analysis for all users and per-user."""
    
    schedule("core.ai_services.generate_health_trends", None, period_type="weekly", schedule_type="W", repeats=-1)
    schedule("core.ai_services.generate_health_trends", None, period_type="monthly", schedule_type="M", repeats=-1)

    for user in CustomUser.objects.all():
        schedule("core.ai_services.generate_health_trends", user.id, period_type="weekly", schedule_type="W", repeats=-1)
        schedule("core.ai_services.generate_health_trends", user.id, period_type="monthly", schedule_type="M", repeats=-1)
