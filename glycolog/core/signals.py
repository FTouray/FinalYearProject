import threading
from django.db.models.signals import post_save
from django.dispatch import receiver
from core.models import QuestionnaireSession
import subprocess

_thread_local = threading.local()

@receiver(post_save, sender=QuestionnaireSession)
def trigger_model_retrain(sender, instance, created, **kwargs):
    if not instance.completed:
        return

    if getattr(_thread_local, 'suppress_signal', False):
        return  # 🛡️ prevent recursive signal

    user = instance.user
    completed_count = QuestionnaireSession.objects.filter(user=user, completed=True).count()

    if completed_count >= 5:
        print(f"📊 Retraining model for {user.username} (sessions: {completed_count})")
        _thread_local.suppress_signal = True  # prevent infinite loop

        subprocess.Popen([
            'python', 'manage.py', 'retrain_single_user_model', str(user.id)
        ])
