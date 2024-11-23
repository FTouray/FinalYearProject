# glycolog_flutter

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## SERVER
cd "C:\Users\ftour\OneDrive - Technological University Dublin\4th Year\FYP\glycologapp\glycolog"
python manage.py runserver 0.0.0.0:8000

## FRONTEND
cd "C:\Users\ftour\OneDrive - Technological University Dublin\4th Year\FYP\glycologapp\glycolog_flutter"
flutter run


## Maybe move to services/auth_service.dart
- auth_service
- login(String username, String password): Handles user login and token storage.
- *logout(): Clears tokens from storage.
- isLoggedIn(): Checks if the user is currently authenticated.
- getUserDetails(): Fetches details of the currently logged-in user.
- updateUserProfile(Map<String, dynamic> profileData): Updates user profile information.

## TOKEN
- Have a look at token refresh - when restart the app still logged in -**

## FORMAT TIMESTAMP

## Login
- Forgot Password
- Password Validation

## Register
- Email and Password Validation

## Homepage
- When you go from homepage to other page and back to homepage users first name doesn't appear and it defaults to user

## Glucose Log
- *Validation for if they have no previous log 
- *Frontend 
- *Measurement unit - can't enter 300 if using mmol/L 
- Filter Not Working - glucose level and remove filter

*Graph*
- *Label Axis 
- *Change the y-axis to display more hours 
- *Graph for GL Today 
- *Round to 1 or 2 Decimal Points 
- Match the y-axis glucose levels to the grid

# GRT

- Error Handling in calculate_totals
- Meal Selection Counter doesn't update immediately when an item is removed from the confirmation screen and they navigate back to meal selection screen
- Celery and Redis - Automate the process of updating the database with new food items from the website

1. GRT Analysis Screen
Purpose: Provides visual insights into logged data, such as trends in glucose levels and food response patterns.
Reason for Priority: Once users have enough logged data, this screen can start generating insights, empowering users with meaningful feedback on their habits.
1. GRT Food Database Screen
Purpose: Allows users to explore available foods, view glycaemic index details, and easily add items to their meal logs.
Reason for Priority: This feature enhances the ease of meal logging by providing a convenient database of foods, giving users a streamlined way to add information to their logs.
1. GRT Alerts and Notifications Screen
Purpose: Allows users to set thresholds for blood glucose levels and customize notification settings.
Reason for Priority: This screen offers helpful reminders and alerts, which are valuable for adherence but can be built after core logging and analysis features are functional.
1. GRT Meal Recommendation Screen
Purpose: Suggests alternative food options based on logged responses to help users make healthier choices.
Reason for Priority: Recommendation features can be added later as they depend on logged data and analysis insights to provide valuable suggestions.
1. GRT Personalization and Settings Screen
Purpose: Enables customization, like setting glycaemic thresholds and dietary preferences.
Reason for Priority: Tailoring the app for each user is valuable but can come after core features, as it enhances the experience rather than forming its basis.
1. GRT Data Export Screen
Purpose: Lets users export their data for personal use or to share with healthcare providers.
Reason for Priority: Data export is useful for users wanting to take their data outside the app but is generally less essential for in-app functionality and can be developed last.

Step 3: Implement Glycaemic Response Analysis in Backend
Once logging is functional, you can start developing the response analysis feature. Initially, you could implement a simplified analysis to provide users with basic insights based on logged meals.

Data Analysis Logic: Write a function to analyze trends in glucose data relative to meals. For instance, check if specific foods consistently lead to higher glucose spikes.
Insights Generation: Generate basic recommendations or warnings based on trends (e.g., "Consider reducing high-GI foods like bread to manage glucose spikes.").
You can implement this analysis as a Django management command or an API endpoint that processes logged data and returns insights.

Step 4: Integrate Glycaemic Response Tracker Insights in the Frontend
Once you have insights generated on the backend, display these insights in the Flutter app.

Insights UI: Design a page or section that shows users how specific foods or meal times affect their glucose levels.
Data Visualization (Optional): Add graphs or visualizations to make data trends clear (e.g., using fl_chart for displaying response trends over time).
