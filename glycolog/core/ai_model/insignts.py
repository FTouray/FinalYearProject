class InsightsGenerator:
    @staticmethod
    def generate_personal_insights(user_data):
        """
        Generate personalized insights for a specific user.

        Args:
            user_data (pd.DataFrame): User-specific data.

        Returns:
            dict: Insights about glucose levels, symptoms, meals, and exercise.
        """
        insights = {
            # **Glucose Insights**
            "high_glucose_sessions": user_data[user_data["glucose_level"] > 180].shape[0],
            "low_glucose_sessions": user_data[user_data["glucose_level"] < 70].shape[0],
            "glucose_variability": user_data["glucose_level"].std(),

            # **Sleep & Stress Insights**
            "low_sleep_sessions": user_data[user_data["sleep_hours"] < 6].shape[0],
            "stress_correlation": user_data.corr().loc["stress", "glucose_level"],

            # **Glycaemic Response Insights**
            "high_gi_meal_count": user_data[user_data["weighted_gi"] > 50].shape[0],
            "post_meal_spikes": user_data[user_data["post_meal_glucose_spike"] > 50].shape[0],
            "glycaemic_response_score": user_data["glycaemic_response_score"].mean(),

            # **Meal Pattern Insights**
            "skipped_meal_count": user_data[user_data["skipped_meals"].apply(len) > 0].shape[0],
            "meal_impact_correlation": user_data.corr().loc["meal_impact", "glucose_level"],

            # **Exercise & Glucose Relationship**
            "exercise_duration_avg": user_data["exercise_duration"].mean(),
            "exercise_intensity_avg": user_data["exercise_intensity_numeric"].mean(),
            "exercise_glucose_stability": user_data.corr().loc["exercise_score", "glucose_variability"],

            # **Symptoms Analysis**
            "frequent_symptoms": user_data["symptoms"].explode().value_counts().head(3).to_dict(),
            "severe_symptom_correlation": user_data.corr().loc["average_symptom_severity", "glucose_level"],
        }

        return insights

    @staticmethod
    def generate_general_trends(all_users_data):
        """
        Generate aggregate trends across all users.

        Args:
            all_users_data (pd.DataFrame): Combined dataset of all users.

        Returns:
            dict: Trends across the entire dataset.
        """
        trends = {
            # **Glucose Trends**
            "avg_glucose": all_users_data["glucose_level"].mean(),
            "avg_glucose_variability": all_users_data["glucose_level"].std(),

            # **Meal Trends**
            "avg_weighted_gi": all_users_data["weighted_gi"].mean(),
            "avg_skipped_meals": all_users_data["skipped_meals"].apply(len).mean(),

            # **Exercise Trends**
            "avg_exercise_duration": all_users_data["exercise_duration"].mean(),
            "avg_exercise_intensity": all_users_data["exercise_intensity_numeric"].mean(),
            "exercise_effect_on_glucose": all_users_data.corr().loc["exercise_score", "glucose_variability"],

            # **Symptom Trends**
            "most_common_symptoms": all_users_data["symptoms"].explode().value_counts().head(3).to_dict(),
            "symptom_glucose_correlation": all_users_data.corr().loc["average_symptom_severity", "glucose_level"],

            # **Wellness Trends**
            "avg_sleep_hours": all_users_data["sleep_hours"].mean(),
            "stress_glucose_correlation": all_users_data.corr().loc["stress", "glucose_level"],
        }

        return trends
