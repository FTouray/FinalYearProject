from django.urls import path
from .views import log_glucose, register_user, login_user, settings_view  # Import your new SettingsView

from rest_framework_simplejwt.views import (
    TokenObtainPairView,
    TokenRefreshView,
)

urlpatterns = [
    path('token/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('register/', register_user, name='register'),
    path('login/', login_user, name='login'),
    path('glucose-log/', log_glucose, name='glucose-log'),
    path('settings/', settings_view, name='settings'), 
]
