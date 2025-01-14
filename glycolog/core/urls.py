from django.urls import path
from .views import (exercise_step, meal_step, glucose_step, glycaemic_response_main, insights_graph_data, list_categories, list_food_items_by_category, log_glucose, log_meal, meal_log_detail,  meal_log_history, questionnaire_visualization_data, register_user, 
    login_user, review_answers, settings_view, glucose_log_details, glucose_log_history, start_questionnaire, symptom_step)
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
    path("questionnaire/visualization-data/", questionnaire_visualization_data, name="questionnaire-visualization-data"),
    path("insights-graph/", insights_graph_data, name="insights-graph-data"),  # Get insights
]