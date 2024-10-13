from rest_framework import serializers
from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError
from .models import GlycaemicResponseTracker, Meal, GlucoseLog  # Import your models

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

# Glycaemic Response Tracker Serializer
class GlycaemicResponseTrackerSerializer(serializers.ModelSerializer):
    user_data = serializers.JSONField()  # Handle the user data as JSON

    class Meta:
        model = GlycaemicResponseTracker
        fields = ['trackerID', 'userID', 'user_data', 'responsePatterns', 'mealLog']

    
    def validate_user_data(self, value):
        # Custom validation logic for user_data if needed
        return value

# Meal Serializer
class MealSerializer(serializers.ModelSerializer):
    class Meta:
        model = Meal
        fields = ['mealID', 'trackerID', 'foodItems', 'glycaemicIndex', 'carbs', 'timestamp']

    # Validation or methods???
    def validate_foodItems(self, value):
        # Ensure foodItems is not empty
        if not value:
            raise serializers.ValidationError("Food items cannot be empty.")
        return value

# Glucose Log Serializer
class GlucoseLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = GlucoseLog
        fields = ['logID', 'userID', 'glucoseLevel', 'timestamp', 'mealContext']

    # Validations
    def validate_glucoseLevel(self, value):
        # Ensure glucose level is within a reasonable range
        if value < 0:
            raise serializers.ValidationError("Glucose level must be a positive number.")
        return value
