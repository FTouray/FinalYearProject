import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler, OrdinalEncoder

def load_data_from_db(glucose_queryset, glucose_log_queryset, questionnaire_queryset, meal_queryset, glycaemic_response_queryset, 
                      symptom_queryset, exercise_queryset):
    """
    Converts multiple Django QuerySets into a fully integrated Pandas DataFrame.
    - GlucoseLog (real-time logs)
    - Questionnaire Data (includes meals, glucose, symptoms, and exercise)
    - Glycaemic Response (tracked meals)
    """

    # Convert QuerySets to DataFrames
    glucose_data = pd.DataFrame(list(glucose_queryset.values()))
    glucose_log_data = pd.DataFrame(list(glucose_log_queryset.values()))  # Separate glucose logs
    questionnaire_data = pd.DataFrame(list(questionnaire_queryset.values()))
    meal_data = pd.DataFrame(list(meal_queryset.values()))
    glycaemic_response_data = pd.DataFrame(list(glycaemic_response_queryset.values()))
    symptom_data = pd.DataFrame(list(symptom_queryset.values()))
    exercise_data = pd.DataFrame(list(exercise_queryset.values()))

    # Ensure `session_id` is present in the DataFrames to merge properly
    if "session_id" in symptom_data.columns and "session_id" in exercise_data.columns:
        questionnaire_data = questionnaire_data.merge(symptom_data, on="session_id", how="left")
        questionnaire_data = questionnaire_data.merge(exercise_data, on="session_id", how="left")

    if "meal_context" in glucose_log_data.columns:
        # Assign glucose levels based on context when available
        glucose_log_data["glucose_context_fasting"] = glucose_log_data["glucose_level"].where(glucose_log_data["meal_context"] == "fasting")
        glucose_log_data["glucose_context_pre_meal"] = glucose_log_data["glucose_level"].where(glucose_log_data["meal_context"] == "pre_meal")
        glucose_log_data["glucose_context_post_meal"] = glucose_log_data["glucose_level"].where(glucose_log_data["meal_context"] == "post_meal")

        # Track cases where `meal_context` is missing
        glucose_log_data["glucose_context_undefined"] = glucose_log_data["glucose_level"].where(glucose_log_data["meal_context"].isna())

    else:
        # If `meal_context` column is missing, treat all data as undefined
        glucose_log_data["glucose_context_undefined"] = glucose_log_data["glucose_level"]

    # Merge meals with Glycaemic Response Tracker (GRT) on `user_id` and `timestamp`
    meal_data = meal_data.merge(glycaemic_response_data, on=["user_id", "created_at"], how="left")

    # Merge Glucose Logs with Questionnaire Glucose Check
    if "user_id" in glucose_data.columns and "user_id" in questionnaire_data.columns:
        glucose_combined = pd.concat([glucose_data, questionnaire_data], axis=0, ignore_index=True)
    else:
        glucose_combined = questionnaire_data  # If no glucose logs exist yet, fallback to questionnaire data

    # Merge all datasets into a single DataFrame
    combined_data = pd.concat([glucose_combined, meal_data], axis=0, ignore_index=True)

    return combined_data

def preprocess_data(data, target_column=None):
    """
    Preprocesses the data:
    - Handles missing values
    - Encodes categorical variables (Ordinal + One-Hot Encoding)
    - Scales numeric features
    - Flattens JSON fields (e.g., symptoms)
    """

    # Flatten JSON fields (e.g., symptoms)
    if "symptoms" in data.columns:
        data["average_symptom_severity"] = data["symptoms"].apply(
            lambda x: sum(item["severity"] for item in x) / len(x) if x else 0
        )
        data["symptom_count"] = data["symptoms"].apply(len)

    # Handle missing values
    data = data.fillna(data.median(numeric_only=True))

    # Separate features and target
    X = data.drop(columns=[target_column]) if target_column else data
    y = data[target_column] if target_column else None

    # **Ordinal Encoding for Ordered Categorical Variables**
    ordinal_cols = ["exercise_intensity", "post_exercise_feeling"]
    ordinal_mappings = {
        "exercise_intensity": ["Low", "Moderate", "Vigorous"],
        "post_exercise_feeling": ["Tired", "Neutral", "Energised"]
    }

    for col, categories in ordinal_mappings.items():
        if col in X.columns:
            encoder = OrdinalEncoder(categories=[categories])
            X[col] = encoder.fit_transform(X[[col]])

    # **One-Hot Encoding for Unordered Categorical Variables**
    X_categorical = pd.get_dummies(X.select_dtypes(include=["object", "category"]))

    # **Scale numeric features**
    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X.select_dtypes(include=["float64", "int64"]))
    X_scaled = pd.DataFrame(X_scaled, columns=X.select_dtypes(include=["float64", "int64"]).columns)

    # Merge scaled and categorical data
    X_final = pd.concat([X_scaled, X_categorical], axis=1)

    return X_final, y
