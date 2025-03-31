from django.urls import path
from .views import (
    MedicationListView, MedicationReminderListView,
    chat_with_virtual_coach, delete_medication, exercise_step, fetch_medications_from_rxnorm,
    chat_history, get_ai_health_trends, get_all_ai_health_trends, latest_fitness_entry,
    get_local_notifications, get_medication_reminders, list_ai_recommendations,
    get_saved_medications, questionnaire_get_ai_insights, questionnaire_get_insights, today_fitness_summary, meal_step, glucose_step, glycaemic_response_main,
    list_categories, list_food_items_by_category, log_glucose, log_meal, meal_log_detail,
    meal_log_history, questionnaire_data_visualization, queue_local_notification, register_user,
    login_user, review_answers, save_medication, scan_medication, set_reminder, settings_view,
    glucose_log_details, glucose_log_history, start_questionnaire, log_health_entry,
    symptom_step, update_medication, get_dashboard_summary
)
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView

urlpatterns = [
    # JWT Auth
    path("token/", TokenObtainPairView.as_view(), name="token_obtain_pair"),
    path("token/refresh/", TokenRefreshView.as_view(), name="token_refresh"),

    # Auth
    path("register/", register_user, name="register"),
    path("login/", login_user, name="login"),

    # Glucose Log
    path("glucose-log/", log_glucose, name="glucose-log"),
    path("glucose-log/history/", glucose_log_history, name="glucose-log-history"),
    path("glucose-log/<int:logIDR>/", glucose_log_details, name="glucose-log-details"),

    # Settings
    path("settings/", settings_view, name="settings"),

    # Glycaemic Response Tracker
    path("glycaemic-response/", glycaemic_response_main, name="glycaemic-response"),
    path("meal-log/create/", log_meal, name="log-meal"),
    path("meal-log/history/", meal_log_history, name="meal-log-history"),
    path("meal-log/<int:meal_id>/", meal_log_detail, name="meal-log-detail"),

    # Food Data
    path("food/categories/", list_categories, name="list_categories"),
    path("food/categories/<int:category_id>/items/", list_food_items_by_category, name="list_food_items_by_category"),

    # Questionnaire
    path("questionnaire/start/", start_questionnaire, name="start-questionnaire"),
    path("questionnaire/symptom/", symptom_step, name="symptom-step"),
    path("questionnaire/glucose/", glucose_step, name="glucose-step"),
    path("questionnaire/meal/", meal_step, name="meal-step"),
    path("questionnaire/exercise/", exercise_step, name="exercise-step"),
    path("questionnaire/review/", review_answers, name="review-answers"),
    path("questionnaire/visualize/", questionnaire_data_visualization, name="data-visualization"),

    # Insights
    path("insights/", questionnaire_get_insights, name="insights"),
    path("insights/ai/", questionnaire_get_ai_insights, name="ai-insights"),

    # Health Coach Dashboard
    path("dashboard/summary/", get_dashboard_summary, name="get_dashboard_summary"),
    path("dashboard/recommendations/", list_ai_recommendations, name="list_ai_recommendations"),
    path("dashboard/chat/", chat_with_virtual_coach, name="chat_with_virtual_coach"),
    path("dashboard/chat/history/", chat_history, name="chat_history"),

    # Health Data Sync
    path("health/log/", log_health_entry, name="log_health_entry"),
    path("health/today/", today_fitness_summary, name="today_fitness_summary"),
    path("health/latest/", latest_fitness_entry, name="latest_fitness_entry"),

    # Health Trends
    path("health/trends/<str:period_type>/", get_ai_health_trends, name="get_ai_health_trends"),
    path("health/trends/", get_all_ai_health_trends, name="get_all_trend_summaries"),

    # Notifications
    path("notifications/", get_local_notifications, name="get_local_notifications"),
    path("notifications/queue/", queue_local_notification, name="queue_local_notification"),

    # Medication Support
    path("medications/search/", fetch_medications_from_rxnorm, name="fetch-medications"),
    path("medications/scan/", scan_medication, name="scan-medication"),
    path("medications/save/", save_medication, name="save-medication"),
    path("medications/list/", get_saved_medications, name="get-saved-medications"),
    path("medications/update/<int:medication_id>/", update_medication, name="update-medication"),
    path("medications/delete/<int:medication_id>/", delete_medication, name="delete-medication"),

    # Reminders
    path("reminders/set/", set_reminder, name="set-reminder"),
    path("reminders/", get_medication_reminders, name="get-reminders"),
]
