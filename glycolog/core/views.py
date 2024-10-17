from rest_framework import status
from rest_framework.response import Response
from rest_framework.decorators import api_view
from django.contrib.auth import authenticate
from rest_framework_simplejwt.tokens import RefreshToken, AccessToken
from .serializers import GlucoseLogSerializer, RegisterSerializer, LoginSerializer, SettingsSerializer
from .models import CustomUser  
from django.contrib.auth import get_user_model
from rest_framework.permissions import IsAuthenticated
from rest_framework.permissions import AllowAny
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny


User = get_user_model()

@api_view(['POST'])
@permission_classes([AllowAny])  # Allow any user to access this endpoint
def register_user(request):
    serializer = RegisterSerializer(data=request.data)

    if serializer.is_valid():
        serializer.save()
        return Response({"message": "User registered successfully"}, status=status.HTTP_201_CREATED)
    else:
        # Return validation errors from the serializer
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

@api_view(['POST'])
@permission_classes([AllowAny])  
def login_user(request):
    serializer = LoginSerializer(data=request.data)

    if serializer.is_valid():
        username = serializer.validated_data['username']
        password = serializer.validated_data['password']
        
        # Authenticate user
        user = authenticate(request, username=username, password=password)

        if user is not None:
           # Generate access token
            access = AccessToken.for_user(user)

            return Response({
                "access": str(access),  # Include the access token in the response
                "first_name": user.first_name,  # Include the first name in the response
                "username": user.username
            }, status=status.HTTP_200_OK)
        else:
            return Response({"error": "Username or password is incorrect."}, status=status.HTTP_401_UNAUTHORIZED)
    else:
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
@api_view(['POST'])
@permission_classes([IsAuthenticated])  # Ensure the user is authenticated
def log_glucose(request):
    serializer = GlucoseLogSerializer(data=request.data)

    if serializer.is_valid():
        serializer.save(user=request.user)  # Save the glucose log with the authenticated user
        return Response({"message": "Glucose log created successfully"}, status=status.HTTP_201_CREATED)
    else:
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated])  # Ensure the user is authenticated
def settings_view(request):
    user = request.user  # Get the currently authenticated user

    if request.method == 'GET':
        # Return user settings
        settings_data = {
            'selectedUnit': user.selected_unit,  # Assuming you have a field for this
            'notificationsEnabled': user.notifications_enabled,  # Assuming you have this too
            'darkModeEnabled': user.dark_mode_enabled,  # And this
        }
        return Response(settings_data, status=status.HTTP_200_OK)

    elif request.method == 'POST':
        # Update user settings
        selected_unit = request.data.get('selectedUnit')
        notifications_enabled = request.data.get('notificationsEnabled')
        dark_mode_enabled = request.data.get('darkModeEnabled')

        user.selected_unit = selected_unit
        user.notifications_enabled = notifications_enabled
        user.dark_mode_enabled = dark_mode_enabled
        user.save()

        return Response({"message": "Settings updated successfully"}, status=status.HTTP_200_OK)
