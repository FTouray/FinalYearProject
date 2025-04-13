from django.urls import path
from .views import ( MedicationListView, MedicationReminderListView, 
    chat_with_virtual_coach, create_category, create_comment, create_thread, delete_medication, exercise_step, 
    chat_history, fetch_medications_from_openfda, get_ai_health_trends, get_all_ai_health_trends, get_insights_summary_with_ai, get_last_synced_workout, get_predictive_feedback, get_quizset_quizzes, get_user_profile, latest_fitness_entry,
    get_local_notifications, get_medication_reminders, leaderboard, list_ai_recommendations,
    get_saved_medications, list_all_quizsets_and_progress, list_comments_for_thread, list_forum_categories, list_past_insights, list_quiz_attempts, list_threads_by_category, list_user_achievements, submit_quiz, today_fitness_summary, meal_step, glucose_step, glycaemic_response_main,
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
    path("log-meal/", log_meal, name="log-meal"),
    path("meal-log/history/", meal_log_history, name="meal-log-history"),
    path("meal-log/<int:meal_id>/", meal_log_detail, name="meal-log-detail"),

    # Food Data
    path("categories/", list_categories, name="list_categories"),
    path("categories/<int:category_id>/food-items/", list_food_items_by_category, name="list_food_items_by_category"),

    # Questionnaire
    path("questionnaire/start/", start_questionnaire, name="start-questionnaire"),
    path("questionnaire/symptom-step/", symptom_step, name="symptom-step"),
    path("questionnaire/glucose-step/", glucose_step, name="glucose-step"),
    path("questionnaire/meal-step/", meal_step, name="meal-step"),
    path("questionnaire/exercise-step/", exercise_step, name="exercise-step"),
    path("questionnaire/review/", review_answers, name="review-answers"),
    path("questionnaire/data-visualization/", questionnaire_data_visualization, name="data-visualization"),

    # Insights
    path("insights/summary/", get_insights_summary_with_ai, name="insights-summary"),
    path("insights/past/", list_past_insights, name="list-past-insight"),

    # Health Coach Dashboard
    path("dashboard/summary/", get_dashboard_summary, name="get_dashboard_summary"),
    path("dashboard/recommendations/", list_ai_recommendations, name="list_ai_recommendations"),
    path("dashboard/chat/", chat_with_virtual_coach, name="chat_with_virtual_coach"),
    path("dashboard/chat/history/", chat_history, name="chat_history"),

    # Health Data Sync
    path("health/log/", log_health_entry, name="log_health_entry"),
    path("health/today/", today_fitness_summary, name="today_fitness_summary"),
    path("health/latest/", latest_fitness_entry, name="latest_fitness_entry"),
    path("health/last-synced/", get_last_synced_workout, name="get_last_synced_workout"),

    # Health Trends
    path("health/trends/<str:period_type>/", get_ai_health_trends, name="get_ai_health_trends"),
    path("health/trends/", get_all_ai_health_trends, name="get_all_trend_summaries"),

    # Notifications
    path("notifications/", get_local_notifications, name="get_local_notifications"),
    path("notifications/queue/", queue_local_notification, name="queue_local_notification"),

    # Medication Support
    path("medications/search/", fetch_medications_from_openfda, name="fetch-medications"),
    path("medications/scan/", scan_medication, name="scan-medication"),
    path("medications/save/", save_medication, name="save-medication"),
    path("medications/list/", get_saved_medications, name="get-saved-medications"),
    path("medications/update/<int:medication_id>/", update_medication, name="update-medication"),
    path("medications/delete/<int:medication_id>/", delete_medication, name="delete-medication"),

    # Reminders
    path("reminders/set/", set_reminder, name="set-reminder"),
    path("reminders/", get_medication_reminders, name="get-reminders"),
    
    # Forum
    path("forum/categories/", list_forum_categories, name="list_forum_categories"),
    path("forum/categories/<int:category_id>/", list_categories, name="list_categories"),
    path("forum/category/create/", create_category, name="create_category"),
    path("forum/categories/<int:category_id>/threads/", list_threads_by_category, name="list_threads_by_category"),
    path("forum/threads/create/", create_thread, name="create_thread"),
    path("forum/threads/<int:thread_id>/comments/", list_comments_for_thread, name="list_comments_for_thread"),
    path("forum/comments/create/", create_comment, name="create_comment"),
    
    # Quiz
    path('gamification/quizsets/<int:level>/', get_quizset_quizzes, name='get_quizset_quizzes'),
    path('gamification/submit-quiz/<int:quizset_id>/', submit_quiz, name='submit_quiz'),
    path('gamification/quizsets/', list_all_quizsets_and_progress, name='list_quizsets'),
    path('gamification/achievements/', list_user_achievements, name='list_achievements'),
    path('gamification/leaderboard/', leaderboard, name='leaderboard'),
    path('user/profile/', get_user_profile, name='get_user_profile'),
    path('gamification/attempts/', list_quiz_attempts, name='list_quiz_attempts'),

    path('predictive-feedback/', get_predictive_feedback, name='predictive-feedback'),
]
