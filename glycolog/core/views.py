from datetime import datetime, timedelta, timezone
from django.utils import timezone
from django.http import JsonResponse
import pandas as pd
from django.db.models import Max
from rest_framework import status
from rest_framework.response import Response
from django.contrib.auth import authenticate
from rest_framework_simplejwt.tokens import RefreshToken, AccessToken

from core.ai_model import feature_engineering
from core.ai_model.data_processing import load_data_from_db
from core.ai_model.recommendation_engine import generate_recommendations, load_models, predict_glucose, predict_wellness_risk
from core.services.google_fit_service import get_smartwatch_data
from .serializers import ChatMessageSerializer, ExerciseCheckSerializer, ExerciseRecommendationSerializer, FoodCategorySerializer, FoodItemSerializer, GlucoseCheckSerializer, GlucoseLogSerializer, MealCheckSerializer, MealSerializer, QuestionnaireSessionSerializer, RegisterSerializer, LoginSerializer, SettingsSerializer, SymptomCheckSerializer
from .models import ChatMessage, CustomUser, CustomUserToken, ExerciseCheck, ExerciseRecommendation, FeelingCheck, FoodCategory, FoodItem, GlucoseCheck, GlucoseLog, GlycaemicResponseTracker, Meal, MealCheck, QuestionnaireSession, SymptomCheck  
from django.contrib.auth import get_user_model
from rest_framework.permissions import IsAuthenticated
from rest_framework.permissions import AllowAny
from rest_framework.decorators import api_view, permission_classes
from django.shortcuts import get_object_or_404, redirect, render
from django.db.models import Q
from django.db.models import Avg
import joblib
import openai
import os
from google_auth_oauthlib.flow import Flow


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

            print(f"Login successful for user: {username}")
            return Response({
                "access": str(access),  # Include the access token in the response
                "refresh": str(refresh),  # Refresh token
                "first_name": user.first_name,  # Include the first name in the response
                "username": user.username
            }, status=status.HTTP_200_OK)
        else:
            print(f"Login failed for user: {username}")
            return Response({"error": "Username or password is incorrect."}, status=status.HTTP_401_UNAUTHORIZED)
    else:
        print("Serializer validation failed:", serializer.errors)
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
    range_param = request.query_params.get("range", "last_10")  # Default to "last_10"

    # Filter sessions based on the range
    if range_param == "last_7":
        sessions = QuestionnaireSession.objects.filter(
            user=user, completed=True
        ).order_by("-created_at")[:7]
    elif range_param == "last_10":
        sessions = QuestionnaireSession.objects.filter(
            user=user, completed=True
        ).order_by("-created_at")[:10]
    elif range_param == "last_30_days":
        date_threshold = timezone.now() - timedelta(days=30)  
        sessions = QuestionnaireSession.objects.filter(
            user=user, completed=True, created_at__gte=date_threshold
        ).order_by("-created_at")
    elif range_param == "all":
        sessions = QuestionnaireSession.objects.filter(
            user=user, completed=True
        ).order_by("-created_at")
    else:
        return Response(
            {"error": "Invalid range parameter provided."}, status=400
        )

    # Get the latest session date for "is_latest" flag
    latest_session_date = sessions.aggregate(Max("created_at"))["created_at__max"]

    # Prepare session data
    data = [
        {
            "session_id": session.id,
            "date": session.created_at.strftime("%Y-%m-%d %H:%M:%S"),
            "is_latest": session.created_at == latest_session_date,
            "feeling_check": session.feeling_check.feeling if session.feeling_check else None,
            "glucose_check": GlucoseCheckSerializer(session.glucose_check.all(), many=True).data,
            "meal_check": MealCheckSerializer(session.meal_check.all(), many=True).data,
            "exercise_check": ExerciseCheckSerializer(session.exercise_check.all(), many=True).data,
            "symptom_check": SymptomCheckSerializer(session.symptom_check.all(), many=True).data,
        }
        for session in sessions
    ]

    return Response(data, status=200)

@api_view(["GET"])
@permission_classes([IsAuthenticated])
def get_insights(request):
    user = request.user

    # Fetch the user's completed questionnaire sessions
    user_sessions = QuestionnaireSession.objects.filter(user=user, completed=True).order_by("-created_at")

    if not user_sessions.exists():
        return Response({"error": "No completed sessions found for this user."}, status=404)

    # Analyze user-specific data
    personal_insights = {
        "high_glucose": user_sessions.filter(glucose_check__glucose_level__gt=("glucose_check__target_max")).count(),
        "low_sleep": user_sessions.filter(symptom_check__sleep_hours__lt=6).count(),
        "exercise_impact": user_sessions.filter(exercise_check__post_exercise_feeling="Energised").count(),
        "skipped_meals": user_sessions.filter(meal_check__skipped_meals__len__gt=0).count(),
    }

    # General trends (aggregated data for all users)
    all_sessions = QuestionnaireSession.objects.filter(completed=True)
    general_trends = {
        "avg_glucose": all_sessions.aggregate(avg_glucose=Avg("glucose_check__glucose_level")),
        "avg_sleep": all_sessions.aggregate(avg_sleep=Avg("symptom_check__sleep_hours")),
        "exercise_effect": all_sessions.filter(exercise_check__post_exercise_feeling="Energised").count(),
        "skipped_meals_effect": all_sessions.filter(meal_check__wellness_impact=True).count(),
    }

    return Response({
        "personal_insights": personal_insights,
        "general_trends": general_trends,
    }, status=200)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def get_ai_insights(request):
    """
    Fetch AI-generated insights and recommendations based on all logged data.
    """
    user = request.user

    # Fetch all relevant data
    symptom_data = SymptomCheck.objects.filter(session__user=user)
    exercise_data = ExerciseCheck.objects.filter(session__user=user)
    glucose_data = GlucoseCheck.objects.filter(session__user=user)
    meal_data = MealCheck.objects.filter(session__user=user)
    glucose_logs = GlucoseLog.objects.filter(user=user)

    if not (
        symptom_data.exists()
        or exercise_data.exists()
        or glucose_data.exists()
        or meal_data.exists()
        or glucose_logs.exists()
    ):
        return Response(
            {"error": "No relevant data found for AI insights."}, status=404
        )

    # Load all data for AI processing
    data = load_data_from_db(
        questionnaire_queryset=QuestionnaireSession.objects.filter(
            user=user, completed=True
        ),
        symptom_queryset=symptom_data,
        glucose_check_queryset=glucose_data,
        meal_check_queryset=meal_data,
        exercise_queryset=exercise_data,
        glucose_log_queryset=glucose_logs,
        glycaemic_response_queryset=GlycaemicResponseTracker.objects.filter(user=user),
        meal_queryset=Meal.objects.filter(user=user),
        feeling_queryset=FeelingCheck.objects.filter(user=user),
    )

    if data.empty:
        return Response({"error": "No sufficient data available."}, status=400)

    # Apply feature engineering before predictions
    data = feature_engineering(data)

    # Load AI models
    wellness_model, glucose_model = load_models()

    # Make predictions
    wellness_predictions = predict_wellness_risk(wellness_model, data)
    glucose_predictions = predict_glucose(glucose_model, data)

    # Generate AI-based recommendations
    recommendations = generate_recommendations(data)

    response_data = {
        "wellness_predictions": wellness_predictions.tolist(),
        "glucose_predictions": glucose_predictions.tolist(),
        "recommendations": recommendations,
    }

    return Response(response_data, status=200)


# Load OpenAI API Key
openai.api_key = os.getenv("OPENAI_API_KEY")

def convert_glucose_units(glucose_value, preferred_unit="mg/dL"):
    """Convert glucose levels based on user preference (mg/dL or mmol/L)."""
    if preferred_unit == "mmol/L":
        return round(glucose_value / 18, 2)  # Convert mg/dL to mmol/L
    return glucose_value  # Keep mg/dL as is

@api_view(["GET"])
@permission_classes([IsAuthenticated])
def virtual_health_coach(request):
    user = request.user

    # Fetch user’s glucose unit preference from settings
    user_settings = user.settings.first()
    preferred_unit = user_settings.glucose_unit if user_settings else "mg/dL"

    # Fetch the most recent exercise and glucose data
    latest_exercise = ExerciseCheck.objects.filter(user=user).order_by("-created_at").first()
    latest_glucose_log = GlucoseLog.objects.filter(user=user).order_by("-timestamp").first()
    latest_glucose_check = GlucoseCheck.objects.filter(user=user).order_by("-timestamp").first()

    # Determine the most recent glucose reading
    latest_glucose = max(
        filter(None, [latest_glucose_log, latest_glucose_check]),
        key=lambda x: x.timestamp,
        default=None
    )

    # Count total exercise sessions
    total_exercise_sessions = ExerciseCheck.objects.filter(user=user).count()

    # Calculate average glucose level from both sources
    avg_glucose_log = GlucoseLog.objects.filter(user=user).aggregate(Avg('glucose_level'))['glucose_level__avg']
    avg_glucose_check = GlucoseCheck.objects.filter(user=user).aggregate(Avg('glucose_level'))['glucose_level__avg']

    # Determine the overall average glucose level
    if avg_glucose_log and avg_glucose_check:
        avg_glucose_level = (avg_glucose_log + avg_glucose_check) / 2
    else:
        avg_glucose_level = avg_glucose_log or avg_glucose_check or None

    # Fetch smartwatch data
    smartwatch_data = get_smartwatch_data(user)

    # Format summaries for OpenAI prompt
    exercise_summary = (
        f"- {latest_exercise.exercise_type} for {latest_exercise.exercise_duration} mins at {latest_exercise.exercise_intensity} intensity."
        if latest_exercise else "No recent exercise logs."
    )

    glucose_summary = (
        f"{latest_glucose.timestamp}: {convert_glucose_units(latest_glucose.glucose_level, preferred_unit)} {preferred_unit}"
        if latest_glucose else "No recent glucose logs."
    )

    smartwatch_summary = smartwatch_data if smartwatch_data else "No smartwatch data available."

    # OpenAI Prompt
    prompt = f"""
    The user has diabetes and their health data is as follows:
    
    - **Most Recent Glucose Reading (before exercise):** {glucose_summary}
    - **Most Recent Exercise Session (after glucose reading):** {exercise_summary}
    - **Smartwatch/Phone Fitness Data (recent activity trends):** {smartwatch_summary}

    **Historical Data Summary:**
    - Total Exercise Sessions: {total_exercise_sessions}
    - Average Glucose Level: {avg_glucose_level if avg_glucose_level else 'N/A'} {preferred_unit}

    **Your task:**
    1. Provide personalized exercise recommendations that align with glucose levels and exercise history.
    2. Use smartwatch data to adjust plans, ensuring they meet the user's fitness goals.
    3. Suggest ways to stabilize glucose through exercise.
    4. Ensure all recommendations are diabetes-friendly and promote overall wellness.

    Present recommendations in bullet-point format.
    """

    # Sending prompt to OpenAI API
    response = openai.ChatCompletion.create(
        model="gpt-4",
        messages=[
            {"role": "system", "content": "You are a certified fitness coach specializing in diabetic health management."},
            {"role": "user", "content": prompt},
        ],
    )

    ai_response = response["choices"][0]["message"]["content"]

    # Save AI-generated recommendation
    recommendation = ExerciseRecommendation.objects.create(
        user=user,
        glucose_level=latest_glucose.glucose_level if latest_glucose else None,
        glucose_unit=preferred_unit,
        exercise_type=latest_exercise.exercise_type if latest_exercise else None,
        exercise_duration=latest_exercise.exercise_duration if latest_exercise else None,
        exercise_intensity=latest_exercise.exercise_intensity if latest_exercise else None,
        recommendation_text=ai_response
    )

    serialized_recommendation = ExerciseRecommendationSerializer(recommendation)
    return JsonResponse(serialized_recommendation.data)

@api_view(["GET"])
@permission_classes([IsAuthenticated])
def get_past_recommendations(request):
    """Retrieve past AI-generated exercise recommendations."""
    user = request.user
    recommendations = ExerciseRecommendation.objects.filter(user=user).order_by("-timestamp")[:10]

    data = ExerciseRecommendationSerializer(recommendations, many=True).data
    
    return JsonResponse({"past_recommendations": data})

@api_view(["GET"])
@permission_classes([IsAuthenticated])
def authorize_google_fit(request):
    """Redirect user to Google Fit OAuth for authorization."""
    flow = Flow.from_client_secrets_file(
        'path/to/client_secret.json',  # Replace with your client secret file path
        scopes=['https://www.googleapis.com/auth/fitness.activity.read'],
        redirect_uri='http://localhost:8000/api/google_fit/callback/'  # Match with Google Console redirect URI
    )
    authorization_url, state = flow.authorization_url(access_type='offline', include_granted_scopes='true')
    request.session['oauth_state'] = state  # Save state to session for security
    return redirect(authorization_url)

@api_view(["GET"])
@permission_classes([IsAuthenticated])
def google_fit_callback(request):
    """Handle the callback from Google Fit OAuth."""
    state = request.session.get('oauth_state')
    flow = Flow.from_client_secrets_file(
        'path/to/client_secret.json',
        scopes=['https://www.googleapis.com/auth/fitness.activity.read'],
        redirect_uri='http://localhost:8000/api/google_fit/callback/'
    )
    flow.fetch_token(authorization_response=request.build_absolute_uri())

    credentials = flow.credentials
    user = request.user

    # Save credentials to the database
    CustomUserToken.objects.update_or_create(
        user=user,
        defaults={
            'token': credentials.token,
            'refresh_token': credentials.refresh_token,
            'token_uri': credentials.token_uri,
            'client_id': credentials.client_id,
            'client_secret': credentials.client_secret,
            'scopes': credentials.scopes
        }
    )

    return JsonResponse({"message": "Google Fit connected successfully!"})

@api_view(["POST"])
@permission_classes([IsAuthenticated])
def chat_with_health_coach(request):
    user = request.user
    user_message = request.data.get("message")

    # Save user message in chat history
    ChatMessage.objects.create(user=user, sender="user", message=user_message)

    # Fetch recent health data
    latest_exercise = ExerciseCheck.objects.filter(user=user).order_by("-created_at").first()
    latest_glucose_log = GlucoseLog.objects.filter(user=user).order_by("-timestamp").first()
    smartwatch_data = get_smartwatch_data(user)

    # Build system context for OpenAI
    health_context = f"""
    The user has diabetes. Here's their recent health data:
    
    - Last Exercise: {latest_exercise.exercise_type if latest_exercise else 'N/A'} for {latest_exercise.exercise_duration if latest_exercise else 'N/A'} mins
    - Last Glucose Level: {latest_glucose_log.glucose_level if latest_glucose_log else 'N/A'} mg/dL
    - Smartwatch Data: {smartwatch_data if smartwatch_data else 'No data available'}
    """

    # Fetch past chat history
    past_messages = ChatMessage.objects.filter(user=user).order_by("timestamp")
    conversation_history = [
        {"role": "user" if msg.sender == "user" else "assistant", "content": msg.message}
        for msg in past_messages
    ]

    # Append latest user message
    conversation_history.append({"role": "user", "content": user_message})

    # Send prompt to OpenAI API
    response = openai.ChatCompletion.create(
        model="gpt-4",
        messages=[
            {"role": "system", "content": f"You are a fitness coach specialized in diabetic health. {health_context}"},
            *conversation_history,
        ],
    )

    ai_response = response["choices"][0]["message"]["content"]

    # Save AI response in chat history
    ChatMessage.objects.create(user=user, sender="assistant", message=ai_response)

    return JsonResponse({"response": ai_response})


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def get_chat_history(request):
    user = request.user
    chat_history = ChatMessage.objects.filter(user=user).order_by("timestamp")
    serialized_history = ChatMessageSerializer(chat_history, many=True)
    return JsonResponse({"chat_history": serialized_history.data})
