from django.urls import path

from .views import (MedicationListView, MedicationReminderListView, chat_with_health_coach, delete_medication, exercise_step, fetch_medications_from_rxnorm, get_ai_insights, get_chat_history, get_health_trends, get_insights, get_latest_fitness_data, get_local_notifications, get_medication_reminders, get_past_recommendations, get_saved_medications, get_today_health_data, meal_step, glucose_step, glycaemic_response_main, list_categories, list_food_items_by_category, log_glucose, log_meal, meal_log_detail,  meal_log_history, questionnaire_data_visualization, queue_local_notification, register_user, 
    login_user, review_answers, save_medication, scan_medication, set_reminder, settings_view, glucose_log_details, glucose_log_history, start_questionnaire, store_health_data, symptom_step, update_medication, virtual_health_coach)
from rest_framework_simplejwt.views import (TokenObtainPairView, TokenRefreshView)

urlpatterns = [
    # JWT Token related
    path("token/", TokenObtainPairView.as_view(), name="token_obtain_pair"),
    path("token/refresh/", TokenRefreshView.as_view(), name="token_refresh"),
    # Authentication endpoints
    path("register/", register_user, name="register"),
    path("login/", login_user, name="login"),
    # Glucose log endpoints
    path("glucose-log/", log_glucose, name="glucose-log"),  # Endpoint to log glucose data
    path("glucose-log/history/", glucose_log_history, name="glucose-log-history"),  # To list and filter glucose logs
    path("glucose-log/<int:logIDR>/", glucose_log_details, name="glucose-log-details"),  # Endpoint to get a specific glucose log by its ID
    # Settings endpoint
    path("settings/", settings_view, name="settings"),
    # Glycaemic Response Tracker endpoints
    path("glycaemic-response-main/", glycaemic_response_main, name="glycaemic-response-main" ),
    path("log-meal/", log_meal, name="log-meal"),  # Endpoint to log a meal
    # Meal log endpoints
    path("meal-log/history/", meal_log_history, name="meal-log-history"),  # Endpoint to get meal log history
    path("meal-log/<int:meal_id>/", meal_log_detail, name="meal-log-detail"),  # Endpoint to get meal details by ID
    # Food data endpoints
    path("categories/", list_categories, name="list_categories"),
    path("categories/<int:category_id>/food-items/", list_food_items_by_category, name="list_food_items_by_category" ),
    # Questionnaire endpoints
    path("questionnaire/start/", start_questionnaire, name="start-questionnaire"),  # Start the questionnaire
    path("questionnaire/symptom-step/", symptom_step, name="symptom-step"),  # Handle symptom step
    path("questionnaire/glucose-step/", glucose_step, name="glucose-step"),  # Handle glucose step
    path("questionnaire/meal-step/", meal_step, name="meal-step"),  # Handle diet step
    path("questionnaire/exercise-step/", exercise_step, name="exercise-step"),
    path("questionnaire/review/", review_answers, name="review-answers"),
    path("questionnaire/data-visualization/", questionnaire_data_visualization, name="data-visualization"),
    path("insights/", get_insights, name="insights"),  # Get insights
    path('ai-insights/', get_ai_insights, name='ai-insights'),
    # Virtual Health Coach
    path("virtual-health-coach/", virtual_health_coach, name="virtual_health_coach"),
    path("virtual-health-coach/recommendations/", get_past_recommendations, name="get_past_recommendations"),
    path("virtual-health-coach/chat/", chat_with_health_coach, name="chat_with_health_coach"),
    path("virtual-health-coach/chat/history/", get_chat_history, name="get_chat_history"),

     # Daily Health Overview for Flutter Health Plugin
    path("store-health-data/", store_health_data, name="store_health_data"),
    path("health-connect/today/", get_today_health_data, name="get_today_health_data"),
    path("health-connect/latest/", get_latest_fitness_data, name="get_latest_fitness_data"),

    # AI Health Trends
    path("health-trends/<str:period_type>/", get_health_trends, name="get_health_trends"),
    # Local Notifications
    path("local-notifications/", get_local_notifications, name="get_local_notifications"),
    path("queue-local-notification/", queue_local_notification, name="queue_local_notification"),
    # RxNorm API Integration
    path('fetch-medications/', fetch_medications_from_rxnorm, name='fetch-medications'),
    # OCR Scanning for Medication Labels
    path('scan-medication/', scan_medication, name='scan-medication'),
     # Medication CRUD Operations
    path('save-medication/', save_medication, name='save-medication'),
    path('get-saved-medications/', get_saved_medications, name='get-saved-medications'),
    path('update-medication/<int:medication_id>/', update_medication, name='update-medication'),
    path('delete-medication/<int:medication_id>/', delete_medication, name='delete-medication'),
    # Medication Reminders
    path('set-reminder/', set_reminder, name='set-reminder'),
    path('get-reminders/', get_medication_reminders, name='get-reminders'),

]