from rest_framework import serializers
from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError
from .models import FoodItem, GlycaemicResponseTracker, Meal, GlucoseLog  # Import your models

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

# Food Item Serializer
class FoodItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = FoodItem
        fields = ['foodId', 'name', 'glycaemic_index', 'carbs']

# Meal Serializer
class MealSerializer(serializers.ModelSerializer):
    food_items = FoodItemSerializer(many=True)

    class Meta:
        model = Meal
        fields = ['mealId', 'user', 'tracker', 'food_items', 'total_glycaemic_index', 'total_carbs', 'timestamp']
    
    def create(self, validated_data):
        # Extract food items data
        food_items_data = validated_data.pop('food_items')
        meal = Meal.objects.create(**validated_data)
        
        # Get FoodItem instances and add to the meal
        for food_item_data in food_items_data:
            food_item, created = FoodItem.objects.get_or_create(
                name=food_item_data['name'],
                defaults={
                    'glycaemic_index': food_item_data['glycaemic_index'],
                    'carbs': food_item_data.get('carbs')
                }
            )
            meal.food_items.add(food_item)
        
        # Calculate totals for the meal
        meal.calculate_totals()
        return meal

# Glucose Log Serializer
class GlucoseLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = GlucoseLog
        fields = ['logID', 'user', 'glucose_level', 'timestamp', 'meal_context']
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
