import random
from datetime import datetime, timedelta
from django.core.management.base import BaseCommand
from django.utils.timezone import make_aware
from core.models import (
    CustomUser, FitnessActivity, FoodItem, Meal, GlucoseLog,
    QuestionnaireSession, FeelingCheck, SymptomCheck,
    GlucoseCheck, MealCheck, ExerciseCheck
)

class Command(BaseCommand):
    help = "Populate user with mock health data over a month."

    def add_arguments(self, parser):
        parser.add_argument('--username', type=str, help='Username of the user')

    def handle(self, *args, **kwargs):
        username = kwargs['username']
        user = CustomUser.objects.get(username=username)

        start_date = datetime.now().date() - timedelta(days=30)
        meal_id_counter = user.meal_count + 1
        high_gi_foods = list(FoodItem.objects.filter(glycaemic_index__gte=70))

        for day_offset in range(30):
            base_day = start_date + timedelta(days=day_offset)

            activity_options = [
                "Walking",
                "Running",
                "Cycling",
                "Strength Training",
                "Yoga",
                "Dancing",
                "Swimming",
                "Hiking"
            ]
            activity_type = random.choice(activity_options)

            activity_start_time = make_aware(datetime.combine(base_day, datetime.min.time()) + timedelta(
                hours=random.randint(6, 9), minutes=random.randint(0, 59)))
            activity_duration = random.randint(20, 75)
            activity_end_time = activity_start_time + timedelta(minutes=activity_duration)
            steps = random.randint(1000, 15000) if activity_type in ["Walking", "Running", "Hiking"] else None
            distance = (steps * 0.7 / 1000) if steps else random.uniform(0.5, 3.0)  # kilometers

            FitnessActivity.objects.create(
                user=user,
                activity_type=activity_type,
                source="Phone",
                start_time=activity_start_time,
                end_time=activity_end_time,
                steps=steps,
                duration_minutes=activity_duration,
                calories_burned=round(random.uniform(100, 600), 2),
                heart_rate=random.uniform(75, 140),
                distance_km=distance
            )

            # Meal + Glucose Logs
            for hour, context in zip([8, 13, 19], ['pre_meal', 'post_meal', 'fasting']):
                meal_time = make_aware(datetime.combine(base_day, datetime.min.time()) + timedelta(
                    hours=hour, minutes=random.randint(0, 59)))
                meal = None

                if high_gi_foods:
                    meal = Meal.objects.create(
                        user=user,
                        user_meal_id=meal_id_counter,
                        name=f"Meal {meal_id_counter}",
                        timestamp=meal_time
                    )
                    meal.food_items.set(random.sample(high_gi_foods, k=2))
                    meal_id_counter += 1
                    user.meal_count += 1
                    user.save()

                GlucoseLog.objects.create(
                    user=user,
                    glucose_level=round(random.uniform(70, 180), 1),
                    timestamp=meal_time + timedelta(minutes=random.randint(10, 60)),
                    meal_context=context
                )

            # Feeling check + questionnaire
            feeling_time = make_aware(datetime.combine(base_day, datetime.min.time()) + timedelta(
                hours=18, minutes=random.randint(0, 59)))
            feeling = FeelingCheck.objects.create(
                user=user,
                feeling=random.choice(["good", "okay", "bad"]),
                timestamp=feeling_time
            )
            session = QuestionnaireSession.objects.create(
                user=user,
                feeling_check=feeling,
                completed=True
            )
            
            sleep_start_time = make_aware(datetime.combine(base_day, datetime.min.time()) + timedelta(
                hours=22, minutes=random.randint(0, 59)))
            sleep_hours = round(random.uniform(5.0, 8.0), 2)
            sleep_end_time = sleep_start_time + timedelta(hours=sleep_hours)

            SymptomCheck.objects.create(
                session=session,
                symptoms={"headache": random.choice([True, False]), "nausea": random.choice([True, False])},
                sleep_hours=sleep_hours,
                stress=random.choice([True, False]),
                routine_change=random.choice(["None", "Work", "Travel", "Schedule"]),
                responses={"mood": random.choice(["low", "neutral", "positive"])}
            )

            GlucoseCheck.objects.create(
                session=session,
                glucose_level=round(random.uniform(80, 200), 1),
                target_min=80,
                target_max=140
            )

            if meal:
                MealCheck.objects.create(
                    session=session,
                    notes="Felt full",
                    wellness_impact=random.choice([True, False])
                ).high_gi_foods.set(meal.food_items.all())

            ExerciseCheck.objects.create(
                session=session,
                last_exercise_time=random.choice(["Today", "2-3 Days Ago", "More than 5 Days Ago"]),
                exercise_type=random.choice(["Walking", "Yoga", "Running"]),
                exercise_intensity=random.choice(["Low", "Moderate", "Vigorous"]),
                exercise_duration=random.randint(10, 60),
                post_exercise_feeling=random.choice(["Energised", "Neutral", "Tired"]),
                activity_level_comparison=random.choice(["More", "Less", "About the Same"]),
                activity_prevention_reason=random.choice(["Fatigue", "Lack of time", "Other"]),
                discomfort_or_fatigue=random.choice([True, False]),
                discomfort_description="Mild knee pain" if random.random() < 0.3 else "",
                exercise_impact=random.choice([True, False])
            )

        self.stdout.write(self.style.SUCCESS(f"✅ Mock data seeded across 30 days for user: {user.username}"))

# python manage.py seed_month_data --username ftouray