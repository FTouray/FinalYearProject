from django.db import models
from django.contrib.auth.models import AbstractUser
from django.db.models import Q
from django.dispatch import receiver
from django.forms import JSONField
from datetime import datetime, timedelta
from django.db.models.signals import post_save

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
    completed = models.BooleanField(default=False)  # Marks when the session is finished
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"QuestionnaireSession for {self.user.username} - {self.created_at.strftime('%Y-%m-%d %H:%M:%S')}"

# Model to track how thw user is feeling
class FeelingCheck(models.Model):
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE, related_name='feeling_checks')
    feeling = models.CharField(
        max_length=20,
        choices=[
            ('bad', 'Bad'),
        ]
    )
    timestamp = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user.username} - Feeling {self.feeling} at {self.timestamp.strftime('%d/%m/%Y %H:%M:%S')}"

# Model to store symptoms reported by the user
class SymptomCheck(models.Model):
    session = models.ForeignKey(QuestionnaireSession, on_delete=models.CASCADE, related_name="symptom_check")
    symptoms = models.JSONField()  
    sleep_hours = models.FloatField(null=True, blank=True)  
    stress = models.BooleanField(null=True, blank=True)
    routine_change = models.CharField(max_length=255, null=True, blank=True)  
    responses = models.JSONField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        symptom_summary = ", ".join(f"{k}: {v}" for k, v in self.symptoms.items())
        return f"SymptomCheck for {self.session.user.username} - {symptom_summary}"

# Model to store glucose checks by the user
class GlucoseCheck(models.Model):
    session = models.ForeignKey(QuestionnaireSession, on_delete=models.CASCADE, related_name="glucose_check")
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
    session = models.ForeignKey(QuestionnaireSession, on_delete=models.CASCADE, related_name="meal_check")
    high_gi_foods = models.ManyToManyField(FoodItem, related_name="meal_check")
    skipped_meals = models.JSONField(blank=True, default=list)
    wellness_impact = models.BooleanField(default=False)  # Impact on wellness due to diet
    notes = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"DietCheck for {self.session.user.username} - {self.created_at.strftime('%Y-%m-%d %H:%M:%S')}"

    @property
    def weighted_gi(self):
        """
        Calculate the weighted glycemic index for the meal.
        Formula: Weighted GI = sum(GI * carbs) / total carbs
        """
        total_carb = sum(food.carbs for food in self.high_gi_foods.all() if food.carbs)
        if total_carb == 0:
            return 0  # Avoid division by zero
        weighted_gi = sum(
            food.glycaemic_index * food.carbs
            for food in self.high_gi_foods.all()
            if food.carbs
        ) / total_carb
        return round(weighted_gi, 2)

# Model to store exercise checks
class ExerciseCheck(models.Model):
    session = models.ForeignKey(QuestionnaireSession, on_delete=models.CASCADE, related_name="exercise_check")
    last_exercise_time = models.CharField(
        max_length=20,
        choices=[
            ("Today", "Today"),
            ("2-3 Days Ago", "2-3 Days Ago"),
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

    exercise_intensity = models.CharField(
        max_length=20,
        choices=[
            ("Low", "Low"),
            ("Moderate", "Moderate"),
            ("Vigorous", "Vigorous"),
        ],
        default="Moderate",
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
class ChatMessage(models.Model):
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE)
    sender = models.CharField(max_length=50, choices=[('user', 'User'), ('assistant', 'Assistant')])
    message = models.TextField()
    timestamp = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user.username} - {self.sender} - {self.timestamp}"

# Model to store user activity data from Health Connect
class FitnessActivity(models.Model):
    ACTIVITY_SOURCES = [
        ("Smartwatch", "Smartwatch"),
        ("Phone", "Phone"),
        ("Manual Entry", "Manual Entry"),
    ]

    SLEEP_STAGES = [
        ("Light Sleep", "Light Sleep"),
        ("Deep Sleep", "Deep Sleep"),
        ("REM Sleep", "REM Sleep"),
        ("Unspecified", "Unspecified"),
    ]
    
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE)
    activity_type = models.CharField(max_length=100)
    source = models.CharField(max_length=20, choices=ACTIVITY_SOURCES, default="Smartwatch")
    start_time = models.DateTimeField()
    end_time = models.DateTimeField()
    duration_minutes = models.FloatField()
    steps = models.IntegerField(null=True, blank=True)
    heart_rate = models.FloatField(null=True, blank=True)
    sleep_stage = models.CharField(max_length=50, choices=SLEEP_STAGES, null=True, blank=True)
    total_sleep_hours = models.FloatField(null=True, blank=True)
    calories_burned = models.FloatField(null=True, blank=True)
    distance_km = models.FloatField(null=True, blank=True)
    is_manual_override = models.BooleanField(default=False)
    is_fallback = models.BooleanField(default=False)

    last_activity_time = models.DateTimeField(null=True, blank=True)  # Last recorded activity time
    last_synced = models.DateTimeField(auto_now=True)  # Timestamp of last sync with Health Connect

    
    class Meta:
        indexes = [
            models.Index(fields=["start_time"]),
        ]
        ordering = ["-start_time"]

    def __str__(self):
        return f"{self.user.username} - {self.activity_type} on {self.start_time.strftime('%Y-%m-%d')}"
    
# Model to store AI-generated insights based on weekly/monthly trends
class AIHealthTrend(models.Model):
    """Stores AI-generated insights based on weekly/monthly trends."""
    
    PERIOD_CHOICES = [("weekly", "Weekly"), ("monthly", "Monthly")]

    user = models.ForeignKey("CustomUser", on_delete=models.CASCADE)
    period_type = models.CharField(max_length=10, choices=PERIOD_CHOICES)
    start_date = models.DateField()  # Start of the period (week/month)
    end_date = models.DateField()  # End of the period
    avg_glucose_level = models.FloatField(null=True, blank=True)
    avg_steps = models.IntegerField(null=True, blank=True)
    avg_sleep_hours = models.FloatField(null=True, blank=True)
    avg_heart_rate = models.FloatField(null=True, blank=True)
    total_exercise_sessions = models.IntegerField(null=True, blank=True)
    ai_summary = models.TextField(null=True, blank=True)  # AI-generated trend analysis

    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user.username} - {self.period_type.capitalize()} ({self.start_date} to {self.end_date})"

    # Model to store ai-generated recommendations based on user fitness and health data
class AIRecommendation(models.Model):
    """Stores AI-generated recommendations based on user fitness and health data."""

    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE, related_name="ai_recommendations")
    generated_at = models.DateTimeField(auto_now_add=True)
    recommendation_text = models.TextField()  # AI-generated advice

    fitness_activities = models.ManyToManyField(FitnessActivity, blank=True)

    # Health-Specific Context
    glucose_level = models.FloatField(null=True, blank=True)  # Latest glucose reading
    glucose_unit = models.CharField(max_length=10, default="mg/dL")  # mg/dL or mmol/L
    context_summary = models.TextField(blank=True, null=True)  # Explanation of AI’s reasoning
    ai_version = models.CharField(max_length=20, default="GPT-4")  # Track AI model version used
    
    health_trend = models.ForeignKey(AIHealthTrend, on_delete=models.SET_NULL, null=True, blank=True)

    class Meta:
        ordering = ["-generated_at"]

    def __str__(self):
        return f"AI Recommendation for {self.user.username} - {self.generated_at.strftime('%Y-%m-%d %H:%M:%S')}"

class LocalNotificationPrompt(models.Model):
    """Stores local notifications for users."""
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE)
    message = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)
    is_sent = models.BooleanField(default=False)  # Mark if sent

    def __str__(self):
        return f"{self.user.username} - {self.message}"

class UserNotification(models.Model):
    """Stores push notifications sent to users."""
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE, related_name="notifications")
    message = models.TextField()
    notification_type = models.CharField(
        max_length=20,
        choices=[
            ("health_alert", "Health Alert"),
            ("reminder", "Reminder"),
            ("motivation", "Motivation"),
        ],
        default="health_alert",
    )
    is_sent = models.BooleanField(default=False)
    timestamp = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user.username} - {self.notification_type} - {self.timestamp}"

# Model to store medication details
class Medication(models.Model):
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE, related_name="medication")
    name = models.CharField(max_length=255)
    fda_id = models.CharField(max_length=100, blank=True, null=True) 
    generic_name = models.CharField(max_length=255, blank=True, null=True)
    dosage = models.CharField(max_length=100, blank=True, null=True)
    frequency = models.CharField(max_length=100, blank=True, null=True)
    last_taken = models.DateTimeField(blank=True, null=True)

    def __str__(self):
        return f"{self.name} ({self.dosage})"

class MedicationReminder(models.Model):
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE)
    medication = models.ForeignKey(Medication, on_delete=models.CASCADE)
    day_of_week = models.IntegerField()  # Monday=1, Tuesday=2, ...
    hour = models.IntegerField(default=0)
    minute = models.IntegerField(default=0)
    repeat_weeks = models.IntegerField(default=4)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Reminder for {self.medication.name} on day={self.day_of_week} at {self.hour}:{self.minute}"

class ForumCategory(models.Model):
    name = models.CharField(max_length=100)
    description = models.TextField(blank=True)

    def __str__(self):
        return self.name

class ForumThread(models.Model):
    category = models.ForeignKey(ForumCategory, on_delete=models.CASCADE, related_name='threads')
    title = models.CharField(max_length=200)
    created_by = models.ForeignKey(CustomUser, on_delete=models.CASCADE)
    created_at = models.DateTimeField(auto_now_add=True)

    def latest_reply(self):
        return self.comments.order_by("-created_at").first()

    def comment_count(self):
        return self.comments.count()

    def __str__(self):
        return self.title

class Comment(models.Model):
    thread = models.ForeignKey(ForumThread, on_delete=models.CASCADE, related_name='comments')
    author = models.ForeignKey(CustomUser, on_delete=models.CASCADE)
    content = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.author.username}: {self.content[:30]}"

class PersonalInsight(models.Model):
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE, related_name="personal_insights")
    summary_text = models.TextField()  # Full AI summary (formatted)
    raw_data = models.JSONField(blank=True, null=True)  # Raw values used to generate the summary
    generated_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user.username} - {self.generated_at.strftime('%Y-%m-%d %H:%M:%S')}"
    
class QuizSet(models.Model):
    title = models.CharField(max_length=100)
    description = models.TextField()
    related_topic = models.CharField(max_length=100)  
    level = models.PositiveIntegerField(unique=True)

    def __str__(self):
        return f"{self.title} (Level {self.level})"


class Quiz(models.Model):
    quiz_set = models.ForeignKey(QuizSet, on_delete=models.CASCADE)
    question = models.TextField()
    correct_answer = models.CharField(max_length=255)
    wrong_answers = models.JSONField()

class UserProgress(models.Model):
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE)
    quiz_set = models.ForeignKey(QuizSet, on_delete=models.CASCADE)
    score = models.FloatField()
    completed = models.BooleanField(default=False)
    badge_awarded = models.BooleanField(default=False)
    xp_earned = models.PositiveIntegerField(default=0)


class Achievement(models.Model):
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE)
    badge_name = models.CharField(max_length=100)
    points = models.IntegerField(default=0)
    awarded_at = models.DateTimeField(auto_now_add=True)


class UserProfile(models.Model):
    user = models.OneToOneField(CustomUser, on_delete=models.CASCADE)
    xp = models.PositiveIntegerField(default=0)
    level = models.PositiveIntegerField(default=1)

    def update_xp_and_level(self, earned_xp):
        self.xp += earned_xp
        self.level = (self.xp // 500) + 1 
        self.save()
        
class QuizAttempt(models.Model):
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE)
    quiz_set = models.ForeignKey(QuizSet, on_delete=models.CASCADE)
    score = models.FloatField()
    xp_earned = models.PositiveIntegerField()
    attempted_at = models.DateTimeField(auto_now_add=True)
    review = models.JSONField(default=list)
        
@receiver(post_save, sender=CustomUser)
def create_user_profile(sender, instance, created, **kwargs):
    if created:
        UserProfile.objects.create(user=instance)


@receiver(post_save, sender=CustomUser)
def save_user_profile(sender, instance, **kwargs):
    instance.userprofile.save()
    
class PredictiveFeedback(models.Model):
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE, related_name="predictive_feedback")
    insight = models.TextField()  # The actual feedback/explanation string
    timestamp = models.DateTimeField(auto_now_add=True)
    model_version = models.CharField(max_length=50, default="v1.0")
    feedback_type = models.CharField(max_length=20, choices=[
    ('shap', 'SHAP-based'),
    ('trend', 'Trend-based'),
    ('improvement', 'Improvement'),
])

    def __str__(self):
        return f"{self.user.username} - {self.timestamp.strftime('%Y-%m-%d %H:%M')}"