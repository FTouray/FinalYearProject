from datetime import datetime, time, timedelta, timezone
from django.utils.timezone import now, timedelta
import json
from django.utils import timezone
from django.http import JsonResponse
from django.utils.dateparse import parse_time, parse_datetime
import pandas as pd
from django.db.models import Max
import requests
from rest_framework import status, viewsets
from rest_framework.response import Response
from rest_framework.views import APIView
from django.db.models import Sum
from django.contrib.auth import authenticate
from rest_framework_simplejwt.tokens import RefreshToken, AccessToken
from django.conf import settings
from core.fitness_ai import generate_ai_recommendation, generate_health_trends
from core.services.ocr_service import extract_text_from_image, parse_dosage_info
from core.services.openfda_service import fetch_openfda_drug_details, search_openfda_drugs
from core.services.reminder_service import schedule_medication_reminder
from .serializers import ChatMessageSerializer, CommentSerializer, ExerciseCheckSerializer, FoodCategorySerializer, FoodItemSerializer, ForumCategorySerializer, ForumThreadSerializer, GlucoseCheckSerializer, GlucoseLogSerializer, MealCheckSerializer, MealSerializer, MedicationReminderSerializer, MedicationSerializer, PredictiveFeedbackSerializer, QuestionnaireSessionSerializer, RegisterSerializer, LoginSerializer, SettingsSerializer, SymptomCheckSerializer
from .models import AIHealthTrend, AIRecommendation, Achievement, ChatMessage, Comment, CustomUser, ExerciseCheck, FeelingCheck, FitnessActivity, FoodCategory, FoodItem, ForumCategory, ForumThread, GlucoseCheck, GlucoseLog, GlycaemicResponseTracker, LocalNotificationPrompt, Meal, MealCheck, Medication, MedicationReminder, PersonalInsight, PredictiveFeedback, QuestionnaireSession, Quiz, QuizAttempt, QuizSet, SymptomCheck, UserProfile, UserProgress  
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
from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
import re


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

        # Initialize per-date list
        if date_str not in trend_summary:
            trend_summary[date_str] = {
                "steps": 0,
                "heart_rate": [],
                "sleep_hours": None,
                "calories_burned": 0,
                "distance_km": 0,
                "activities": [],
            }

        entry = {
            "activity_type": activity.activity_type,
            "start_time": activity.start_time.isoformat(),
            "end_time": activity.end_time.isoformat(),
            "is_fallback": activity.is_fallback,
        }

        # Only update these fields if it's not a fallback
        if not activity.is_fallback:
            trend_summary[date_str]["steps"] += activity.steps or 0
            trend_summary[date_str]["calories_burned"] += activity.calories_burned or 0
            trend_summary[date_str]["distance_km"] += activity.distance_km or 0

            if activity.heart_rate is not None:
                trend_summary[date_str]["heart_rate"].append(activity.heart_rate)

            entry.update({
                "steps": activity.steps or 0,
                "calories_burned": activity.calories_burned or 0,
                "distance_km": activity.distance_km or 0,
                "heart_rate": activity.heart_rate,
            })

        # If no sleep yet, and this is a sleep fallback, set it
        if trend_summary[date_str]["sleep_hours"] is None and activity.is_fallback:
            if "sleep" in activity.activity_type.lower():
                trend_summary[date_str]["sleep_hours"] = activity.total_sleep_hours or 0.0

        # Also allow sleep from non-fallback if available (preferred)
        elif trend_summary[date_str]["sleep_hours"] is None and not activity.is_fallback:
            if "sleep" in activity.activity_type.lower():
                trend_summary[date_str]["sleep_hours"] = activity.total_sleep_hours or 0.0

        trend_summary[date_str]["activities"].append(entry)

    # Add average heart rate per day
    for day, data in trend_summary.items():
        rates = data["heart_rate"]
        data["avg_heart_rate_for_day"] = (
            sum(rates) / len(rates) if rates else None
        )
        del data["heart_rate"]

    # Glucose & AI stuff
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
    ai_recommendation = AIRecommendation.objects.create(user=user, recommendation_text=ai_response)
    ai_recommendation.fitness_activities.set(recent_activities)

    latest_fitness = FitnessActivity.objects.filter(user=user, is_fallback=False).order_by("-start_time").first()
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
            "distance_km": latest_fitness.distance_km if latest_fitness else None,
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

    if request.query_params.get("refresh") == "true":
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
def get_all_ai_health_trends(request):
    user = request.user
    period_type = request.query_params.get("period_type", "weekly")

    trends = AIHealthTrend.objects.filter(user=user, period_type=period_type).order_by("-start_date")

    trend_list = []
    for trend in trends:
        trend_list.append({
            "start_date": trend.start_date.strftime("%Y-%m-%d"),
            "end_date": trend.end_date.strftime("%Y-%m-%d"),
            "avg_glucose_level": trend.avg_glucose_level,
            "avg_steps": trend.avg_steps,
            "avg_sleep_hours": trend.avg_sleep_hours,
            "avg_heart_rate": trend.avg_heart_rate,
            "total_exercise_sessions": trend.total_exercise_sessions,
            "ai_summary": trend.ai_summary,
        })

    return JsonResponse({"trends": trend_list})


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
        "distance_km": latest.distance_km,
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

    # Step 1: Get latest non-fallback activity for today
    activity = (
        FitnessActivity.objects
        .filter(user=user, start_time__date=today, is_fallback=False)
        .order_by("-start_time")
        .first()
    )

    # Step 2: If no activity found today, check yesterday
    if not activity:
        yesterday = today - timedelta(days=1)
        activity = (
            FitnessActivity.objects
            .filter(user=user, start_time__date=yesterday, is_fallback=False)
            .order_by("-start_time")
            .first()
        )

    if not activity:
        return Response({"message": "No valid fitness data found."}, status=404)

    # Step 3: If activity has no sleep_hours, look for fallback sleep data
    if not activity.total_sleep_hours:
        sleep_fallback = (
            FitnessActivity.objects
            .filter(
                user=user,
                start_time__date=activity.start_time.date(),
                is_fallback=True,
                activity_type__icontains="sleep"
            )
            .order_by("-start_time")
            .first()
        )
        if sleep_fallback:
            activity.total_sleep_hours = sleep_fallback.total_sleep_hours

    return Response({
        "activity_type": activity.activity_type,
        "steps": activity.steps,
        "sleep_hours": activity.total_sleep_hours,
        "heart_rate": activity.heart_rate,
        "calories_burned": activity.calories_burned,
        "distance_km": activity.distance_km,
        "start_time": activity.start_time,
        "end_time": activity.end_time,
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
                "distance_km": data.get("distance_km"),
                "source": "Phone",
                "last_activity_time": end_time,
                "is_manual_override": False,
            }
        )

        return Response({"message": "Health data stored successfully."}, status=201)

    except Exception as e:
        return Response({"error": f"Failed to store health data: {str(e)}"}, status=400)

@api_view(["GET"])
@permission_classes([IsAuthenticated])
def get_last_synced_workout(request):
    last = FitnessActivity.objects.filter(
        user=request.user,
        is_manual_override=False
    ).order_by("-end_time").first()

    if not last:
        return Response({"last_synced": None})

    return Response({"last_synced": last.end_time.isoformat()})


client = OpenAI()

@api_view(["POST"])
@permission_classes([IsAuthenticated])
def chat_with_virtual_coach(request):
    user = request.user
    user_message = request.data.get("message")

    if not user_message:
        return JsonResponse({"error": "Message cannot be empty"}, status=400)

    ChatMessage.objects.create(user=user, sender="user", message=user_message)
   
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

@api_view(["GET"])
@permission_classes([IsAuthenticated])
def fetch_medications_from_openfda(request):
    query = request.GET.get("query", "")

    results = search_openfda_drugs(query=query.strip())
    return JsonResponse({"medications": results})

@api_view(["GET"])
@permission_classes([IsAuthenticated])
def get_medication_details_openfda(request):
    fda_id = request.GET.get("id")
    if not fda_id:
        return JsonResponse({"error": "Missing FDA ID"}, status=400)

    details = fetch_openfda_drug_details(fda_id)
    if not details:
        return JsonResponse({"error": "Details not found"}, status=404)

    return JsonResponse(details)


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def set_reminder(request):
    """
    Expects JSON like:
    {
      "medication_id": 123,
      "day_of_week": 4,   # (1=Monday, 4=Thursday, etc.)
      "hour": 16,
      "minute": 0,
      "repeat_weeks": 4
    }
    """
    user = request.user
    medication_id = request.data.get("medication_id")
    day_of_week = request.data.get("day_of_week")
    hour = request.data.get("hour")
    minute = request.data.get("minute")
    repeat_weeks = request.data.get("repeat_weeks", 4)

    if not medication_id or day_of_week is None or hour is None or minute is None:
        return Response({"error": "Missing required fields."}, status=400)

    medication = get_object_or_404(Medication, id=medication_id, user=user)

    reminder = MedicationReminder.objects.create(
        user=user,
        medication=medication,
        day_of_week=day_of_week,
        hour=hour,
        minute=minute,
        repeat_weeks=repeat_weeks
    )

    return Response({"message": "Reminder set successfully!", "reminder_id": reminder.id}, status=201)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def get_medication_reminders(request):
    """Retrieve all medication reminders for the user."""
    reminders = MedicationReminder.objects.filter(user=request.user).select_related("medication")
    serializer = MedicationReminderSerializer(reminders, many=True)
    return Response(serializer.data, status=200)

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
    """Save medication from OpenFDA or manual entry"""
    user = request.user
    name = request.data.get("name")
    fda_id = request.data.get("fda_id")  # renamed field
    generic_name = request.data.get("generic_name", "")
    dosage = request.data.get("dosage", "")
    frequency = request.data.get("frequency", "")
    last_taken = request.data.get("last_taken", None)

    if not name:
        return Response({"error": "Medication name is required."}, status=400)

    medication, created = Medication.objects.get_or_create(
        user=user,
        name=name,
        defaults={
            "fda_id": fda_id,
            "generic_name": generic_name,
            "dosage": dosage,
            "frequency": frequency,
            "last_taken": last_taken,
        },
    )

    serializer = MedicationSerializer(medication)
    return Response(
        {"message": "Medication saved successfully." if created else "Already exists.", "data": serializer.data},
        status=201 if created else 200,
    )


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

    if 'last_taken' in data:
        medication.last_taken = data['last_taken']  # parse if needed

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
    if 'image' not in request.FILES:
        return JsonResponse({"error": "No image provided"}, status=400)

    file = request.FILES['image']
    file_path = "temp.jpg"
    try:
        with open(file_path, 'wb+') as destination:
            for chunk in file.chunks():
                destination.write(chunk)

        extracted_text = extract_text_from_image(file_path)
        parsed_info = parse_dosage_info(extracted_text)

        matches = search_openfda_drugs(extracted_text)
        if matches:
            top = matches[0]
            details = fetch_openfda_drug_details(top['id'])

            return JsonResponse({
                "name": details.get("name", extracted_text),
                "fda_id": top["id"],
                "generic_name": details.get("generic_name", ""),
                "dosage": parsed_info.get("dosage"),
                "frequency": parsed_info.get("frequency"),
            })
        else:
            return JsonResponse({
                "name": extracted_text,
                "fda_id": None,
                "dosage": parsed_info.get("dosage"),
                "frequency": parsed_info.get("frequency"),
            })

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
    
@api_view(["GET"])
@permission_classes([AllowAny])
def list_threads_by_category(request, category_id):
    threads = ForumThread.objects.filter(category_id=category_id).order_by("-created_at")
    data = [
        {
            "id": thread.id,
            "title": thread.title,
            "comment_count": thread.comment_count(),
            "latest_reply": thread.latest_reply().created_at.strftime("%Y-%m-%d %H:%M") if thread.latest_reply() else None,
        }
        for thread in threads
    ]
    return JsonResponse(data, safe=False)

@api_view(["POST"])
@permission_classes([IsAuthenticated])
def create_thread(request):
    title = request.data.get("title")
    category_id = request.data.get("category_id")

    if not title or not category_id:
        return JsonResponse({"error": "Missing title or category"}, status=400)

    thread = ForumThread.objects.create(
        title=title,
        category_id=category_id,
        created_by=request.user
    )

    return JsonResponse({"id": thread.id, "message": "Thread created successfully"}, status=201)

# Comments
@api_view(["GET"])
@permission_classes([AllowAny])
def list_comments_for_thread(request, thread_id):
    comments = Comment.objects.filter(thread_id=thread_id).order_by("created_at")
    serializer = CommentSerializer(comments, many=True)
    return JsonResponse(serializer.data, safe=False)

@api_view(["POST"])
@permission_classes([IsAuthenticated])
def create_comment(request):
    content = request.data.get("content")
    thread_id = request.data.get("thread_id")

    if not content or not thread_id:
        return JsonResponse({"error": "Missing content or thread ID"}, status=400)

    comment = Comment.objects.create(
        content=content,
        thread_id=thread_id,
        author=request.user
    )

    # Broadcast via WebSocket
    channel_layer = get_channel_layer()
    async_to_sync(channel_layer.group_send)(
        f"forum_{thread_id}",
        {
            "type": "chat.message",
            "message": comment.content,
            "username": comment.author.username,
        }
    )

    return JsonResponse({"message": "Comment added"}, status=201)
        
@api_view(["GET"])
@permission_classes([AllowAny])
def list_forum_categories(request):
    return JsonResponse(list(ForumCategory.objects.values()), safe=False)

@api_view(["POST"])
@permission_classes([IsAuthenticated])
def create_category(request):
    name = request.data.get("name")
    description = request.data.get("description", "")

    if not name:
        return JsonResponse({"error": "Missing category name"}, status=400)

    if ForumCategory.objects.filter(name__iexact=name).exists():
        return JsonResponse({"error": "A category with that name already exists."}, status=400)

    category = ForumCategory.objects.create(
        name=name,
        description=description
    )

    return JsonResponse({"id": category.id, "message": "Category created"}, status=201)

client = OpenAI()

@api_view(["GET"])
@permission_classes([IsAuthenticated])
def get_insights_summary_with_ai(request):
    user = request.user
    today = now().date()

    # --- Glucose ---
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

    # --- Meals ---
    manual_meals_today = Meal.objects.filter(user=user, timestamp__date=today).count()
    questionnaire_meals_today = MealCheck.objects.filter(session__user=user, created_at__date=today).count()
    total_meals_today = manual_meals_today + questionnaire_meals_today

    avg_gi_meals = Meal.objects.filter(user=user).aggregate(Avg("food_items__glycaemic_index"))["food_items__glycaemic_index__avg"]
    avg_weighted_gi_questionnaire = MealCheck.objects.filter(session__user=user)
    weighted_gis = [meal.weighted_gi for meal in avg_weighted_gi_questionnaire]
    avg_weighted_gi = round(sum(weighted_gis) / len(weighted_gis), 2) if weighted_gis else None

    # --- Activity ---
    fitness_logs = FitnessActivity.objects.filter(user=user).order_by("-start_time")[:7]
    steps = [f.steps for f in fitness_logs if f.steps]
    sleep = [f.total_sleep_hours for f in fitness_logs if f.total_sleep_hours]

    questionnaire_exercises = ExerciseCheck.objects.filter(session__user=user)
    exercise_sessions = questionnaire_exercises.count()

    avg_steps = int(sum(steps) / len(steps)) if steps else None
    avg_sleep = round(sum(sleep) / len(sleep), 2) if sleep else None

    # --- Medications ---
    next_reminder = MedicationReminder.objects.filter(user=user).order_by("hour", "minute").first()

    # --- Questionnaire ---
    sessions = QuestionnaireSession.objects.filter(user=user, completed=True)
    symptoms_logged = SymptomCheck.objects.filter(session__in=sessions).count()
    skipped_meals = MealCheck.objects.filter(session__in=sessions).exclude(skipped_meals=[]).count()

    # --- Summary for AI ---
    summary = f"""
    AI Health Summary for {user.username}:

    Glucose:
    - Latest value: {latest_glucose_value}
    - Average: {avg_glucose_level}

    Meals:
    - Logged today: {total_meals_today}
    - Avg GI (manual meals): {round(avg_gi_meals, 2) if avg_gi_meals else 'N/A'}
    - Avg Weighted GI (questionnaire): {avg_weighted_gi}

    Activity:
    - Avg steps: {avg_steps}
    - Avg sleep: {avg_sleep}
    - Exercise sessions: {exercise_sessions}

    Medications:
    - Next reminder: {next_reminder.medication.name if next_reminder else 'None'} at {f"{next_reminder.hour:02d}:{next_reminder.minute:02d}" if next_reminder else 'N/A'}

    Questionnaire:
    - Sessions completed: {sessions.count()}
    - Symptoms logged: {symptoms_logged}
    - Skipped meals: {skipped_meals}

    Please generate a friendly, personalized insight summary for the user based on this data.
    Highlight wellness, risks, and give at least 1 actionable tip.
    """

    response = client.chat.completions.create(
        model="gpt-4",
        messages=[
            {"role": "system", "content": "You are a diabetic health coach providing expert personalized feedback."},
            {"role": "user", "content": summary}
        ]
    )

    ai_insight = response.choices[0].message.content.strip()

    # Save insight to database
    PersonalInsight.objects.create(
        user=user,
        summary_text=ai_insight,
        raw_data={
            "glucose": {
                "latest": latest_glucose_value,
                "timestamp": latest_glucose_time.isoformat() if latest_glucose_time else None,
                "average": avg_glucose_level,
            },
            "meals_logged_today": total_meals_today,
            "avg_gi": avg_gi_meals,
            "avg_weighted_gi": avg_weighted_gi,
            "avg_steps": avg_steps,
            "avg_sleep": avg_sleep,
            "exercise_sessions_logged": exercise_sessions,
            "next_med_reminder": {
                "medication": next_reminder.medication.name if next_reminder else None,
                "hour": next_reminder.hour if next_reminder else None,
                "minute": next_reminder.minute if next_reminder else None,
            } if next_reminder else None,
            "questionnaire": {
                "completed": sessions.count(),
                "symptoms_logged": symptoms_logged,
                "skipped_meals": skipped_meals,
            },
        }
    )

    return Response({
        "glucose": {
            "latest": {
                "value": latest_glucose_value,
                "timestamp": latest_glucose_time,
            },
            "average": avg_glucose_level,
        },
        "meals": {
            "logged_today": total_meals_today,
            "avg_gi_meals": round(avg_gi_meals, 2) if avg_gi_meals else None,
            "avg_weighted_gi": avg_weighted_gi,
        },
        "activity": {
            "avg_steps": avg_steps,
            "avg_sleep": avg_sleep,
            "exercise_sessions_logged": exercise_sessions,
        },
        "medications": {
            "next_reminder": {
                "medication": next_reminder.medication.name if next_reminder else None,
                "hour": next_reminder.hour if next_reminder else None,
                "minute": next_reminder.minute if next_reminder else None,
            } if next_reminder else None,
        },
        "questionnaire": {
            "sessions_completed": sessions.count(),
            "symptoms_logged": symptoms_logged,
            "skipped_meals": skipped_meals,
        },
        "ai_insight": ai_insight,
    })


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def list_past_insights(request):
    user = request.user
    insights = PersonalInsight.objects.filter(user=user).order_by("-generated_at")

    data = [
        {
            "timestamp": i.generated_at.strftime("%Y-%m-%d %H:%M"),
            "summary": i.summary_text,
            "raw_data": i.raw_data
        }
        for i in insights
    ]
    return JsonResponse({"insights": data})

@api_view(["GET"])
@permission_classes([AllowAny])
def get_quizset_quizzes(request, level):
    quiz_set = get_object_or_404(QuizSet, level=level)
    quizzes = Quiz.objects.filter(quiz_set=quiz_set)
    data = [
        {
            "id": quiz.id,
            "question": quiz.question,
            "options": [quiz.correct_answer] + quiz.wrong_answers
        }
        for quiz in quizzes
    ]
    return JsonResponse({"quiz_set": quiz_set.title, "description": quiz_set.description, "quizzes": data})

@api_view(["POST"])
@permission_classes([IsAuthenticated])
def submit_quiz(request, quizset_id):
    quiz_set = get_object_or_404(QuizSet, pk=quizset_id)
    user_answers = request.data.get("answers", [])
    questions = Quiz.objects.filter(quiz_set=quiz_set)
    score = 0

    detailed_results = []
    for i, question in enumerate(questions):
        user_answer = user_answers[i] if i < len(user_answers) else None
        is_correct = user_answer == question.correct_answer
        if is_correct:
            score += 1

        detailed_results.append({
            "id": question.id,
            "question": question.question,
            "correct_answer": question.correct_answer,
            "user_answer": user_answer,
            "is_correct": is_correct,
            "options": [question.correct_answer] + question.wrong_answers
        })

    percentage = (score / questions.count()) * 100
    xp_awarded = 100 if percentage >= 70 else 50

    progress, created = UserProgress.objects.get_or_create(
        user=request.user,
        quiz_set=quiz_set,
        defaults={
            "score": 0.0,
            "completed": False,
            "badge_awarded": False,
            "xp_earned": 0
        }
    )
    progress.score = percentage
    progress.completed = percentage >= 70
    progress.xp_earned = xp_awarded
    progress.save()

    if progress.completed and not progress.badge_awarded:
        Achievement.objects.create(user=request.user, badge_name=f"Completed {quiz_set.title}", points=100)
        progress.badge_awarded = True
        progress.save()

    user_profile, _ = UserProfile.objects.get_or_create(user=request.user)
    user_profile.update_xp_and_level(xp_awarded)

    QuizAttempt.objects.create(
        user=request.user,
        quiz_set=quiz_set,
        score=percentage,
        xp_earned=xp_awarded,
        review=detailed_results
    )

    return JsonResponse({
        "score": percentage,
        "completed": progress.completed,
        "xp_awarded": xp_awarded,
        "quiz_set_level": quiz_set.level,
        "review": detailed_results
    })


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def list_all_quizsets_and_progress(request):
    quiz_sets = QuizSet.objects.all().order_by("level")
    progress_map = {
        p.quiz_set.id: {"completed": p.completed, "score": p.score, "xp_earned": p.xp_earned}
        for p in UserProgress.objects.filter(user=request.user)
    }
    data = [
        {
            "id": qs.id,
            "title": qs.title,
            "description": qs.description,
            "level": qs.level,
            "progress": progress_map.get(qs.id, {"completed": False, "score": 0, "xp_earned": 0})
        }
        for qs in quiz_sets
    ]
    return JsonResponse(data, safe=False)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def list_user_achievements(request):
    achievements = Achievement.objects.filter(user=request.user).order_by("-awarded_at")
    data = [
        {
            "badge_name": a.badge_name,
            "points": a.points,
            "awarded_at": a.awarded_at.strftime("%Y-%m-%d %H:%M")
        }
        for a in achievements
    ]
    return JsonResponse(data, safe=False)


@api_view(["GET"])
@permission_classes([AllowAny])
def leaderboard(request):
    leaderboard_data = Achievement.objects.values("user__username").annotate(
        total_points=Sum("points")
    ).order_by("-total_points")[:10]
    data = [
        {
            "username": entry["user__username"],
            "points": entry["total_points"]
        }
        for entry in leaderboard_data
    ]
    return JsonResponse(data, safe=False)

@api_view(["GET"])
@permission_classes([IsAuthenticated])
def get_user_profile(request):
    profile, _ = UserProfile.objects.get_or_create(user=request.user)
    print("User:", request.user)
    print("Has profile:", hasattr(request.user, 'userprofile'))
    return JsonResponse({
        "xp": profile.xp,
        "level": profile.level
    })
    
@api_view(["GET"])
@permission_classes([IsAuthenticated])
def list_quiz_attempts(request):
    attempts = QuizAttempt.objects.filter(user=request.user).order_by("-attempted_at")
    data = [
        {
            "level": a.quiz_set.level,
            "title": a.quiz_set.title,
            "score": a.score,
            "xp_earned": a.xp_earned,
            "attempted_at": a.attempted_at.strftime("%Y-%m-%d %H:%M"),
            "review": a.review
        }
        for a in attempts
    ]
    return JsonResponse(data, safe=False)

SYMPTOMS = [
    'Fatigue', 'Headaches', 'Dizziness', 'Thirst', 'Nausea', 'Blurred Vision',
    'Irritability', 'Sweating', 'Frequent Urination', 'Dry Mouth',
    'Slow Wound Healing', 'Weight Loss', 'Increased Hunger', 'Shakiness',
    'Hunger', 'Fast Heartbeat'
]

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_predictive_feedback(request):
    user = request.user
    all_feedback = PredictiveFeedback.objects.filter(user=user).order_by('-timestamp')

    # Read preferred unit from headers (default to mg/dL)
    preferred_unit = request.headers.get('Glucose-Unit', 'mg/dL')

    def convert_value(val):
        try:
            val = float(val)
            return val / 18.01559 if preferred_unit == 'mmol/L' else val
        except:
            return val

    def convert_units(text):
        # Look for patterns like <=130, >=180, =110
        pattern = r'([<>=]=?)\s*(\d+(?:\.\d+)?)'

        def replacer(match):
            op = match.group(1)
            value = match.group(2)
            converted = convert_value(value)
            rounded = round(converted, 1) if preferred_unit == 'mmol/L' else int(round(converted))
            return f"{op} {rounded}"

        return re.sub(pattern, replacer, text)

    feedback_data = [
        {
            'text': convert_units(fb.insight),
            'type': fb.feedback_type,
            'timestamp': fb.timestamp
        }
        for fb in all_feedback
    ]

    summary = {
        'positive': [f['text'] for f in feedback_data if f['type'] in ('improvement', 'shap') and f['text'].startswith("✅")],
        'trend': [f['text'] for f in feedback_data if f['type'] == 'trend'],
        'all': feedback_data
    }

    return Response({'predictive_feedback': summary})