import json
import pandas as pd
from sklearn.preprocessing import StandardScaler, OrdinalEncoder


# Map textual feelings into numerical wellness scores
def map_feeling_to_score(feeling):
    mapping = {"good": 5, "okay": 3, "bad": 1}
    return mapping.get(feeling, 0)  # Default to 0 if feeling is missing


def load_data_from_db(
    questionnaire_queryset,
    symptom_queryset,
    glucose_check_queryset,
    meal_check_queryset,
    exercise_queryset,
    glucose_log_queryset,
    glycaemic_response_queryset,
    meal_queryset,
    feeling_queryset,
):
    """Loads and integrates data from multiple Django models."""

    # Convert querysets to pandas DataFrames
    questionnaire_df = pd.DataFrame(list(questionnaire_queryset.values("id", "user_id", "created_at", "feeling_check_id")))
    symptom_df = pd.DataFrame(list(symptom_queryset.values()))
    glucose_check_df = pd.DataFrame(list(glucose_check_queryset.values()))
    # Convert MealCheck queryset to DataFrame and include `weighted_gi`
    meal_check_data = []
    for meal in meal_check_queryset:
        meal_check_data.append({
            "id": meal.id,
            "session_id": meal.session_id,
            "skipped_meals": json.loads(meal.skipped_meals) if isinstance(meal.skipped_meals, str) else (meal.skipped_meals or []),
            "wellness_impact": meal.wellness_impact,
            "notes": meal.notes,
            "created_at": meal.created_at,
            "weighted_gi": meal.weighted_gi  
        })
    meal_check_df = pd.DataFrame(meal_check_data)
    exercise_df = pd.DataFrame(list(exercise_queryset.values()))
    glucose_log_df = pd.DataFrame(list(glucose_log_queryset.values()))
    glycaemic_response_df = pd.DataFrame(list(glycaemic_response_queryset.values()))
    meal_df = pd.DataFrame(list(meal_queryset.values()))
    feeling_df = pd.DataFrame(list(feeling_queryset.values()))

    # Debugging: Print column names before merging
    print(f"Questionnaire Columns: {questionnaire_df.columns.tolist()}")
    print(f"Symptoms Columns: {symptom_df.columns.tolist()}")
    print(f"Glucose Check Columns: {glucose_check_df.columns.tolist()}")
    print(f"Meal Check Columns: {meal_check_df.columns.tolist()}")
    print(f"Exercise Check Columns: {exercise_df.columns.tolist()}")

    # Ensure FeelingCheck has user_id and feeling
    if not feeling_df.empty and "feeling" in feeling_df.columns:
        feeling_df["wellness_score"] = feeling_df["feeling"].apply(map_feeling_to_score)

    # Ensure 'id' is still present
    if "id" not in questionnaire_df.columns:
        print("Critical Error: 'id' is missing in questionnaire_df before merging!")
        raise ValueError("Missing 'id' column in questionnaire DataFrame.")

    # Merge `FeelingCheck` with `QuestionnaireSession` on `feeling_check_id`
    print(f"Before merging with FeelingCheck: {questionnaire_df.columns.tolist()}")
    if (
        not questionnaire_df.empty
        and "feeling_check_id" in questionnaire_df.columns
        and not feeling_df.empty
    ):
        questionnaire_df = questionnaire_df.merge(
            feeling_df.rename(columns={"id": "feeling_id"})[
                ["feeling_id", "wellness_score"]
            ],
            left_on="feeling_check_id",
            right_on="feeling_id",
            how="left",
        ).drop(columns=["feeling_id"], errors="ignore")
    print(f"After merging with FeelingCheck: {questionnaire_df.columns.tolist()}")

    # Ensure 'id' is still present after merging with FeelingCheck
    if "id" not in questionnaire_df.columns:
        print(
            "Error: 'id' column missing in questionnaire_df after merging with FeelingCheck!"
        )
        raise ValueError("Missing 'id' column after merging with FeelingCheck.")

    # Debugging: Check before filtering
    print(
        f"Before filtering valid_ids, Questionnaire DF Columns: {questionnaire_df.columns.tolist()}"
    )

    # Ensure questionnaire_df is not empty before filtering
    if not questionnaire_df.empty and "id" in questionnaire_df.columns:
        valid_ids = (
            set(symptom_df.get("session_id", []))
            & set(glucose_check_df.get("session_id", []))
            & set(meal_check_df.get("session_id", []))
            & set(exercise_df.get("session_id", []))
        )

        if valid_ids:
            questionnaire_df = questionnaire_df[questionnaire_df["id"].isin(valid_ids)]
            print(
                f"Filtered Questionnaire DF, Remaining Rows: {len(questionnaire_df)}"
            )
        else:
            print(
                "Warning: No valid questionnaire IDs found! Some sessions may be missing related data."
            )

    # Ensure 'id' is still present after filtering
    if "id" not in questionnaire_df.columns:
        print(
            "Error: 'id' column missing after filtering valid questionnaire responses!"
        )
        raise ValueError("Missing 'id' column after filtering.")

    # Merge additional data (ensure session_id is present)
    for df, name in [
        (symptom_df, "SymptomCheck"),
        (glucose_check_df, "GlucoseCheck"),
        (meal_check_df, "MealCheck"),
        (exercise_df, "ExerciseCheck"),
    ]:
        print(f"Before merging {name}: {questionnaire_df.columns.tolist()}")

        if not df.empty and "session_id" in df.columns:
            df = df.rename(columns={"id": f"{name.lower()}_id", "created_at": f"{name.lower()}_created_at"})  # Rename created_at

            questionnaire_df = questionnaire_df.merge(
                df, left_on="id", right_on="session_id", how="left"
            ).drop(columns=["session_id"], errors="ignore")  # Remove session_id to avoid duplication

        print(f"After merging {name}: {questionnaire_df.columns.tolist()}")

        # Ensure 'id' still exists
        if "id" not in questionnaire_df.columns:
            print(f"Error: 'id' column missing after merging {name}!")
            raise ValueError(f"Missing 'id' column after merging {name}.")

    # Merge meal data with glycaemic response if both exist
    if not meal_df.empty and not glycaemic_response_df.empty:
        common_cols = ["user_id", "created_at"]
        if all(
            col in meal_df.columns and col in glycaemic_response_df.columns
            for col in common_cols
        ):
            meal_df = meal_df.merge(
                glycaemic_response_df,
                left_on=common_cols,
                right_on=common_cols,
                how="left",
                suffixes=("", "_glycaemic"),
            ).drop_duplicates()

    # Combine questionnaire, glucose logs, and meal data
    combined_df = pd.concat(
        [questionnaire_df, glucose_log_df, meal_df], axis=0, ignore_index=True
    )

    # Final check before returning
    if "id" not in combined_df.columns:
        print("Error: 'id' column missing from final dataset!")
        raise ValueError("Final dataset is missing 'id' column.")

    return combined_df


def preprocess_data(data, target_column=None):
    """Preprocess the dataset by handling missing values, encoding categories, and scaling numerical features."""

    if data.empty:
        print("Warning: Empty dataset received for preprocessing!")
        return data, None

    # Ensure all date columns are in datetime format
    for col in data.columns:
        if data[col].dtype == 'object':
            try:
                data[col] = pd.to_datetime(data[col])
            except (ValueError, TypeError):
                pass  # Ignore columns that cannot be converted

    # Identify and exclude Datetime Columns before scaling
    datetime_cols = data.select_dtypes(include=["datetime64"]).columns
    if len(datetime_cols) > 0:
        print(f"Excluding datetime columns from scaling: {list(datetime_cols)}")
        data = data.drop(columns=datetime_cols)

    # Handle missing values (fill numerics with median, categorical with mode)
    data = data.fillna(data.median(numeric_only=True))

    if target_column and target_column in data.columns:
        X = data.drop(columns=[target_column])
        y = data[target_column]
    else:
        X, y = data, None

    # Convert lists & dictionaries to string format for consistency
    for col in X.columns:
        if X[col].apply(lambda x: isinstance(x, dict)).any():
            X[col] = X[col].apply(lambda x: json.dumps(x) if isinstance(x, dict) else str(x))
        if X[col].apply(lambda x: isinstance(x, list)).any():
            X[col] = X[col].apply(lambda x: ",".join(map(str, x)) if isinstance(x, list) else str(x))

    # Ordinal Encoding for Ordered Categorical Variables
    ordinal_mappings = {"exercise_intensity": ["Low", "Moderate", "Vigorous"]}
    for col, categories in ordinal_mappings.items():
        if col in X.columns:
            X[col] = X[col].fillna(categories[0])
            encoder = OrdinalEncoder(categories=[categories], handle_unknown="use_encoded_value", unknown_value=-1)
            X[col] = encoder.fit_transform(X[[col]])

    # One-Hot Encoding for Unordered Categorical Variables
    X = pd.get_dummies(X)

    # Ensure all remaining columns are numeric before scaling
    for col in X.columns:
        X[col] = pd.to_numeric(X[col], errors='coerce')

    # Scale numeric features only
    num_cols = X.select_dtypes(include=["number"]).columns
    if not num_cols.empty:
        scaler = StandardScaler()
        X[num_cols] = scaler.fit_transform(X[num_cols])

    return X, y
