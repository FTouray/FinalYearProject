from django.urls import path
from .views import (
    log_glucose,
    log_meal, 
    register_user, 
    login_user, 
    settings_view, 
    glucose_log_details,  
    glucose_log_history  
)
from rest_framework_simplejwt.views import (
    TokenObtainPairView,
    TokenRefreshView,
)

urlpatterns = [
    # JWT Token related
    path('token/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    
    # Authentication endpoints
    path('register/', register_user, name='register'),
    path('login/', login_user, name='login'),
    
    # Glucose log endpoints
    path('glucose-log/', log_glucose, name='glucose-log'),  # Endpoint to log glucose data
    path('glucose-log/history/', glucose_log_history, name='glucose-log-history'),  # To list and filter glucose logs
    path('glucose-log/<int:logIDR>/', glucose_log_details, name='glucose-log-details'),  # Endpoint to get a specific glucose log by its ID
    
    # Settings
    path('settings/', settings_view, name='settings'), 
    
    # Glycaemic Response Tracker endpoints
    path('api/log_meal/', log_meal, name='log_meal'),  # Endpoint to log a meal
]
