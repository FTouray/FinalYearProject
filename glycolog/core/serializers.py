from django.shortcuts import get_object_or_404
from rest_framework import serializers
from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError
from .models import FeelingCheck, FollowUpQuestion, FoodCategory, FoodItem, GlycaemicResponseTracker, Insight, Meal, GlucoseLog, QuestionnaireSession, SymptomCheck  # Import your models

# Get the custom user model
User = get_user_model()

# Serializer for user registration
class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, required=True, validators=[validate_password])
    password2 = serializers.CharField(write_only=True, required=True)  # For password confirmation

    class Meta:
        model = User
        fields = ('username', 'email', 'phone_number', 'first_name', 'last_name', 'password', 'password2')

    # Validate the data to ensure passwords match
    def validate(self, data):
        if data['password'] != data['password2']:
            raise serializers.ValidationError({"password": "Passwords do not match."})
        return data

    # Create the user with the validated data
    def create(self, validated_data):
        validated_data.pop('password2')  # Remove password2 as it's not needed in the database
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            phone_number=validated_data['phone_number'],
            first_name=validated_data['first_name'],
            last_name=validated_data['last_name'],
        )
        user.set_password(validated_data['password'])  # Hash and set the password
        user.save()
        return user

# Serializer for user login
class LoginSerializer(serializers.Serializer):
    username = serializers.CharField(required=True)
    password = serializers.CharField(write_only=True, required=True)

# Glucose Log Serializer
class GlucoseLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = GlucoseLog
        fields = ["logID", "user", "glucose_level", "timestamp", "meal_context"]
        read_only_fields = ['user']  # Make the user field read-only

    def create(self, validated_data):
        # Automatically set the user from the request
        request = self.context.get('request')
        if request and hasattr(request, 'user'):
            validated_data['user'] = request.user  # Set the logged-in user
        return super().create(validated_data)

    # Validations
    def validate_glucose_level(self, value):
        # Ensure glucose level is within a reasonable range
        if value < 0:
            raise serializers.ValidationError("Glucose level must be a positive number.")
        return value


class SettingsSerializer(serializers.Serializer):
    selectedUnit = serializers.ChoiceField(choices=['mmol/L', 'mg/dL'])  # Limit choices for units
    notificationsEnabled = serializers.BooleanField(required=False)  # Optional field
    darkModeEnabled = serializers.BooleanField(required=False)  # Optional field


class FoodCategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = FoodCategory
        fields = ["id", "name"]


# Food Item Serializer
class FoodItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = FoodItem
        fields = ["foodId", "name", "glycaemic_index", "carbs"]


# Meal Serializer
class MealSerializer(serializers.ModelSerializer):
    food_items = FoodItemSerializer(many=True, read_only=True)
    food_item_ids = serializers.ListField(child=serializers.IntegerField(), write_only=True, required=False)
    name = serializers.CharField(required=False, allow_blank=True)

    class Meta:
        model = Meal
        fields = ["mealId", "user", "user_meal_id", "name", "food_items", "food_item_ids", "total_glycaemic_index", "total_carbs", "timestamp",]
        read_only_fields = ["user", "user_meal_id", "total_glycaemic_index", "total_carbs",]  # These fields are read-only

    def create(self, validated_data):
        request = self.context.get("request")
        if request and hasattr(request, "user"):
            user = request.user
            user.meal_count += 1
            user.save()

            # Assign the user-specific meal ID
            validated_data["user"] = user  # Set the logged-in user
            validated_data["user_meal_id"] = user.meal_count

        food_item_ids = validated_data.pop("food_item_ids", [])  # Extract food item IDs
        meal = Meal.objects.create(**validated_data)  # Create the meal instance

        for food_item_id in food_item_ids:
            food_item = get_object_or_404(FoodItem, foodId=food_item_id)
            meal.food_items.add(food_item)

        return meal


# Glycaemic Response Tracker Serializer
class GlycaemicResponseTrackerSerializer(serializers.ModelSerializer):
    user_data = serializers.JSONField()  # Handle the user data as JSON
    meals = MealSerializer(many=True, read_only=True)

    class Meta:
        model = GlycaemicResponseTracker
        fields = ["id", "user", "user_data", "response_patterns", "meals"]
        # fields = ["id", "user", "meals", "insights"]

    def validate_user_data(self, value):
        # Custom validation logic for user_data if needed
        return value

# Questionnaire Session Serializer
class QuestionnaireSessionSerializer(serializers.ModelSerializer):
    class Meta:
        model = QuestionnaireSession
        fields = ["id", "user", "feeling_check", "current_step", "completed", "created_at"]
        read_only_fields = ["id", "created_at"]

# Symptom Check Serializer
class SymptomCheckSerializer(serializers.ModelSerializer):
    class Meta:
        model = SymptomCheck
        fields = ["id", "session", "symptoms", "created_at"]
        read_only_fields = ["id", "created_at"]

# Feeling Check Serializer
class FeelingCheckSerializer(serializers.ModelSerializer):
    class Meta:
        model = FeelingCheck
        fields = ['id', 'feeling', 'timestamp']

class FollowUpQuestionSerializer(serializers.ModelSerializer):
    class Meta:
        model = FollowUpQuestion
        fields = ['id', 'question', 'response']

class InsightSerializer(serializers.ModelSerializer):
    class Meta:
        model = Insight
        fields = ['id', 'insight', 'timestamp']
