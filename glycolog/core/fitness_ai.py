from datetime import datetime, timedelta, timezone
from django.utils.timezone import now, localtime
from django.db.models import Avg, Sum, Count
from openai import OpenAI
from core.models import AIHealthTrend, FitnessActivity, CustomUser, GlucoseCheck, GlucoseLog
from django.db.models import Q
import re



client = OpenAI()

def generate_ai_recommendation(user, fitness_activities):
    """
    Generates AI-based health recommendations using OpenAI GPT.
    Supports **individual** user insights based on recent workouts.
    """
    fitness_activities = [
        a for a in fitness_activities if not getattr(a, "is_fallback", False)
    ]

    if not fitness_activities:
        fitness_summary = "No recent fitness data available."
    else:
        fitness_summary = "\n".join(
            f"- {activity.activity_type} for {activity.duration_minutes:.0f} mins on {activity.start_time.strftime('%Y-%m-%d')}"
            for activity in fitness_activities
        )
    prompt = f"""
    The user has diabetes and their recent health activities are:

    {fitness_summary}

    Based on this data:
    - Suggest improvements to their fitness routine.
    - Provide personalized exercise recommendations.
    - Ensure all recommendations are diabetes-friendly and promote glucose stability.

    Return in bullet-point format.
    """

    response = client.chat.completions.create(
        model="gpt-3.5-turbo",
        messages=[
            {"role": "system", "content": "You are an AI fitness coach specializing in diabetic health advice."},
            {"role": "user", "content": prompt},
        ],
    )

    return response.choices[0].message.content

def generate_health_trends(user, period_type="weekly"):
    """
    Generates user-specific health trends and AI insights.
    - Includes fallback data ONLY for sleep
    - Excludes fallback fitness records
    - Aggregates glucose from GlucoseLog and GlucoseCheck
    """
    if not user:
        raise ValueError("User is required for trend generation.")

    end_date = now().date()
    start_date = end_date - timedelta(days=7 if period_type == "weekly" else 30)
    print(f"Generating trends for: {user.username}")
    print(f"Period: {start_date} to {end_date}")

    # 🏃 Fitness data
    activities = FitnessActivity.objects.filter(
        user=user,
        start_time__date__range=[start_date, end_date]
    )
    print(f"Total activities found: {activities.count()}")

    sleep_activities = activities.filter(Q(activity_type__iexact="sleep") | Q(activity_type__iexact="sleeping"))
    print(f"Sleep-related activities: {sleep_activities.count()}")

    valid_activities = activities.exclude(Q(activity_type__iexact="sleep") | Q(is_fallback=True))
    print(f"Valid non-sleep activities (excluding fallback): {valid_activities.count()}")
    for activity in valid_activities:
        print(f" - {activity.activity_type} | {activity.start_time} | Steps: {activity.steps}, HR: {activity.heart_rate}")

    # 🧮 Aggregates
    avg_steps = valid_activities.aggregate(Sum("steps"))["steps__sum"] or 0
    avg_hr = valid_activities.aggregate(Avg("heart_rate"))["heart_rate__avg"]
    # avg_sleep = sleep_activities.aggregate(Avg("total_sleep_hours"))["total_sleep_hours__avg"] or 0
    total_sessions = valid_activities.count()

    print(f"Avg Steps: {avg_steps}")
    print(f"Avg Heart Rate: {avg_hr}")
    # print(f"Avg Sleep: {avg_sleep}")
    print(f"Total Exercise Sessions: {total_sessions}")

    # 🩸 Glucose
    log_glucose = GlucoseLog.objects.filter(
    user=user,
    timestamp__range=[
        datetime.combine(start_date, datetime.min.time(), tzinfo=timezone.utc),
        datetime.combine(end_date, datetime.max.time(), tzinfo=timezone.utc)
    ]
    ).values_list("glucose_level", flat=True)

    check_glucose = GlucoseCheck.objects.filter(
        session__user=user,
        timestamp__range=[
            datetime.combine(start_date, datetime.min.time(), tzinfo=timezone.utc),
            datetime.combine(end_date, datetime.max.time(), tzinfo=timezone.utc)
        ]
    ).values_list("glucose_level", flat=True)

    all_glucose = [g for g in (list(log_glucose) + list(check_glucose)) if g is not None]
    avg_glucose = (
        sum(all_glucose) / len(all_glucose)
        if all_glucose else None
    )
    print(f"Glucose entries: {len(all_glucose)}")
    print(f"Avg Glucose: {avg_glucose}")

    # 🤖 Prompt
    trend_prompt = f"""
    The user has diabetes. Below are their {period_type} health trends:

    - Total Steps: {avg_steps}
    - Average Heart Rate: {avg_hr or 'N/A'} bpm
    - Average Glucose: {avg_glucose or 'N/A'} mg/dL
    - Total Exercise Sessions: {total_sessions}

    Please provide:
    - Insights on activity, rest, and cardiovascular trends
    - Diabetes-specific analysis of glucose trends
    - Personalized, safe fitness & wellness recommendations

    Return your output in bullet point format. **Add a priority score from 1 to 3 for each bullet** based on urgency or importance:
    - 3 = Must address soon
    - 2 = Important but not critical
    - 1 = Good to know or long-term

    Format each bullet like:
    [3] Try to walk 5,000+ steps daily to maintain glucose stability.
    """
    print("Sending prompt to GPT...")

    response = client.chat.completions.create(
        model="gpt-4",
        messages=[
            {"role": "system", "content": "You are an AI fitness coach for people managing diabetes."},
            {"role": "user", "content": trend_prompt},
        ],
    )

    summary = response.choices[0].message.content.strip()
    parsed_summary = parse_ai_summary_with_scores(summary)
    print("AI Summary:")
    print(summary)

    # Save trend
    AIHealthTrend.objects.update_or_create(
        user=user,
        period_type=period_type,
        start_date=start_date,
        end_date=end_date,
        defaults={
            "avg_steps": avg_steps,
            # "avg_sleep_hours": avg_sleep,
            "avg_heart_rate": avg_hr,
            "avg_glucose_level": avg_glucose,
            "total_exercise_sessions": total_sessions,
            "ai_summary": summary,
            "ai_summary_items": parsed_summary,
        },
    )

    print("Trend saved.\n")
    return summary

def parse_ai_summary_with_scores(summary_text):
    pattern = r"\[(\d+)\]\s+(.*)"
    parsed = re.findall(pattern, summary_text)
    return [
        {"score": int(score), "text": text.strip()}
        for score, text in parsed
    ]

def generate_system_wide_health_trends():
    return generate_health_trends(user=None, period_type="weekly"), generate_health_trends(user=None, period_type="monthly")


def generate_individual_health_trends():
    for user in CustomUser.objects.all():
        generate_health_trends(user=user, period_type="weekly")
        generate_health_trends(user=user, period_type="monthly")
