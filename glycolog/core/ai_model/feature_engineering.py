import pandas as pd

def feature_engineering(data):
    """
    Add derived features for glycaemic response, meal impact, symptom severity, glucose fluctuations, and exercise influence.
    """

    # Handle Missing Values for Core Features
    data["weighted_gi"] = data["weighted_gi"].fillna(0)  # Default missing GI values
    data["skipped_meals"] = data["skipped_meals"].apply(len)  # Convert list to count
    data["exercise_duration"] = data["exercise_duration"].fillna(0)  # Default missing exercise

    # Meal & Glycaemic Response Features
    data["meal_impact"] = data["weighted_gi"] * (1 + data["skipped_meals"])  # Impact Score
    data["glycaemic_response_score"] = data["meal_impact"] / (data["glucose_level"] + 1)  # Normalize
    # data["glycaemic_variability"] = data.groupby("user_id")["glucose_level"].std()  # Glucose fluctuation

    # Track Post-Meal Glucose Spikes
    if "meal_context" in data.columns:
        data["post_meal_glucose_spike"] = data.apply(
            lambda row: row["glucose_level"] - row["glucose_level"].mean()
            if row["meal_context"] == "post_meal"
            else 0, axis=1
        )

    # Symptoms Severity Feature Engineering
    if "symptoms" in data.columns:
        data["average_symptom_severity"] = data["symptoms"].apply(
            lambda x: sum(item["severity"] for item in x) / len(x) if x else 0
        )
        data["symptom_count"] = data["symptoms"].apply(len)  # Count total reported symptoms

    # Sleep & Stress Features
    data["sleep_quality"] = data["sleep_hours"].apply(lambda x: "Good" if x >= 6 else "Poor")
    data["stress_impact"] = data["stress"].astype(int) * data["glucose_level"]  # Stress & glucose relation

    # Exercise-Based Features
    intensity_map = {"Low": 1, "Moderate": 2, "Vigorous": 3}
    data["exercise_intensity_numeric"] = data["exercise_intensity"].map(intensity_map)
    data["exercise_score"] = data["exercise_duration"] * data["exercise_intensity_numeric"]  # Total Exercise Score

    # Exercise & Glucose Stability
    data["exercise_glucose_stability"] = data.groupby("user_id")["glucose_level"].diff().abs()  # Drop magnitude
    data["exercise_glucose_stability"] = data["exercise_glucose_stability"].fillna(0)  # Default missing values

    # Map meal categories for better tracking
    meal_category_map = {"Breakfast": 1, "Lunch": 2, "Dinner": 3, "Snack": 4}
    data["meal_category_numeric"] = data["name"].map(meal_category_map).fillna(0)

    # **Track Post-Meal Glucose Spikes**
    if "meal_context" in data.columns:
        data["post_meal_glucose_spike"] = data.apply(
            lambda row: (
                row["glucose_level"] - data["glucose_level"].mean()
                if pd.notna(row["meal_context"]) and row["meal_context"] == "post_meal"
                else None
            ),  # Assign None instead of 0 if meal_context is missing
            axis=1,
        )
    else:
        # If meal_context column does not exist, create a NaN column to avoid errors
        data["post_meal_glucose_spike"] = None

    # Symptoms & Exercise Correlation
    data["symptom_glucose_correlation"] = data["average_symptom_severity"] * data["glucose_level"]
    data["exercise_symptom_impact"] = data["exercise_duration"] * data["average_symptom_severity"]

    return data
