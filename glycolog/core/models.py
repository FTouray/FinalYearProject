from django.db import models
from django.contrib.auth.models import AbstractUser
from django.db.models import Q
from django.forms import JSONField
from datetime import datetime, timedelta

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

# Model to track the questionnaire session for each user
class QuestionnaireSession(models.Model):
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE, related_name="questionnaire_sessions"    )
    feeling_check = models.ForeignKey("FeelingCheck", on_delete=models.SET_NULL, null=True, blank=True, related_name="questionnaire_sessions"    )
    current_step = models.IntegerField(default=1)  # Tracks progress in the questionnaire
    completed = models.BooleanField(default=False)  # Marks when the session is finished
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"QuestionnaireSession for {self.user.username} - Step {self.current_step}"

# Model to track how thw user is feeling
class FeelingCheck(models.Model):
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE, related_name='feeling_checks')
    feeling = models.CharField(
        max_length=20,
        choices=[
            ('good', 'Good'),
            ('okay', 'Okay'),
            ('bad', 'Bad'),
        ]
    )
    timestamp = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user.username} - Feeling {self.feeling} at {self.timestamp.strftime('%d/%m/%Y %H:%M:%S')}"

# Model to store symptoms reported by the user
class SymptomCheck(models.Model):
    session = models.OneToOneField("QuestionnaireSession", on_delete=models.CASCADE, related_name="symptom_check")
    symptoms = models.JSONField()  
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        symptom_summary = ", ".join(f"{k}: {v}" for k, v in self.symptoms.items())
        return f"SymptomCheck for {self.session.user.username} - {symptom_summary}"

# Model to store glucose checks by the user
class GlucoseCheck(models.Model):
    session = models.ForeignKey(QuestionnaireSession, on_delete=models.CASCADE, related_name="glucose_checks")
    glucose_level = models.FloatField()
    target_min = models.FloatField() 
    target_max = models.FloatField()
    timestamp = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        formatted_timestamp = self.timestamp.strftime('%d/%m/%Y %H:%M:%S')
        return f"{self.session.user.username} - {self.glucose_level} at {formatted_timestamp}"

    def evaluate_target(self):
        """
        Evaluates whether the glucose level is higher, lower, or within the range at the time of logging.
        """
        if self.glucose_level < self.target_min:
            return "Lower"
        elif self.glucose_level > self.target_max:
            return "Higher"
        else:
            return "Within Range"

# Model to store diet checks
class MealCheck(models.Model):
    session = models.ForeignKey(QuestionnaireSession, on_delete=models.CASCADE, related_name="diet_checks")
    meal_type = models.CharField(
        max_length=10,
        choices=[
            ('Breakfast', 'Breakfast'),
            ('Lunch', 'Lunch'),
            ('Dinner', 'Dinner'),
            ('Snack', 'Snack'),
        ]
    )
    high_gi_foods = models.ManyToManyField(FoodItem, related_name="meal_checks")
    skipped_meals = models.JSONField(blank=True, default=list)
    wellness_impact = models.BooleanField(default=False)  # Impact on wellness due to diet
    notes = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"DietCheck for {self.session.user.username} - {self.meal_type} ({self.created_at})"

# Model to store exercise checks
class ExerciseCheck(models.Model):
    session = models.ForeignKey(
        QuestionnaireSession, on_delete=models.CASCADE, related_name="exercise_checks"
    )
    last_exercise_time = models.CharField(
        max_length=20,
        choices=[
            ("Today", "Today"),
            ("2-3 Days Ago", "2–3 Days Ago"),
            ("More than 5 Days Ago", "More than 5 Days Ago"),
            ("I Don’t Remember", "I Don’t Remember"),
        ],
    )
    exercise_type = models.CharField(
        max_length=30,
        choices=[
            ("Walking", "Walking"),
            ("Running", "Running"),
            ("Yoga", "Yoga"),
            ("Strength Training", "Strength Training"),
            ("Other", "Other"),
        ],
    )
    exercise_duration = models.PositiveIntegerField()  # Duration in minutes
    post_exercise_feeling = models.CharField(
        max_length=20,
        choices=[
            ("Energised", "Energised"),
            ("Neutral", "Neutral"),
            ("Tired", "Tired"),
        ],
    )
    activity_level_comparison = models.CharField(
        max_length=20,
        choices=[
            ("More", "More"),
            ("Less", "Less"),
            ("About the Same", "About the Same"),
        ],
    )
    activity_prevention_reason = models.CharField(
        max_length=50,
        choices=[
            ("Lack of time", "Lack of time"),
            ("Fatigue", "Fatigue"),
            ("Physical discomfort", "Physical discomfort"),
            ("Other", "Other"),
        ],
        blank=True,
        null=True,
    )
    discomfort_or_fatigue = models.BooleanField(default=False)
    discomfort_description = models.TextField(blank=True, null=True)
    exercise_impact = models.BooleanField(
        blank=True, null=True
    )  # Whether it affects exercise ability
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"ExerciseCheck for {self.session.user.username} ({self.created_at})"


# Model to store questions asked to determine why user if feeling unwell and their response
class FollowUpQuestion(models.Model):
    feeling_check = models.ForeignKey(
        FeelingCheck, on_delete=models.CASCADE, related_name="follow_up_questions"
    )
    question = models.TextField()
    response = models.TextField(blank=True, null=True)

    def __str__(self):
        return f"Follow-up for {self.feeling_check} - {self.question[:30]}..."

# Model to store insights generated based on user activity
class Insight(models.Model):
    user = models.ForeignKey(
        CustomUser, on_delete=models.CASCADE, related_name="insights"
    )
    feeling_check = models.ForeignKey(
        FeelingCheck, on_delete=models.SET_NULL, null=True, blank=True
    )
    insight = models.TextField()
    timestamp = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Insight for {self.user.username} - {self.timestamp.strftime('%d/%m/%Y %H:%M:%S')}"


# Virtual health coach model to provide personalised health guidance
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
