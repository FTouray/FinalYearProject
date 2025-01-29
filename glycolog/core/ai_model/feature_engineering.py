import pandas as pd


def feature_engineering(data):
    """
    Add derived features for glycaemic response, meal impact, symptom severity, and glucose fluctuations.
    """
    # **Meal Glycaemic Index Features**
    data["weighted_gi"] = data["weighted_gi"].fillna(0)  # Handle missing GI values
    data["meal_impact"] = data["weighted_gi"] * (1 + len(data["skipped_meals"]))

    # **Calculate Personalized Glycaemic Response**
    data["glycaemic_response_score"] = data["meal_impact"] / (data["glucose_level"] + 1)  # Normalize
    data["glycaemic_variability"] = data.groupby("user")["glucose_level"].std()  # Fluctuation

    # **Track post-meal glucose spikes**
    if "meal_context" in data.columns:
        data["post_meal_glucose_spike"] = data.apply(
            lambda row: row["glucose_level"] - row["glucose_level"].mean()
            if row["meal_context"] == "post_meal"
            else 0, axis=1
        )

    # **Map meal categories for better tracking**
    meal_category_map = {
        "Breakfast": 1, "Lunch": 2, "Dinner": 3, "Snack": 4
    }
    data["meal_category_numeric"] = data["name"].map(meal_category_map).fillna(0)

    return data

