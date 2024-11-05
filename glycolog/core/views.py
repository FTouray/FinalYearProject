from rest_framework import status
from rest_framework.response import Response
from django.contrib.auth import authenticate
from rest_framework_simplejwt.tokens import RefreshToken, AccessToken
from .serializers import FoodCategorySerializer, FoodItemSerializer, GlucoseLogSerializer, MealSerializer, RegisterSerializer, LoginSerializer, SettingsSerializer
from .models import CustomUser, FoodCategory, FoodItem, GlucoseLog, GlycaemicResponseTracker, Meal  
from django.contrib.auth import get_user_model
from rest_framework.permissions import IsAuthenticated
from rest_framework.permissions import AllowAny
from rest_framework.decorators import api_view, permission_classes
from django.shortcuts import get_object_or_404, render
from django.db.models import Q
from django.db.models import Avg


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
            refresh = RefreshToken.for_user(user)
            access = AccessToken.for_user(user)

            return Response({
                "access": str(access),  # Include the access token in the response
                "refresh": str(refresh),  # Refresh token
                "first_name": user.first_name,  # Include the first name in the response
                "username": user.username
            }, status=status.HTTP_200_OK)
        else:
            return Response({"error": "Username or password is incorrect."}, status=status.HTTP_401_UNAUTHORIZED)
    else:
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

@api_view(['GET','POST'])
@permission_classes([IsAuthenticated])  # Ensure the user is authenticated
def log_glucose(request):
    if request.method == 'GET':
        logs = GlucoseLog.objects.filter(user=request.user)  # Filter logs by the authenticated user
        serializer = GlucoseLogSerializer(logs, many=True)
        return Response({'logs': serializer.data}, status=status.HTTP_200_OK)
    
    elif request.method == 'POST':
        print("Incoming request data:", request.data)  # Log the incoming data to the console
        data = request.data.copy()
        serializer = GlucoseLogSerializer(data=data, context={'request': request})  # Pass the request context

        if serializer.is_valid():
            serializer.save()
            return Response({"message": "Glucose log created successfully"}, status=status.HTTP_201_CREATED)
        else:
            print("Serializer errors:", serializer.errors) # Log the errors to the console
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

@api_view(['GET']) 
@permission_classes([IsAuthenticated]) 
def glucose_log_history(request):
    """
    View to list or filter glucose logs for the authenticated user.
    Supports filtering by date range and glucose level.
    """
    user = request.user  # Get the current authenticated user
    logs = GlucoseLog.objects.filter(user=user)  # Get all logs for the user

    # Retrieve filter parameters from the request
    start_date = request.GET.get('start_date')
    end_date = request.GET.get('end_date')
    glucose_level = request.GET.get('glucose_level')
    filter_type = request.GET.get('filter_type', 'equal')  # Optional, defaults to 'equal'

    # Apply date range filtering if both dates are provided
    if start_date and end_date:
        logs = logs.filter(timestamp__range=[start_date, end_date])

    # Apply glucose level filtering
    if glucose_level:
        try:
            glucose_level = float(glucose_level)  # Ensure the input is numeric
            if filter_type == 'greater':
                logs = logs.filter(glucose_level__gt=glucose_level)
            elif filter_type == 'less':
                logs = logs.filter(glucose_level__lt=glucose_level)
            else:  # Default is 'equal'
                logs = logs.filter(glucose_level=glucose_level)
        except ValueError:
            return Response({"error": "Invalid glucose level"}, status=status.HTTP_400_BAD_REQUEST)

    # Serialize the logs data
    serializer = GlucoseLogSerializer(logs, many=True)
    return Response(serializer.data, status=status.HTTP_200_OK)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def glucose_log_details(request, id):
    """
    View to retrieve details of a specific glucose log by its ID.
    """
    log = get_object_or_404(GlucoseLog, id=id, user=request.user)  # Ensure the log belongs to the user
    serializer = GlucoseLogSerializer(log)
    return Response(serializer.data, status=status.HTTP_200_OK)

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


@api_view(["GET", "POST"])
@permission_classes([IsAuthenticated])
def glycaemic_response_main(request):
    # Retrieve recent glycaemic logs for this user
    user = request.user  # Get current user
    logs = GlycaemicResponseTracker.objects.filter(user=user).order_by("-created_at")

    # Calculate last, average, and graph points for glycaemic response
    last_log = logs[0].gi_level if logs else None
    average_log = sum(log.gi_level for log in logs) / len(logs) if logs else None

    # Retrieve all meal logs for the user
    all_meal_logs = Meal.objects.filter(user=user).order_by("-timestamp")

    # Retrieve the last meal for the user
    last_meal = all_meal_logs.first()
    if last_meal is None:
        print("No meals found for the user.")
    else:
        print(f"Last meal found: {last_meal.mealId}, Total GI: {last_meal.total_glycaemic_index}")

    meals = Meal.objects.filter(user=user)
    avg_response = sum(meal.total_glycaemic_index for meal in meals) / len(meals) if meals else 0
    # JSON response with computed data
    response_data = {
        "last_log": last_log,
        "average_log": average_log,
        "recent_logs": [
            {
                "id": log.id,
                "created_at": log.created_at,
                "gi_level": log.gi_level,
                "response_patterns": log.response_patterns,
            }
            for log in logs
        ],
        "lastResponse": (last_meal.total_glycaemic_index if last_meal else 0),
        "avgResponse": avg_response,
        "all_meal_logs": [
            {
                "mealId": meal.mealId,
                "timestamp": meal.timestamp,
                "total_glycaemic_index": meal.total_glycaemic_index,
                "total_carbs": meal.total_carbs,
            }
            for meal in all_meal_logs
        ],
    }
    print(all_meal_logs)
    return Response(response_data, status=status.HTTP_200_OK)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def log_meal(request):
    """
    Endpoint to log a new meal, calculating total glycemic index and carbs based on food items.
    """
    data = request.data.copy()
    data['user'] = request.user.id  # Link the meal to the authenticated user

    serializer = MealSerializer(data=data, context={'request': request})

    # Ensure 'food_item_ids' holds the food IDs for the meal
    food_item_ids = data.pop("food_items", [])
    data["food_items"] = food_item_ids  # Prepare to save food item IDs

    if serializer.is_valid():
        serializer.save()  # This calls the `create` method on the serializer
        return Response({"message": "Meal logged successfully", "meal": serializer.data}, status=status.HTTP_201_CREATED)
    else:
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

@api_view(['GET'])
def list_categories(request):
    categories = FoodCategory.objects.all()
    serializer = FoodCategorySerializer(categories, many=True)
    return Response(serializer.data)

@api_view(['GET'])
def list_food_items_by_category(request, category_id):
    try:
        food_items = FoodItem.objects.filter(category_id=category_id)
        serializer = FoodItemSerializer(food_items, many=True)
        return Response(serializer.data)
    except Exception as e:
        return Response({"error": str(e)}, status=500)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def meal_log_history(request):
    user = request.user  # Get the current authenticated user
    meals = Meal.objects.filter(user=user).order_by(
        "-timestamp"
    )  # Get all meals for the user

    # Retrieve filter parameters from the request
    start_date = request.GET.get("start_date")
    end_date = request.GET.get("end_date")

    # Apply date range filtering if both dates are provided
    if start_date and end_date:
        meals = meals.filter(timestamp__range=[start_date, end_date])

    # Serialize the meals data
    serializer = MealSerializer(meals, many=True)
    return Response(serializer.data, status=status.HTTP_200_OK)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def meal_log_detail(request, meal_id):
    meal = get_object_or_404(Meal, id=meal_id, user=request.user)  # Ensure the meal belongs to the user
    serializer = MealSerializer(meal)
    return Response(serializer.data, status=status.HTTP_200_OK)
