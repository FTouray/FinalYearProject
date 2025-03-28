from datetime import datetime, time, timedelta, timezone
from django.utils.timezone import now, timedelta
import json
from django.utils import timezone
from django.http import JsonResponse
from django.utils.dateparse import parse_time, parse_datetime
from django_q.tasks import async_task
import pandas as pd
from django.db.models import Max
import requests
from rest_framework import status
from rest_framework.response import Response
from django.contrib.auth import authenticate
from rest_framework_simplejwt.tokens import RefreshToken, AccessToken
from django.conf import settings
from core.ai_services import generate_ai_recommendation, generate_health_trends
from core.ai_model import feature_engineering
from core.ai_model.data_processing import load_data_from_db
from core.ai_model.recommendation_engine import generate_recommendations, load_models, predict_glucose, predict_wellness_risk
from core.services.ocr_service import extract_text_from_image
from core.services.rxnorm_service import fetch_medication_details
from core.services.reminder_service import schedule_medication_reminder
from .serializers import ChatMessageSerializer, ExerciseCheckSerializer, FoodCategorySerializer, FoodItemSerializer, GlucoseCheckSerializer, GlucoseLogSerializer, MealCheckSerializer, MealSerializer, MedicationReminderSerializer, MedicationSerializer, QuestionnaireSessionSerializer, RegisterSerializer, LoginSerializer, SettingsSerializer, SymptomCheckSerializer
from .models import AIHealthTrend, AIRecommendation, ChatMessage, CustomUser, ExerciseCheck, FeelingCheck, FitnessActivity, FoodCategory, FoodItem, GlucoseCheck, GlucoseLog, GlycaemicResponseTracker, LocalNotificationPrompt, Meal, MealCheck, Medication, MedicationReminder, QuestionnaireSession, SymptomCheck  
from django.contrib.auth import get_user_model
from rest_framework.permissions import IsAuthenticated
from rest_framework.permissions import AllowAny
from rest_framework.decorators import api_view, permission_classes
from django.shortcuts import get_object_or_404, redirect, render
from django.views.decorators.csrf import csrf_exempt
from django.db.models import Q
from django.db.models import Avg
import joblib
import openai
import os
from google_auth_oauthlib.flow import Flow
import logging
from googleapiclient.discovery import build
from rest_framework.generics import ListAPIView
from openai import OpenAI

User = get_user_model()
logger = logging.getLogger(__name__)
client = OpenAI()
# Load OpenAI API Key
openai.api_key = os.getenv("OPENAI_API_KEY")


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
        user = serializer.save()

        return Response({
            "message": "User registered successfully"}, status=status.HTTP_201_CREATED)
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
                "username": user.username,
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

def convert_glucose_units(glucose_value, preferred_unit="mg/dL"):
    """Convert glucose levels based on user preference (mg/dL or mmol/L)."""
    if preferred_unit == "mmol/L":
        return round(glucose_value / 18, 2)  # Convert mg/dL to mmol/L
    return glucose_value  # Keep mg/dL as is

@api_view(["GET"])
@permission_classes([IsAuthenticated])
def get_dashboard_summary(request):
    user = request.user
    today = now()
    start_date = today - timedelta(days=7)

    activities = FitnessActivity.objects.filter(
        user=user, start_time__date__range=[start_date.date(), today.date()]
    ).order_by("start_time")

    trend_summary = {}
    for activity in activities:
        date_str = activity.start_time.strftime("%Y-%m-%d")
        trend = trend_summary.setdefault(date_str, {
            "steps": 0, "heart_rate": [], "sleep_hours": 0.0, "calories": 0.0, "distance": 0.0
        })
        trend["steps"] += activity.steps or 0
        trend["calories"] += activity.calories_burned or 0.0
        trend["distance"] += activity.distance_meters or 0.0
        if activity.heart_rate:
            trend["heart_rate"].append(activity.heart_rate)
        if activity.total_sleep_hours:
            trend["sleep_hours"] += activity.total_sleep_hours

    for day in trend_summary:
        hr_list = trend_summary[day]["heart_rate"]
        trend_summary[day]["heart_rate"] = sum(hr_list) / len(hr_list) if hr_list else None

    latest_log = GlucoseLog.objects.filter(user=user).order_by("-timestamp").first()
    latest_check = GlucoseCheck.objects.filter(session__user=user).order_by("-timestamp").first()

    if latest_log and (not latest_check or latest_log.timestamp > latest_check.timestamp):
        latest_glucose_value = latest_log.glucose_level
        latest_glucose_time = latest_log.timestamp
    elif latest_check:
        latest_glucose_value = latest_check.glucose_level
        latest_glucose_time = latest_check.timestamp
    else:
        latest_glucose_value = None
        latest_glucose_time = None

    avg_log = GlucoseLog.objects.filter(user=user).aggregate(Avg("glucose_level"))["glucose_level__avg"] or 0
    avg_check = GlucoseCheck.objects.filter(session__user=user).aggregate(Avg("glucose_level"))["glucose_level__avg"] or 0

    avg_glucose_level = round((avg_log + avg_check) / 2, 2) if (avg_log or avg_check) else None

    recent_activities = FitnessActivity.objects.filter(user=user).order_by("-start_time")[:5]
    ai_response = generate_ai_recommendation(user, recent_activities)
    ai_recommendation = AIRecommendation.objects.create(
        user=user, recommendation_text=ai_response
    )
    ai_recommendation.fitness_activities.set(recent_activities)

    latest_fitness = FitnessActivity.objects.filter(user=user).order_by("-start_time").first()
    total_exercise_sessions = FitnessActivity.objects.filter(user=user, activity_type="Exercise").count()

    return JsonResponse({
        "recommendation": ai_response,
        "glucose_summary": (
            f"{latest_glucose_time.strftime('%Y-%m-%d %H:%M')}: {latest_glucose_value} mg/dL"
            if latest_glucose_value else "No recent glucose data."
        ),
        "average_glucose_level": avg_glucose_level or "N/A",
        "total_exercise_sessions": total_exercise_sessions,
        "latest_fitness_data": {
            "activity_type": latest_fitness.activity_type if latest_fitness else None,
            "steps": latest_fitness.steps if latest_fitness else None,
            "heart_rate": latest_fitness.heart_rate if latest_fitness else None,
            "sleep_hours": latest_fitness.total_sleep_hours if latest_fitness else None,
            "distance_meters": latest_fitness.distance_meters if latest_fitness else None,
            "calories_burned": latest_fitness.calories_burned if latest_fitness else None,
            "start_time": latest_fitness.start_time.isoformat() if latest_fitness else None,
            "end_time": latest_fitness.end_time.isoformat() if latest_fitness else None,
        },
        "trend_data": trend_summary
    })


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def list_ai_recommendations(request):
    user = request.user
    recommendations = AIRecommendation.objects.filter(user=user).order_by("-generated_at")[:10]

    data = [
        {
            "generated_at": rec.generated_at.strftime("%Y-%m-%d %H:%M:%S"),
            "recommendation": rec.recommendation_text,
            "related_activities": [
                f"{activity.activity_type} ({activity.start_time.strftime('%Y-%m-%d %H:%M')})"
                for activity in rec.fitness_activities.all()
            ],
        }
        for rec in recommendations
    ]
    return JsonResponse({"past_recommendations": data})


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def get_ai_health_trends(request, period_type="weekly"):
    user = request.user
    latest_trend = AIHealthTrend.objects.filter(user=user, period_type=period_type).order_by("-start_date").first()

    if not latest_trend:
        generate_health_trends(user, period_type)
        latest_trend = AIHealthTrend.objects.filter(user=user, period_type=period_type).order_by("-start_date").first()

    if not latest_trend:
        return JsonResponse({"message": f"No {period_type} trends available."}, status=404)

    data = {
        "start_date": latest_trend.start_date.strftime("%Y-%m-%d"),
        "end_date": latest_trend.end_date.strftime("%Y-%m-%d"),
        "avg_glucose_level": latest_trend.avg_glucose_level,
        "avg_steps": latest_trend.avg_steps,
        "avg_sleep_hours": latest_trend.avg_sleep_hours,
        "avg_heart_rate": latest_trend.avg_heart_rate,
        "total_exercise_sessions": latest_trend.total_exercise_sessions,
        "ai_summary": latest_trend.ai_summary,
    }
    return JsonResponse({"trend": data})


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def latest_fitness_entry(request):
    user = request.user
    latest = FitnessActivity.objects.filter(user=user).order_by('-start_time').first()

    if not latest:
        return JsonResponse({"message": "No fitness data found."}, status=404)

    data = {
        "activity_type": latest.activity_type,
        "steps": latest.steps,
        "heart_rate": latest.heart_rate,
        "calories_burned": latest.calories_burned,
        "distance_meters": latest.distance_meters,
        "sleep_hours": latest.total_sleep_hours,
        "start_time": latest.start_time,
        "end_time": latest.end_time,
    }
    return JsonResponse(data)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def today_fitness_summary(request):
    user = request.user
    today = now().date()

    data = FitnessActivity.objects.filter(user=user, start_time__date=today).first()

    if not data:
        # Try fallback to yesterday
        yesterday = today - timedelta(days=1)
        data = FitnessActivity.objects.filter(user=user, start_time__date=yesterday).first()
        if not data:
            return Response({"message": "No data for today."}, status=404)

    return Response({
        "activity_type": data.activity_type,
        "steps": data.steps,
        "sleep_hours": data.total_sleep_hours,
        "heart_rate": data.heart_rate,
        "calories_burned": data.calories_burned,
        "distance_meters": data.distance_meters,
        "start_time": data.start_time,
        "end_time": data.end_time
    })


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def log_health_entry(request):
    user = request.user
    data = request.data

    try:
        start_time = parse_datetime(data.get("start_time"))
        end_time = parse_datetime(data.get("end_time"))
        activity_type = data.get("activity_type")

        existing = FitnessActivity.objects.filter(
            user=user,
            activity_type=activity_type,
            start_time=start_time,
            end_time=end_time
        ).first()

        if existing and not existing.is_manual_override:
            return Response({"message": "Record already exists."}, status=200)

        FitnessActivity.objects.update_or_create(
            user=user,
            activity_type=activity_type,
            start_time=start_time,
            end_time=end_time,
            defaults={
                "duration_minutes": data.get("duration_minutes"),
                "steps": data.get("steps"),
                "heart_rate": data.get("heart_rate"),
                "total_sleep_hours": data.get("sleep_hours"),
                "calories_burned": data.get("calories_burned"),
                "distance_meters": data.get("distance_meters"),
                "source": "Phone",
                "last_activity_time": end_time,
                "is_manual_override": False,
            }
        )

        return Response({"message": "Health data stored successfully."}, status=201)

    except Exception as e:
        return Response({"error": f"Failed to store health data: {str(e)}"}, status=400)

client = OpenAI()

@api_view(["POST"])
@permission_classes([IsAuthenticated])
def chat_with_virtual_coach(request):
    user = request.user
    user_message = request.data.get("message")

    if not user_message:
        return JsonResponse({"error": "Message cannot be empty"}, status=400)

    ChatMessage.objects.create(user=user, sender="user", message=user_message)
    
    # recent_data = FitnessActivity.objects.filter(
    # user=user,
    # start_time__gte=now() - timedelta(days=3)
    # )

    # if not recent_data.exists():
    #     fallback = (
    #         "I wasn’t able to find any recent health data to analyze. "
    #         "But I can still offer general wellness tips or answer your questions!"
    #     )

    #     ChatMessage.objects.create(user=user, sender="assistant", message=fallback)
    #     return JsonResponse({"response": fallback}, status=200)

    past_recommendations = AIRecommendation.objects.filter(user=user).order_by("-generated_at")[:5]
    recommendations_summary = "\n".join(
        [f"{rec.recommendation_text} (given on {rec.generated_at.strftime('%Y-%m-%d')})" for rec in past_recommendations]
    ) if past_recommendations else "No past recommendations available."

    past_messages = ChatMessage.objects.filter(user=user).order_by("-timestamp")[:50]
    conversation_history = [
        {"role": msg.sender, "content": msg.message} for msg in past_messages
    ]

    user_settings = getattr(user, "settings", None)
    preferred_unit = user_settings.glucose_unit if user_settings else "mg/dL"

    latest_glucose_log = GlucoseLog.objects.filter(user=user).order_by("-timestamp").first()

    if latest_glucose_log:
        glucose_value = latest_glucose_log.glucose_level
        if preferred_unit == "mmol/L":
            glucose_value = round(glucose_value / 18, 2)
        glucose_summary = f"Latest glucose reading: {glucose_value} {preferred_unit}"
    else:
        glucose_summary = "No recent glucose readings available."

    system_message = (
        "You are a virtual fitness coach providing expert diabetic health recommendations. "
        "You analyze glucose levels, fitness data, and past recommendations to provide guidance."
    )

    conversation_history.append({"role": "system", "content": system_message})
    conversation_history.append({"role": "system", "content": f"Previously given recommendations:\n{recommendations_summary}"})
    conversation_history.append({"role": "system", "content": glucose_summary})
    conversation_history.append({"role": "user", "content": user_message})

    response = client.chat.completions.create(
        model="gpt-4",
        messages=conversation_history,
    )
    ai_response = response.choices[0].message.content

    ChatMessage.objects.create(user=user, sender="assistant", message=ai_response)

    return JsonResponse({"response": ai_response})


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def chat_history(request):
    user = request.user
    page = int(request.GET.get("page", 1))
    per_page = 20

    chat_history = ChatMessage.objects.filter(user=user).order_by("-timestamp")[(page - 1) * per_page: page * per_page]

    data = [
        {
            "timestamp": msg.timestamp.strftime("%Y-%m-%d %H:%M:%S"),
            "sender": msg.sender,
            "message": msg.message,
        }
        for msg in chat_history
    ]
    return JsonResponse({"chat_history": data, "page": page, "per_page": per_page})

@api_view(["GET"])
@permission_classes([IsAuthenticated])
def get_local_notifications(request):
    """Return pending local notifications for the user."""
    user = request.user
    notifications = LocalNotificationPrompt.objects.filter(user=user, is_sent=False)

    data = [
        {"id": notif.id, "message": notif.message}
        for notif in notifications
    ]

    # Mark notifications as sent so they are not resent
    notifications.update(is_sent=True)

    return JsonResponse({"notifications": data})

@api_view(["POST"])
@permission_classes([IsAuthenticated])
def queue_local_notification(request):
    """Queue a local notification to be shown in the app."""
    user_id = request.data.get("user_id")
    message = request.data.get("message")

    if not user_id or not message:
        return JsonResponse({"error": "User ID and message are required."}, status=400)

    user = get_object_or_404(CustomUser, id=user_id)

    LocalNotificationPrompt.objects.create(user=user, message=message)

    return JsonResponse({"message": "Local notification queued successfully."})

    
RXNORM_API_URL = "https://rxnav.nlm.nih.gov/REST/drugs.json?name={}"

@api_view(["GET"])
@permission_classes([IsAuthenticated])
def fetch_medications_from_rxnorm(request):
    """Fetches medication list from RxNorm API"""
    search_query = request.GET.get("query", "")

    if not search_query:
        return JsonResponse({"error": "Search query required"}, status=400)

    response = requests.get(RXNORM_API_URL.format(search_query))

    if response.status_code == 200:
        data = response.json()
        medications = []

        if "drugGroup" in data and "conceptGroup" in data["drugGroup"]:
            for group in data["drugGroup"]["conceptGroup"]:
                if "conceptProperties" in group:
                    for med in group["conceptProperties"]:
                        medications.append({
                            "name": med["name"],
                            "rxnorm_id": med["rxcui"]
                        })

        return JsonResponse({"medications": medications})

    return JsonResponse({"error": "Failed to fetch medications"}, status=500)

@api_view(["POST"])
@permission_classes([IsAuthenticated])
def set_reminder(request):
    """Set a medication reminder for the user."""
    user = request.user
    medication_name = request.data.get("medication_name")
    reminder_time = request.data.get("time")

    if not medication_name or not reminder_time:
        return JsonResponse({"error": "Medication name and time are required."}, status=400)

    reminder, created = MedicationReminder.objects.get_or_create(
        user=user,
        medication_name=medication_name,
        reminder_time=reminder_time
    )

    if created:
        async_task("core.tasks.send_medication_reminder", user.id, medication_name, schedule_type="D", repeats=-1)

    return JsonResponse({"message": "Reminder set successfully!"})

@api_view(["GET"])
@permission_classes([IsAuthenticated])
def get_medication_reminders(request):
    """Retrieve all medication reminders for the user"""
    reminders = MedicationReminder.objects.filter(user=request.user)
    serializer = MedicationReminderSerializer(reminders, many=True)
    return JsonResponse({"reminders": serializer.data})


@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated])
def MedicationReminderListView(request):
    if request.method == 'GET':
        reminders = MedicationReminder.objects.filter(user=request.user)
        serializer = MedicationReminderSerializer(reminders, many=True)
        return Response(serializer.data)

    if request.method == 'POST':
        data = request.data
        medication = Medication.objects.get(user=request.user, name=data['medication_name'])
        reminder_time = parse_time(data['time'])
        
        reminder, created = MedicationReminder.objects.get_or_create(
            user=request.user, medication=medication, reminder_time=reminder_time
        )
        if created:
            return Response({'message': 'Reminder set successfully!'}, status=201)
        return Response({'message': 'Reminder already exists.'}, status=200)

@api_view(["POST"])
@permission_classes([IsAuthenticated])
def save_medication(request):
    """Save selected medication from RxNorm API or manually entered"""
    user = request.user
    name = request.data.get("name")
    rxnorm_id = request.data.get("rxnorm_id", None)  
    dosage = request.data.get("dosage", "")
    frequency = request.data.get("frequency", "")
    last_taken = request.data.get("last_taken", None)

    if not name:
        return Response({"error": "Medication name is required."}, status=status.HTTP_400_BAD_REQUEST)

    medication, created = Medication.objects.get_or_create(
        user=user,
        name=name,
        defaults={"rxnorm_id": rxnorm_id, "dosage": dosage, "frequency": frequency, "last_taken": last_taken}
    )

    serializer = MedicationSerializer(medication)
    if created:
        return Response({"message": "Medication saved successfully."}, status=status.HTTP_201_CREATED)
    return Response({"message": "Medication already exists."}, status=status.HTTP_200_OK)

@api_view(["GET"])
@permission_classes([IsAuthenticated])
def get_saved_medications(request):
    """Retrieve all medications saved by the user"""
    medications = Medication.objects.filter(user=request.user).order_by("-id")
    serializer = MedicationSerializer(medications, many=True)
    return JsonResponse({"medications": serializer.data})

@api_view(["PUT"])
@permission_classes([IsAuthenticated])
def update_medication(request, medication_id):
    """Edit a saved medication"""
    try:
        medication = Medication.objects.get(id=medication_id, user=request.user)
    except Medication.DoesNotExist:
        return JsonResponse({"error": "Medication not found"}, status=404)

    data = request.data
    medication.name = data.get("name", medication.name)
    medication.dosage = data.get("dosage", medication.dosage)
    medication.frequency = data.get("frequency", medication.frequency)
    medication.save()

    return JsonResponse({"message": "Medication updated successfully!"})


@api_view(["DELETE"])
@permission_classes([IsAuthenticated])
def delete_medication(request, medication_id):
    """Remove a saved medication"""
    try:
        medication = Medication.objects.get(id=medication_id, user=request.user)
        medication.delete()
        return JsonResponse({"message": "Medication deleted successfully!"})
    except Medication.DoesNotExist:
        return JsonResponse({"error": "Medication not found"}, status=404)
    
from core.services.ocr_service import extract_text_from_image

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def scan_medication(request):
    """Extracts text from an image and fetches medication details."""
    if 'image' not in request.FILES:
        return JsonResponse({"error": "No image provided"}, status=400)

    file = request.FILES['image']
    file_path = "temp.jpg"

    try:
        with open(file_path, 'wb+') as destination:
            for chunk in file.chunks():
                destination.write(chunk)

        extracted_text = extract_text_from_image(file_path)
        medication_details = fetch_medication_details(extracted_text)

        return JsonResponse(medication_details)

    except Exception as e:
        return JsonResponse({"error": f"Failed to process image: {e}"}, status=500)

    
class MedicationListView(ListAPIView):
    queryset = Medication.objects.all().order_by("id")
    serializer_class = MedicationSerializer
    permission_classes = [IsAuthenticated]

class MedicationReminderListView(ListAPIView):
    queryset = MedicationReminder.objects.all()
    serializer_class = MedicationReminderSerializer
    permission_classes = [IsAuthenticated]