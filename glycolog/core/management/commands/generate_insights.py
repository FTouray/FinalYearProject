from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from glycolog.core.models import GlucoseLog, GlycaemicResponseTracker, Meal
import joblib
import pandas as pd
from datetime import timedelta
import os


class Command(BaseCommand):
    help = "Generate personalized glucose insights for each user"

    def handle(self, *args, **kwargs):
        # Check for model file
        model_path = "ml/ml_models/gly_glucose_response_model.joblib"
        if not os.path.exists(model_path):
            self.stderr.write("Model file not found.")
            return

        model = joblib.load(model_path)
        User = get_user_model()

        # Iterate through all users
        for user in User.objects.all():
            glucose_logs = GlucoseLog.objects.filter(user=user)
            meals = Meal.objects.filter(user=user).prefetch_related("food_items")

            data = []
            for meal in meals:
                # Filter glucose logs related to the current meal's time
                related_logs = glucose_logs.filter(
                    timestamp__gte=meal.timestamp,
                    timestamp__lte=meal.timestamp + timedelta(hours=2),
                )

                # Calculate total glycaemic index (GI) and total carbs for the meal
                total_gi = sum(item.glycaemic_index for item in meal.food_items.all())
                carb_total = sum(
                    item.carbs
                    for item in meal.food_items.all()
                    if item.carbs is not None
                )

                # Collect data to predict glucose response
                for log in related_logs:
                    data.append(
                        {
                            "food_items": ", ".join(
                                [item.name for item in meal.food_items.all()]
                            ),
                            "total_glycaemic_index": total_gi,
                            "total_carbs": carb_total,
                            "glucose_level": log.glucose_level,
                        }
                    )

            # Perform predictions using the model
            if data:
                df = pd.DataFrame(data)
                predictions = model.predict(df.drop(columns=["glucose_level"]))
                insights = self.calculate_insights(
                    predictions,
                    df["food_items"],
                    df["total_glycaemic_index"],
                    df["total_carbs"],
                )
                self.save_insights(user, insights)

    def calculate_insights(self, predictions, food_items, total_gi, total_carbs):
        """
        Generate insights for both food items and meals based on the model's predictions.
        """
        insights = {}

        # Loop over food items to generate individual insights
        for food, pred in zip(food_items, predictions):
            if pred > 200:
                effect = "significant increase"
            elif 140 < pred <= 200:
                effect = "moderate increase"
            elif 110 < pred <= 140:
                effect = "slight increase"
            else:
                effect = "decrease or steady level"
            insights[food] = f"This food may cause a {effect} in glucose levels."

        # Meal-level insights based on total GI and total carbs
        for meal_gi, meal_carbs in zip(total_gi, total_carbs):
            meal_effect = self.predict_meal_effect(meal_gi, meal_carbs)
            insights["meal"] = meal_effect

        return insights

    def predict_meal_effect(self, total_gi, total_carbs):
        """
        Predict meal effect on glucose level based on total glycaemic index and total carbs.
        """
        if total_gi > 200 or total_carbs > 100:
            return "Meals with high GI or high carbs can significantly increase glucose levels."
        elif 140 < total_gi <= 200 or total_carbs > 50:
            return "Meals with moderate GI or carbs may moderately increase glucose levels."
        elif 110 < total_gi <= 140 or total_carbs <= 50:
            return "Meals with slight GI or low carbs may have a slight increase in glucose."
        else:
            return "Meals with low GI or carbs may help maintain steady glucose levels."

    def save_insights(self, user, insights):
        """
        Save the generated insights into the GlycaemicResponseTracker model.
        """
        # Create or update the GlycaemicResponseTracker for the user
        tracker, created = GlycaemicResponseTracker.objects.get_or_create(user=user)

        # Save food item insights
        food_item_insights = {
            food: message for food, message in insights.items() if food != "meal"
        }

        # Save meal-level insight separately
        meal_insight = insights.get("meal", "No meal-level insight available.")

        # Store insights in the tracker
        tracker.insights = {**food_item_insights, "meal": meal_insight}
        tracker.save()

        # Print for debugging or logging purposes
        for food, message in food_item_insights.items():
            print(f"For {user.first_name}, {food}: {message}")
        print(f"Meal-level insight for {user.first_name}: {meal_insight}")
