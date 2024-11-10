from django.db import models
from django.contrib.auth.models import AbstractUser
from django.db.models import Q
from django.forms import JSONField
from datetime import datetime

# Custom user model extending Django's AbstractUser
class CustomUser(AbstractUser):
    email = models.EmailField(unique=True)  # Unique email field for user authentication
    phone_number = models.CharField(max_length=15, blank=True, null=True)  # Optional phone number field
    first_name = models.CharField(max_length=30, blank=False, null=False)  # First name, required
    last_name = models.CharField(max_length=30, blank=False, null=False)  # Last name, required
    meal_count = models.IntegerField(default=0) # Field to store the number of meals logged by the user

    def __str__(self):
        return self.username  # Return username when the user object is printed

# Model to store food categories
class FoodCategory(models.Model):
    name = models.CharField(max_length=100)  # Name of the category

    def __str__(self):
        return self.name

# Model to store food items and their glycaemic index
class FoodItem(models.Model):
    foodId = models.AutoField(primary_key=True, null=False)  # Primary key for the food item
    name = models.CharField(max_length=255)  # Name of the food item
    glycaemic_index = models.FloatField()  # Glycemic index of the food item
    carbs = models.FloatField(null=True, blank=True)  # Carbohydrate content, optional
    category = models.ForeignKey(FoodCategory, on_delete=models.CASCADE, related_name='food_items')  # Link to the category
    
    def __str__(self):
        return self.name

# Model to store meal details linked to the glycaemic response tracker
class Meal(models.Model):
    mealId = models.AutoField(primary_key=True, null=False)  # Primary key for the meal
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE, related_name='meals') # Foreign key linking to user
    user_meal_id = models.IntegerField()
    name = models.CharField(max_length=100, blank=True, null=True)  # Optional meal name
    food_items = models.ManyToManyField(FoodItem, related_name='meals')  # Link to multiple food items  # Field to store food items in the meal
    timestamp = models.DateTimeField(auto_now_add=True)  # Automatically set timestamp when meal is logged

    class Meta:
        unique_together = ("user", "user_meal_id")  # Ensures unique user-specific IDs

    def __str__(self):
        formatted_timestamp = self.timestamp.strftime("%d/%m/%Y %H:%M:%S")
        return f"Meal logged by {self.user.username} on {formatted_timestamp}"

    @property # Calculate the total glycaemic index of the meal
    def total_glycaemic_index(self):
        return sum(item.glycaemic_index for item in self.food_items.all())

    @property # Calculate the total carbs in the meal
    def total_carbs(self):
        return sum(item.carbs for item in self.food_items.all() if item.carbs is not None)

# Model to log glucose levels for each user
class GlucoseLog(models.Model):
    logID = models.AutoField(primary_key=True)  # Primary key for the log
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE, related_name='glucose_logs')  # Foreign key linking to CustomUser
    glucose_level = models.FloatField()  # Field to store glucose level
    timestamp = models.DateTimeField(auto_now_add=True)  # Automatically set timestamp when log is created
    meal_context = models.CharField(max_length=50, choices=[
        ('fasting', 'Fasting'),
        ('pre_meal', 'Pre-Meal'),
        ('post_meal', 'Post-Meal'),
    ])  # Context of glucose level logging    
    # meal = models.ForeignKey(Meal, on_delete=models.SET_NULL, null=True, blank=True)  # Add foreign key to Meal
    class Meta:
        indexes = [models.Index(fields=['user']),]  # Index for faster lookups by user
        constraints = [
            models.CheckConstraint(check=Q(glucose_level__gte=0), name='glucose_level_gte_0'),  # Constraint to ensure glucose level is non-negative
        ]

    def __str__(self):
        formatted_timestamp = self.timestamp.strftime('%d/%m/%Y %H:%M:%S')
        return f"{self.user.username} - {self.glucose_level} at {formatted_timestamp}"

# Model to track glycaemic responses linked to a user
class GlycaemicResponseTracker(models.Model):
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE, related_name='response_trackers')  # Foreign key linking to user
    user_data = JSONField()  # Field to store user-specific data, potentially in JSON format
    response_patterns = models.TextField(blank=True, null=True)  # Field to store observed response patterns
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    meals = models.ManyToManyField(Meal, related_name="response_trackers_meals", blank=True)  # Add many-to-many relationship
    # insights = models.JSONField(default=dict, blank=True)  # Store insights as a JSON field

    # def save_insights(self, insights):
    #     """
    #     Save the generated insights into the `insights` field.
    #     """
    #     self.insights = insights
    #     self.save()

# Virtual health coach model to provide personalized health guidance
class VirtualHealthCoach(models.Model):
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE, related_name='health_coach')  # Foreign key linking to user
    user_patterns =models.TextField(default='', blank=True)  # Field to store patterns from user activity logs
    motivational_messages = models.TextField(blank=True, null=True)  # Field to store motivational messages

    class Meta:
        constraints = [
            models.CheckConstraint(check=Q(motivational_messages__isnull=False), name='motivational_messages_not_null'),  # Ensure messages are not null
        ]

# Model to store medication details
class Medication(models.Model):
    name = models.CharField(max_length=100, unique=True)  # Unique name for each medication
    dosage = models.CharField(max_length=100)  # Dosage instructions for the medication
    frequency = models.CharField(max_length=100)  # Frequency of medication intake

# Model to track medication adherence for each user
class MedicationTracker(models.Model):
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE, related_name='medication_trackers')  # Foreign key linking to user
    medication_list = models.ManyToManyField(Medication)  # Many-to-many relationship with Medication
    adherence_data = models.TextField(blank=True, null=True)  # Field to store adherence logs or notes

# Model to log hypo/hyperglycaemia alerts for users
class HypoHyperGlycaemiaAlert(models.Model):
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE, related_name='alerts')  # Foreign key linking to user
    glucose_level = models.FloatField()  # Glucose level at the time of alert
    timestamp = models.DateTimeField(auto_now_add=True)  # Automatically set timestamp when alert is logged
    alert_type = models.CharField(max_length=20)  # Type of alert (e.g., 'hypo', 'hyper')

# Model to store community support interactions
class CommunitySupport(models.Model):
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE, related_name='community_posts')  # Foreign key linking to user
    post_content = models.TextField()  # Content of the community post
    sentiment_score = models.FloatField(blank=True, null=True)  # Field to store sentiment analysis score of the post
