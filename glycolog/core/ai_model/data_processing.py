import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler


def load_data_from_db(glucose_queryset, questionnaire_queryset, meal_queryset, glycaemic_response_queryset):
    """
    Converts multiple Django QuerySets into a combined Pandas DataFrame.
    - GlucoseLog (real-time logs)
    - Questionnaire meals (MealCheck)
    - Glycaemic Response (tracked meals)
    """

    # Load individual datasets
    glucose_data = pd.DataFrame(list(glucose_queryset.values()))
    questionnaire_data = pd.DataFrame(list(questionnaire_queryset.values()))
    meal_data = pd.DataFrame(list(meal_queryset.values()))
    glycaemic_response_data = pd.DataFrame(list(glycaemic_response_queryset.values()))

    # Merge meals with Glycaemic Response Tracker (GRT)
    meal_data = meal_data.merge(glycaemic_response_data, on="user", how="left")

    # Combine all datasets
    combined_data = pd.concat([glucose_data, questionnaire_data, meal_data], axis=0, ignore_index=True)

    return combined_data




def preprocess_data(data, target_column):
    """
    Preprocesses the data:
    - Handles missing values
    - Scales numeric features
    - Encodes categorical variables
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
    X = data.drop(columns=[target_column])
    y = data[target_column] if target_column else None

    # Scale numeric features
    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X.select_dtypes(include=["float64", "int64"]))
    X_scaled = pd.DataFrame(
        X_scaled, columns=X.select_dtypes(include=["float64", "int64"]).columns
    )

    # Add categorical variables back
    X_categorical = pd.get_dummies(X.select_dtypes(include=["object", "category"]))
    X_final = pd.concat([X_scaled, X_categorical], axis=1)

    return X_final, y
