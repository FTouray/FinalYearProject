import pandas as pd

def map_wellness_score(feeling):
    if feeling == "good":
        return 5
    if feeling == "okay":
        return 3
    if feeling == "bad":
        return 1
    return 0


def feature_engineering(data):
    """
    Add derived features for glycaemic response, meal impact, symptom severity, glucose fluctuations, and exercise influence.
    """
    
    if "skipped_meals" in data.columns:
        data["skipped_meals"] = data["skipped_meals"].apply(lambda x: len(x) if isinstance(x, list) else 0)

    # Handle Missing Values for Core Features
    data["weighted_gi"] = data["weighted_gi"].fillna(0)  # Default missing GI values
    data["skipped_meals"] = data["skipped_meals"].apply(lambda x: len(x) if isinstance(x, list) else 0)  # Convert list to count
    data["exercise_duration"] = data["exercise_duration"].fillna(0)  # Default missing exercise

    # Meal & Glycaemic Response Features
    data["meal_impact"] = data["weighted_gi"] * (1 + data["skipped_meals"])  # Impact Score
    data["glycaemic_response_score"] = data["meal_impact"] / (data["glucose_level"] + 1)  # Normalize
    # data["glycaemic_variability"] = data.groupby("user_id")["glucose_level"].std()  # Glucose fluctuation

    # Track Post-Meal Glucose Spikes
    if "meal_context" in data.columns:
        avg_glucose = data["glucose_level"].mean()  # Compute once
        data["post_meal_glucose_spike"] = data.apply(
            lambda row: (
                row["glucose_level"] - avg_glucose
                if row["meal_context"] == "post_meal"
                else 0
            ),
            axis=1,
    )
        
    if "stress" in data.columns:
        data["stress"] = data["stress"].fillna(False).astype(int)
        
    # Symptoms Severity Feature Engineering
    if "symptoms" in data.columns:
        data["symptoms"] = data["symptoms"].apply(lambda x: x if isinstance(x, list) else [])

        # Calculate symptom severity safely
        data["average_symptom_severity"] = data["symptoms"].apply(lambda x: sum(item["severity"] for item in x if isinstance(item, dict) and "severity" in item) / len(x) if x else 0)

        # Count total reported symptoms safely
        data["symptom_count"] = data["symptoms"].apply(lambda x: len(x) if isinstance(x, list) else 0)


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

    if "feeling_check" in data.columns:
        data["wellness_score"] = data["feeling_check"].apply(map_wellness_score)

    return data
