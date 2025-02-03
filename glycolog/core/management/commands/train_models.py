from django.core.management.base import BaseCommand
from core.ai_model.model_training import train_all_models
from core.ai_model.data_processing import load_data_from_db

from core.models import (
    QuestionnaireSession,
    SymptomCheck,
    GlucoseCheck,
    MealCheck,
    ExerciseCheck,
    GlucoseLog,
    GlycaemicResponseTracker,
    Meal,
    FeelingCheck,
)


class Command(BaseCommand):
    help = "Trains AI models using the latest database data."

    def handle(self, *args, **options):
        self.stdout.write("Fetching data from database...")

        # **Filter only questionnaires that have related data**
        valid_questionnaires = QuestionnaireSession.objects.filter(
            symptom_check__isnull=False,
            meal_check__isnull=False,
            exercise_check__isnull=False,
            glucose_check__isnull=False
        ).distinct()

        # **Fetch only necessary data, optimizing queries**
        data = load_data_from_db(
            questionnaire_queryset=valid_questionnaires,
            symptom_queryset=SymptomCheck.objects.all(),
            glucose_check_queryset=GlucoseCheck.objects.all(),
            meal_check_queryset=MealCheck.objects.all(),
            exercise_queryset=ExerciseCheck.objects.all(),
            glucose_log_queryset=GlucoseLog.objects.all(),
            glycaemic_response_queryset=GlycaemicResponseTracker.objects.all(),
            meal_queryset=Meal.objects.all(),
            feeling_queryset=FeelingCheck.objects.all(),  
        )

        if data.empty:  # **Prevent training if no data is available**
            self.stdout.write("No valid data available for training. Skipping model training.")
            return

        self.stdout.write("Training models...")
        train_all_models(data)

        self.stdout.write("Models trained and saved successfully!")
