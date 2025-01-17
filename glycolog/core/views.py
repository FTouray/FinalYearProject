from datetime import datetime
from django.http import JsonResponse
import pandas as pd
from django.db.models import Max
from rest_framework import status
from rest_framework.response import Response
from django.contrib.auth import authenticate
from rest_framework_simplejwt.tokens import RefreshToken, AccessToken
from .serializers import ExerciseCheckSerializer, FoodCategorySerializer, FoodItemSerializer, GlucoseCheckSerializer, GlucoseLogSerializer, MealCheckSerializer, MealSerializer, QuestionnaireSessionSerializer, RegisterSerializer, LoginSerializer, SettingsSerializer, SymptomCheckSerializer
from .models import CustomUser, FeelingCheck, FoodCategory, FoodItem, GlucoseCheck, GlucoseLog, GlycaemicResponseTracker, Meal, QuestionnaireSession  
from django.contrib.auth import get_user_model
from rest_framework.permissions import IsAuthenticated
from rest_framework.permissions import AllowAny
from rest_framework.decorators import api_view, permission_classes
from django.shortcuts import get_object_or_404, render
from django.db.models import Q
from django.db.models import Avg
import joblib


User = get_user_model()


def parse_date(date_str):
    try:
        return datetime.strptime(date_str, "%d-%m-%Y")
    except ValueError:
        return None


@api_view(['POST'])
@permission_classes([AllowAny])  # Allow any user to access this endpoint
def register_user(request):
    print("Incoming data:", request.data)
    serializer = RegisterSerializer(data=request.data)

    if serializer.is_valid():
        serializer.save()
        return Response({"message": "User registered successfully"}, status=status.HTTP_201_CREATED)
    else:
        # Print validation errors for debugging
        print("Validation errors:", serializer.errors)
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
    start_date = parse_date(request.GET.get("start_date"))
    end_date = parse_date(request.GET.get("end_date"))
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
    # user = request.user  # Get the currently authenticated user

    # if request.method == 'GET':
    #     # Return user settings
    #     settings_data = {
    #         'selectedUnit': user.selected_unit,  
    #         'notificationsEnabled': user.notifications_enabled,  
    #         'darkModeEnabled': user.dark_mode_enabled,  
    #     }
    #     return Response(settings_data, status=status.HTTP_200_OK)

    # elif request.method == 'POST':
    #     # Update user settings
    #     selected_unit = request.data.get('selectedUnit')
    #     notifications_enabled = request.data.get('notificationsEnabled')
    #     dark_mode_enabled = request.data.get('darkModeEnabled')

    #     user.selected_unit = selected_unit
    #     user.notifications_enabled = notifications_enabled
    #     user.dark_mode_enabled = dark_mode_enabled
    #     user.save()

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
            }
            for log in logs
        ],
        "lastResponse": (last_meal.total_glycaemic_index if last_meal else 0),
        "avgResponse": avg_response,
        "all_meal_logs": [
            {
                "mealId": meal.mealId,
                "user_meal_id": meal.user_meal_id,
                "name": meal.name,
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
    # start_date = parse_date(request.GET.get("start_date"))
    # end_date = parse_date(request.GET.get("end_date"))
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


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def start_questionnaire(request):
    user = request.user
    feeling = request.data.get("feeling")

    if not feeling:
        return Response(
            {"error": "Feeling is required to start the questionnaire"}, status=400
        )

    # Create FeelingCheck
    feeling_check = FeelingCheck.objects.create(user=user, feeling=feeling)

    # Start QuestionnaireSession
    session = QuestionnaireSession.objects.create(
        user=user, feeling_check=feeling_check
    )

    serializer = QuestionnaireSessionSerializer(session)
    return Response(serializer.data, status=201)


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def symptom_step(request):
    user = request.user
    session = QuestionnaireSession.objects.filter(user=user, completed=False).last()

    if not session:
        print("No active session found for user:", user.id)  # Debug
        return Response({"error": "No active questionnaire session found."}, status=404)

   
    print("Received data:", request.data)  # Debug


    data = request.data.copy()
    data["session"] = session.id  # Add session ID to the data

    # Save symptoms
    serializer = SymptomCheckSerializer(data=data, context={"request": request})
    if serializer.is_valid():
        serializer.save(session=session)  # Link symptoms to the session
        session.save()
        return Response({"message": "Symptoms logged successfully"}, status=201)
    else:
        print("Serializer errors:", serializer.errors)  # Debug
        return Response(serializer.errors, status=400)


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def glucose_step(request):
    user = request.user
    session = QuestionnaireSession.objects.filter(user=user, completed=False).last()

    if not session:
        return Response({"error": "No active questionnaire session found."}, status=404)

    data = request.data.copy()
    data["session"] = session.id

    # Fetch target_min and target_max from the request data
    target_min = request.data.get("target_min")
    target_max = request.data.get("target_max")
    glucose_level = request.data.get("glucose_level")

    data["target_min"] = float(target_min)
    data["target_max"] = float(target_max)
    data["glucose_level"] = float(glucose_level)

    if target_min is None or target_max is None:
        return Response(
            {"error": "Target range (min and max) is required."}, status=400
        )

    if not glucose_level:
        return Response({"error": "Glucose level is required."}, status=400)

    # Save glucose check
    data.update(
        {
            "glucose_level": glucose_level,
            "target_min": target_min,
            "target_max": target_max,
        }
    )
    serializer = GlucoseCheckSerializer(data=data)
    if serializer.is_valid():
        serializer.save(session=session)
        session.save()
        return Response(serializer.data, status=201)
    return Response(serializer.errors, status=400)(serializer.errors, status=400)


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def meal_step(request):
    """
    Handles the diet step in the questionnaire.
    """
    user = request.user
    session = QuestionnaireSession.objects.filter(user=user, completed=False).last()

    if not session:
        return Response({"error": "No active questionnaire session found."}, status=404)

    data = request.data.copy()
    data["session"] = session.id  # Add session ID to the data

    serializer = MealCheckSerializer(data=data)
    if serializer.is_valid():
        meal_check = serializer.save()

        session.save()

        return Response(
            {
                "message": "Diet information logged successfully.",
                "meal_check": MealCheckSerializer(meal_check).data,
            },
            status=201,
        )
    else:
        return Response(serializer.errors, status=400)

@api_view(["POST"])
@permission_classes([IsAuthenticated])
def exercise_step(request):
    user = request.user
    session = QuestionnaireSession.objects.filter(user=user, completed=False).last()

    if not session:
        print("No active questionnaire session found.")
        return Response({"error": "No active questionnaire session found."}, status=404)

    # if session.current_step != 4:
    #     print(f"User is on step {session.current_step}, expected step 4.")
    #     return Response({"error": "You are not on the exercise step."}, status=400)

    data = request.data.copy()
    print("Received data:", data)  # Debug: Log the received data

    data["session"] = session.id

    # Check if the required fields are missing
    if "activity_level_comparison" not in data:
        print("Error: Missing activity_level_comparison in the request.")
    if "exercise_type" not in data:
        print("Error: Missing exercise_type in the request.")
    if "exercise_intensity" not in data:
        print("Error: Missing exercise_intensity in the request.")

    # Safely handle missing keys using .get()
    if data.get("activity_level_comparison") == "Less" and not data.get("activity_prevention_reason"):
        print("Missing activity prevention reason for 'Less' activity level.")
        return Response({"error": "Reason for less activity is required if activity level is 'Less'."}, status=400)

    serializer = ExerciseCheckSerializer(data=data)
    if not serializer.is_valid():
        print("Serializer errors:", serializer.errors)  # Debug: Log serializer validation errors
        return Response(serializer.errors, status=400)

    exercise_check = serializer.save()
    session.save()

    return Response(
        {
            "message": "Exercise information logged successfully.",
            "exercise_check": ExerciseCheckSerializer(exercise_check).data,
        },
        status=201,
    )

@api_view(["GET"])
@permission_classes([IsAuthenticated])
def review_answers(request):
    """
    Fetches all answers for the current active questionnaire session for review.
    """
    user = request.user
    session = QuestionnaireSession.objects.filter(user=user, completed=False).last()

    if not session:
        return Response({"error": "No active questionnaire session found."}, status=404)

    data = {
        "symptom_check": SymptomCheckSerializer(session.symptom_check.all(), many=True).data,
        "glucose_check": GlucoseCheckSerializer(session.glucose_check.all(), many=True).data,
        "meal_check": MealCheckSerializer(session.meal_check.all(), many=True).data,
        "exercise_check": ExerciseCheckSerializer(session.exercise_check.all(), many=True).data,
    }

    session.completed = True
    session.save()

    return Response(data)

@api_view(["GET"])
@permission_classes([IsAuthenticated])
def questionnaire_data_visualization(request):
    user = request.user

    # Aggregate data by session
    sessions = QuestionnaireSession.objects.filter(user=user, completed=True)
    latest_session_date = sessions.aggregate(Max("created_at"))["created_at__max"]

    data = []
    for session in sessions:
        session_data = {
            "date": session.created_at.strftime("%Y-%m-%d"),
            "is_latest": session.created_at
            == latest_session_date,  # Flag for latest session
            "glucose_check": [
                {
                    "level": glucose.glucose_level,
                    "target_evaluation": glucose.evaluate_target(),
                }
                for glucose in session.glucose_check.all()
            ],
            "wellness_score": (
                session.feeling_check.feeling if session.feeling_check else None
            ),
            "symptom_check": [
                symptom.symptoms for symptom in session.symptom_check.all()
            ],
            "meal_check": [
                {
                    "high_gi_food_count": meal.high_gi_foods.count(),
                    "skipped_meals": meal.skipped_meals,
                    "weighted_gi": meal.weighted_gi,
                }
                for meal in session.meal_check.all()
            ],
            "exercise_check": {
                "duration": session.exercise_check.aggregate(Avg("exercise_duration"))[
                    "exercise_duration__avg"
                ],
                "feeling": (
                    session.exercise_check.first().post_exercise_feeling
                    if session.exercise_check.exists()
                    else None
                ),
            },
        }
        data.append(session_data)

    return Response(data)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def insights_graph_data(request):
    """
    Provides data for the insights graph: Glucose Levels vs. Wellness Level.
    """
    user = request.user

    target_min = request.GET.get("target_min")
    target_max = request.GET.get("target_max")

    # Fetch glucose logs and wellness logs
    glucose_logs = GlucoseLog.objects.filter(user=user).order_by("timestamp")
    wellness_logs = FeelingCheck.objects.filter(user=user).order_by("created_at")

    # Transform glucose data
    glucose_points = [
        {"date": log.timestamp.strftime("%Y-%m-%d"), "value": log.glucose_level}
        for log in glucose_logs
    ]

    # Identify high/low glucose events
    high_glucose_events = [
        {"date": log.timestamp.strftime("%Y-%m-%d"), "value": log.glucose_level}
        for log in glucose_logs
        if log.glucose_level > target_max
    ]
    low_glucose_events = [
        {"date": log.timestamp.strftime("%Y-%m-%d"), "value": log.glucose_level}
        for log in glucose_logs
        if log.glucose_level < target_min
    ]

    # Transform wellness data
    wellness_points = [
        {"date": log.created_at.strftime("%Y-%m-%d"), "value": log.feeling_rating}
        for log in wellness_logs
    ]

    return Response(
        {
            "glucose_points": glucose_points,
            "wellness_points": wellness_points,
            "high_glucose_events": high_glucose_events,
            "low_glucose_events": low_glucose_events,
            "target_min": target_min,
            "target_max": target_max,
        },
        status=status.HTTP_200_OK,
    )
