import datetime
import json
from django.utils.timezone import now
from django_q.tasks import schedule
from celery import shared_task
from django.db import models
from django.conf import settings
import os
from core.models import CustomUser, FitnessActivity, AIRecommendation, OneSignalPlayerID, UserNotification
from core.ai_services import generate_ai_recommendation, generate_health_trends
import requests

ONESIGNAL_APP_ID = os.getenv("ONESIGNAL_APP_ID")
ONESIGNAL_API_KEY = os.getenv("ONESIGNAL_API_KEY")

def update_fitness_data(user_id=None):
    from core.models import CustomUser
    users = [CustomUser.objects.get(id=user_id)] if user_id else CustomUser.objects.all()
    from datetime import timedelta

    for user in users:
        yesterday = now().date() - timedelta(days=1)
        exists = FitnessActivity.objects.filter(user=user, start_time__date=yesterday).exists()

        if not exists:
            send_push_notification(
                user,
                "Daily Sync Required",
                "Open Glycolog to sync your health data for yesterday."
            )
            
def detect_bad_day_risk(user):
    from datetime import timedelta

    past_activities = FitnessActivity.objects.filter(
        user=user,
        start_time__gte=now() - timedelta(days=7)
    )

    poor_sleep_days = [a for a in past_activities if (a.total_sleep_hours or 0) < 5]
    no_exercise_days = [a for a in past_activities if (a.steps or 0) < 2000]

    if len(poor_sleep_days) >= 2 and len(no_exercise_days) >= 2:
        send_push_notification(
            user,
            "You Might Feel Low Today",
            "Poor sleep and no activity detected recently. Try walking or hydrating."
        )

def send_push_notification(user, title, message):
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

def check_inactivity(user):
    latest_activity = FitnessActivity.objects.filter(user=user).order_by("-start_time").first()
    if not latest_activity:
        return 999
    inactivity_duration = (now() - latest_activity.end_time).total_seconds() / 3600
    return inactivity_duration

def send_smart_prompt(user_id=None):
    users = [CustomUser.objects.get(id=user_id)] if user_id else CustomUser.objects.all()
    for user in users:
        detect_bad_day_risk(user)
        inactivity_hours = check_inactivity(user)
        prompts = []

        if inactivity_hours >= 6:
            msg = "You haven't exercised in 6+ hours. A short walk can help stabilize glucose levels."
            prompts.append(msg)
            send_push_notification(user, "Time to Move!", msg)

        today = now().date()
        today_activities = FitnessActivity.objects.filter(user=user, start_time__date=today)
        total_steps = today_activities.aggregate(models.Sum("steps"))['steps__sum'] or 0
        if total_steps < 3000:
            msg = "You've been inactive today. A quick 10-minute walk can boost your energy."
            prompts.append(msg)
            send_push_notification(user, "Stay Active!", msg)

        avg_sleep = today_activities.aggregate(models.Avg("total_sleep_hours"))['total_sleep_hours__avg'] or 0
        if avg_sleep < 6:
            msg = "You've been getting less than 6 hours of sleep on average. Try sleeping earlier tonight."
            prompts.append(msg)
            send_push_notification(user, "Improve Your Sleep", msg)

        msg = "Have you had enough water today? Staying hydrated supports metabolism and energy levels."
        prompts.append(msg)
        send_push_notification(user, "Hydration Check", msg)

        avg_heart_rate = today_activities.aggregate(models.Avg("heart_rate"))['heart_rate__avg']
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
    users = [CustomUser.objects.get(id=user_id)] if user_id else CustomUser.objects.all()
    for user in users:
        recent_data = FitnessActivity.objects.filter(user=user).order_by("-start_time")[:10]
        if not recent_data.exists():
            continue
        ai_recommendation = generate_ai_recommendation(user, recent_data)
        AIRecommendation.objects.create(user=user, recommendation_text=ai_recommendation)

def schedule_tasks():
    schedule("core.tasks.send_smart_prompt", schedule_type="H", repeats=-1)
    schedule("core.tasks.generate_health_recommendation", schedule_type="D", repeats=-1)
    for user in CustomUser.objects.all():
        schedule("core.tasks.send_smart_prompt", user.id, schedule_type="H", repeats=-1)
        schedule("core.tasks.generate_health_recommendation", user.id, schedule_type="D", repeats=-1)

def schedule_trend_analysis():
    schedule("core.ai_services.generate_health_trends", None, period_type="weekly", schedule_type="W", repeats=-1)
    schedule("core.ai_services.generate_health_trends", None, period_type="monthly", schedule_type="M", repeats=-1)
    for user in CustomUser.objects.all():
        schedule("core.ai_services.generate_health_trends", user.id, period_type="weekly", schedule_type="W", repeats=-1)
        schedule("core.ai_services.generate_health_trends", user.id, period_type="monthly", schedule_type="M", repeats=-1)

@shared_task
def send_medication_reminder(user_id, medication_name):
    print(f"Reminder: Time to take {medication_name} for User {user_id}")
    return f"Reminder sent for {medication_name}"
