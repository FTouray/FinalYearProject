from django.core.management.base import BaseCommand
from core.models import CustomUser
from core.management.commands.retrain_all_user_models import Command as RetrainAll 
from django.utils.timezone import now

class Command(BaseCommand):
    help = "Retrain ML model for a specific user"

    def add_arguments(self, parser):
        parser.add_argument("user_id", type=int)

    def handle(self, *args, **options):
        user = CustomUser.objects.get(id=options["user_id"])
        retrainer = RetrainAll()
        model_version = f"v{now().strftime('%Y%m%d%H%M')}"
        retrainer.handle_single_user(user, model_version)
