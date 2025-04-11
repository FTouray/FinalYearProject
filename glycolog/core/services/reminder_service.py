from core.models import MedicationReminder
from core.tasks import send_push_notification, send_medication_reminder

def send_reminder(user_id, medication_name):
    print(f"Reminder: Time to take {medication_name}!")
    send_push_notification.delay(user_id, "Medication Reminder", f"Time to take {medication_name}")

def schedule_medication_reminder(user, medication, reminder_time):
    """Schedule reminders for medication intake and store in DB."""

    # Save to DB
    reminder, created = MedicationReminder.objects.get_or_create(
        user=user, medication=medication, reminder_time=reminder_time
    )

    if created:
        print(f"New reminder scheduled for {medication.name} at {reminder_time}")

    # Trigger one-time task (you could later set up periodic schedules via celery-beat)
    send_medication_reminder.apply_async(
        args=[user.id, medication.name],
        eta=reminder_time  # Run at exact time
    )
