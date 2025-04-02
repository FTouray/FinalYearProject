from django.core.management.base import BaseCommand
from core.models import FitnessActivity

class Command(BaseCommand):
    help = "Patch distance_km values that are actually in meters"

    def handle(self, *args, **kwargs):
        updated = 0
        for activity in FitnessActivity.objects.filter(distance_km__gte=100):
            original = activity.distance_km
            corrected = round(original / 1000, 2)
            self.stdout.write(f"[{activity.id}] {original} → {corrected} km")

            activity.distance_km = corrected
            activity.save()
            updated += 1

        self.stdout.write(self.style.SUCCESS(f"✅ Patched {updated} entries."))
