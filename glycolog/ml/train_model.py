import os
import sys
import django

# Set up Django environment
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "glycolog.settings")
django.setup()

import joblib
from django.conf import settings
from core.models import GlucoseLog, Meal
import pandas as pd
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_squared_error, r2_score
from datetime import timedelta

def load_data():
    meal_logs = Meal.objects.all().prefetch_related("food_items")
    glucose_logs = GlucoseLog.objects.all()

    if not meal_logs.exists() or not glucose_logs.exists():
        print("No meal logs or glucose logs found in the database.")
        return pd.DataFrame()
    
    print(f"Loaded {meal_logs.count()} meals and {glucose_logs.count()} glucose logs")

    data = []
    for meal in meal_logs:
        related_logs = glucose_logs.filter(
            user=meal.user,
            timestamp__gte=meal.timestamp,
            timestamp__lte=meal.timestamp + timedelta(hours=2),
        )
        for log in related_logs:
            food_items = [item.name for item in meal.food_items.all()]
            total_gi = sum(item.glycaemic_index for item in meal.food_items.all())
            carb_total = sum(item.carbohydrates for item in meal.food_items.all())

            data.append({
                "food_items": ", ".join(food_items),
                "total_glycaemic_index": total_gi,
                "total_carbohydrates": carb_total,
                "glucose_level": log.glucose_level,
            })

    return pd.DataFrame(data)

def preprocess_data(data):
    data = pd.get_dummies(data, columns=["food_items"], drop_first=True)
    X = data.drop(columns=["glucose_level"])
    y = data["glucose_level"]
    return train_test_split(X, y, test_size=0.2, random_state=42)

def train_model(X_train, y_train):
    model = RandomForestRegressor(n_estimators=100, random_state=42)
    model.fit(X_train, y_train)
    return model

def main():
    # data = load_data()
    # if data.empty:
    #     print("No data available for training.")
    #     return

    # X_train, X_test, y_train, y_test = preprocess_data(data)
    # model = train_model(X_train, y_train)

    # predictions = model.predict(X_test)
    # mse = mean_squared_error(y_test, predictions)
    # r2 = r2_score(y_test, predictions)
    # print(f"Model Mean Squared Error: {mse}")
    # print(f"Model R^2 Score: {r2}")

    # model_dir = settings.BASE_DIR / "ml" / "ml_models"
    # os.makedirs(model_dir, exist_ok=True)  # Ensure directory exists
    # model_path = model_dir / "gly_glucose_response_model.joblib"

    # joblib.dump(model, model_path)
    # print(f"Model saved at {model_path}")
    print("Skipping model training for now.")

if __name__ == "__main__":
    main()
