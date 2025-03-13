from core.models import MedicationReminder
from django_q.tasks import async_task

def send_reminder(user_id, medication_name):
    """Function to send reminders (integrated with OneSignal API)."""
    print(f"Reminder: Time to take {medication_name}!")
    async_task("core.tasks.send_push_notification", user_id, "Medication Reminder", f"Time to take {medication_name}")

def schedule_medication_reminder(user, medication, reminder_time):
    """Schedule reminders for medication intake and store in DB."""
    
    # Save to database
    reminder, created = MedicationReminder.objects.get_or_create(
        user=user, medication=medication, reminder_time=reminder_time
    )
    
    if created:
        print(f"New reminder scheduled for {medication.name} at {reminder_time}")
    
    # Schedule with django-q (ensures persistence)
    async_task("core.tasks.send_medication_reminder", user.id, medication.name, schedule_type="D", repeats=-1)
