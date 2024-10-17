from django.db import models
from django.contrib.auth.models import AbstractUser
from django.db.models import Q

# Custom user model extending Django's AbstractUser
class CustomUser(AbstractUser):
    email = models.EmailField(unique=True)  # Unique email field for user authentication
    phone_number = models.CharField(max_length=15, blank=True, null=True)  # Optional phone number field
    first_name = models.CharField(max_length=30, blank=False, null=False)  # First name, required
    last_name = models.CharField(max_length=30, blank=False, null=False)  # Last name, required

    def __str__(self):
        return self.username  # Return username when the user object is printed

# Model to log glucose levels for each user
class GlucoseLog(models.Model):
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE, related_name='glucose_logs')  # Foreign key linking to CustomUser
    glucose_level = models.FloatField()  # Field to store glucose level
    timestamp = models.DateTimeField(auto_now_add=True)  # Automatically set timestamp when log is created
    mealContext = models.CharField(max_length=50, choices=[
        ('fasting', 'Fasting'),
        ('pre_meal', 'Pre-Meal'),
        ('post_meal', 'Post-Meal'),
    ])  # Context of glucose level logging    
    class Meta:
        indexes = [models.Index(fields=['user']),]  # Index for faster lookups by user
        constraints = [
            models.CheckConstraint(check=Q(glucose_level__gte=0), name='glucose_level_gte_0'),  # Constraint to ensure glucose level is non-negative
        ]
        
    def __str__(self):
        return f"{self.user} - {self.glucoseLevel} at {self.timestamp}"

# Model to store meal details linked to the glycaemic response tracker
class Meal(models.Model):
    tracker = models.ForeignKey('GlycaemicResponseTracker', on_delete=models.CASCADE, related_name='meals')  # Foreign key linking to the tracker
    food_items = models.TextField()  # Field to store food items in the meal
    glycaemic_index = models.FloatField()  # Glycaemic index of the meal
    carbs = models.FloatField()  # Total carbs in the meal
    timestamp = models.DateTimeField(auto_now_add=True)  # Automatically set timestamp when meal is logged

    class Meta:
        indexes = [models.Index(fields=['tracker']),]  # Index for faster lookups by tracker

# Model to track glycaemic responses linked to a user
class GlycaemicResponseTracker(models.Model):
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE, related_name='response_trackers')  # Foreign key linking to user
    user_data = models.TextField()  # Field to store user-specific data, potentially in JSON format
    response_patterns = models.TextField(blank=True, null=True)  # Field to store observed response patterns
    meal_log = models.TextField(blank=True, null=True)  # Summary of meals logged by the user

# Virtual health coach model to provide personalized health guidance
class VirtualHealthCoach(models.Model):
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE, related_name='health_coach')  # Foreign key linking to user
    user_patterns = models.TextField()  # Field to store patterns from user activity logs
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
