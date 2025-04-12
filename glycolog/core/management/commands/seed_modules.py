from django.core.management.base import BaseCommand
from core.models import QuizSet, Quiz

class Command(BaseCommand):
    help = 'Seeds the database with quiz sets and related quizzes.'

    def handle(self, *args, **kwargs):
        sets = [
            {
                "level": 1,
                "title": "Understanding Glucose",
                "description": "Learn what glucose is, how it affects your body, and how to manage it.",
                "related_topic": "Glucose Monitoring",
                "quizzes": [
                    {"question": "What is glucose?", "correct": "A type of sugar in the blood", "wrong": ["A protein in muscles", "A brain chemical", "A type of fat"]},
                    {"question": "Which organ produces insulin?", "correct": "Pancreas", "wrong": ["Liver", "Heart", "Kidney"]},
                    {"question": "High blood glucose is also known as:", "correct": "Hyperglycemia", "wrong": ["Hypoglycemia", "Anemia", "Hypertension"]},
                    {"question": "What is a normal fasting glucose level?", "correct": "70–99 mg/dL", "wrong": ["100–120 mg/dL", "50–60 mg/dL", "140–160 mg/dL"]},
                    {"question": "What tool is used to measure blood sugar at home?", "correct": "Glucometer", "wrong": ["Thermometer", "Sphygmomanometer", "Scale"]},
                    {"question": "What is a spike in glucose levels often caused by?", "correct": "Eating sugary foods", "wrong": ["Drinking water", "Sleeping", "Stretching"]},
                    {"question": "Low blood glucose is called:", "correct": "Hypoglycemia", "wrong": ["Hypertension", "Anxiety", "Anemia"]},
                    {"question": "Which time is best for glucose monitoring?", "correct": "Before and after meals", "wrong": ["Only at night", "Once a week", "Every hour"]},
                    {"question": "A1C measures your average glucose over:", "correct": "3 months", "wrong": ["1 day", "1 week", "1 year"]},
                    {"question": "Which is a symptom of high blood sugar?", "correct": "Excessive thirst", "wrong": ["Chills", "Hiccups", "Sneezing"]},
                ]
            },
            {
                "level": 2,
                "title": "Smart Nutrition",
                "description": "Master food labels, carb counting, and healthy meals.",
                "related_topic": "Meal Planning",
                "quizzes": [
                    {"question": "Which of these is a complex carbohydrate?", "correct": "Oatmeal", "wrong": ["Candy", "Soda", "Cake"]},
                    {"question": "Fiber is important because it:", "correct": "Slows sugar absorption", "wrong": ["Raises cholesterol", "Increases sugar", "Has no effect"]},
                    {"question": "What is the first thing to check on a nutrition label?", "correct": "Serving size", "wrong": ["Calories", "Sugar", "Color"]},
                    {"question": "What does GI stand for in food science?", "correct": "Glycemic Index", "wrong": ["General Intake", "Grain Intake", "Glyco Info"]},
                    {"question": "Which meal is diabetes-friendly?", "correct": "Grilled chicken and quinoa", "wrong": ["Fried rice and soda", "Burger and fries", "Pizza"]},
                    {"question": "Which fat should be limited?", "correct": "Saturated fat", "wrong": ["Unsaturated fat", "Omega-3", "Healthy fat"]},
                    {"question": "Which is a good source of fiber?", "correct": "Lentils", "wrong": ["White bread", "Soda", "Ice cream"]},
                    {"question": "Carbs turn into what in your body?", "correct": "Glucose", "wrong": ["Protein", "Fat", "Iron"]},
                    {"question": "Too much added sugar can cause:", "correct": "Blood sugar spikes", "wrong": ["Stronger bones", "Hair growth", "Improved sleep"]},
                    {"question": "Water helps to:", "correct": "Flush out excess sugar", "wrong": ["Raise sugar levels", "Store insulin", "Slow metabolism"]},
                ]
            },
            {
                "level": 3,
                "title": "Active Living",
                "description": "Discover how physical activity affects diabetes.",
                "related_topic": "Exercise",
                "quizzes": [
                    {"question": "Which activity lowers blood sugar?", "correct": "Jogging", "wrong": ["Sleeping", "Eating", "Watching TV"]},
                    {"question": "Exercise helps to:", "correct": "Increase insulin sensitivity", "wrong": ["Block insulin", "Store sugar", "Build toxins"]},
                    {"question": "How often should you be active?", "correct": "Most days", "wrong": ["Once a week", "Rarely", "Only Sundays"]},
                    {"question": "What’s a good warm-up?", "correct": "Stretching", "wrong": ["Jumping into sprint", "Nothing", "Eating"]},
                    {"question": "Strength training helps to:", "correct": "Build muscle and burn glucose", "wrong": ["Build fat", "Reduce sleep", "Increase sugar"]},
                    {"question": "Low blood sugar after a workout is called:", "correct": "Exercise-induced hypoglycemia", "wrong": ["Fatigue", "Sugar crash", "Sleepiness"]},
                    {"question": "What should you carry during long exercise?", "correct": "Fast-acting sugar", "wrong": ["Chips", "Insulin", "Sunscreen"]},
                    {"question": "When is the best time to exercise?", "correct": "After meals", "wrong": ["While sleeping", "Right before insulin", "Midnight"]},
                    {"question": "Which of these is a low-impact exercise?", "correct": "Walking", "wrong": ["Jump rope", "Deadlifts", "Sprint training"]},
                    {"question": "Hydration during exercise is:", "correct": "Essential", "wrong": ["Optional", "Not needed", "Harmful"]},
                ]
            },
            {
                "level": 4,
                "title": "Medication Know-How",
                "description": "Understand how medications and insulin help manage diabetes.",
                "related_topic": "Medication",
                "quizzes": [
                    {"question": "Which is a diabetes medication?", "correct": "Metformin", "wrong": ["Paracetamol", "Ibuprofen", "Aspirin"]},
                    {"question": "Insulin is usually given via:", "correct": "Injection", "wrong": ["Oral pill", "Patch", "Cream"]},
                    {"question": "What should be checked before insulin use?", "correct": "Expiration date", "wrong": ["Brand", "Color", "Bottle cap"]},
                    {"question": "What does basal insulin do?", "correct": "Maintains blood sugar at rest", "wrong": ["Spikes insulin", "Reduces hunger", "Improves muscle"]},
                    {"question": "What time is best for long-acting insulin?", "correct": "Bedtime", "wrong": ["Afternoon", "Lunch", "Random"]},
                    {"question": "Skipping insulin doses causes:", "correct": "Hyperglycemia", "wrong": ["Muscle gain", "Healing", "Hair loss"]},
                    {"question": "Side effect of insulin?", "correct": "Low blood sugar", "wrong": ["High BP", "High pulse", "High calcium"]},
                    {"question": "Pills for diabetes are often used in:", "correct": "Type 2", "wrong": ["Type 1", "Gestational", "Hypoglycemia"]},
                    {"question": "Medication adherence means:", "correct": "Taking meds as prescribed", "wrong": ["Avoiding side effects", "Taking when needed", "Guessing doses"]},
                    {"question": "Too much insulin causes:", "correct": "Hypoglycemia", "wrong": ["Strong bones", "Increased hunger", "Faster heart"]},
                ]
            },
            {
                "level": 5,
                "title": "Preventing Complications",
                "description": "Learn how to protect yourself from long-term effects of diabetes.",
                "related_topic": "Complications",
                "quizzes": [
                    {"question": "What can long-term high sugar damage?", "correct": "Nerves", "wrong": ["Hair", "Eyes only", "Muscle"]},
                    {"question": "Which is a diabetes complication?", "correct": "Kidney disease", "wrong": ["Cold", "Sore throat", "Cough"]},
                    {"question": "Which exam checks eye health?", "correct": "Retina scan", "wrong": ["X-ray", "Ultrasound", "Ear test"]},
                    {"question": "Why are foot checks important?", "correct": "Nerve damage risk", "wrong": ["Fashion", "Exercise", "Pain relief"]},
                    {"question": "Preventing complications includes:", "correct": "Glucose control & regular checkups", "wrong": ["Skipping breakfast", "Avoiding meds", "Staying up late"]},
                    {"question": "Which vitamin helps eyes?", "correct": "Vitamin A", "wrong": ["Vitamin B", "Iron", "Calcium"]},
                    {"question": "Smoking with diabetes increases:", "correct": "Complications risk", "wrong": ["Insulin", "Energy", "Muscle"]},
                    {"question": "What helps reduce foot ulcers?", "correct": "Daily inspection", "wrong": ["Wearing tight shoes", "Skipping care", "Foot scrubbing"]},
                    {"question": "Chronic high blood sugar leads to:", "correct": "Organ damage", "wrong": ["Muscle gain", "Weight loss", "Happiness"]},
                    {"question": "Which lab test shows kidney function?", "correct": "Creatinine", "wrong": ["Cholesterol", "Bilirubin", "Hemoglobin"]},
                ]
            },
            {
                "level": 6,
                "title": "Living Well with Diabetes",
                "description": "Daily routines and lifestyle changes that support your diabetes journey.",
                "related_topic": "Lifestyle",
                "quizzes": [
                    {"question": "Why is sleep important for diabetes?", "correct": "It helps regulate blood sugar levels", "wrong": ["It builds muscle", "It increases cravings", "It has no effect"]},
                    {"question": "Which habit can help prevent spikes in blood sugar?", "correct": "Eating regularly spaced meals", "wrong": ["Skipping breakfast", "Snacking all day", "Eating large meals"]},
                    {"question": "How can stress affect blood glucose?", "correct": "It can cause levels to rise", "wrong": ["It always lowers levels", "It makes no difference", "It reduces hunger"]},
                    {"question": "Which practice supports mental well-being in diabetes care?", "correct": "Mindfulness or meditation", "wrong": ["Overworking", "Avoiding meals", "Skipping rest"]},
                    {"question": "What is a good way to stay on track with diabetes care?", "correct": "Keep a daily health journal", "wrong": ["Avoid talking about it", "Only track during check-ups", "Ignore small changes"]},
                    {"question": "How does alcohol affect diabetes?", "correct": "It can cause blood sugar to rise or fall unpredictably", "wrong": ["It cures symptoms", "It always raises levels", "It helps insulin work"]},
                    {"question": "What is one benefit of a routine sleep schedule?", "correct": "Better blood sugar control", "wrong": ["Weaker appetite", "Faster digestion", "None"]},
                    {"question": "When is it best to schedule meals?", "correct": "At consistent times each day", "wrong": ["Randomly throughout the day", "After exercise only", "Whenever convenient"]},
                    {"question": "What is a sign of stress affecting diabetes?", "correct": "Unexplained blood sugar spikes", "wrong": ["Hiccups", "Itchy skin", "Mild headaches"]},
                    {"question": "Which tool helps manage emotions and behaviour?", "correct": "CBT (Cognitive Behavioural Therapy)", "wrong": ["High sugar snacks", "Watching TV", "Ignoring it"]},
                ]
            },
            {
                "level": 7,
                "title": "Diabetes in Daily Life",
                "description": "Explore how diabetes affects everyday choices, from shopping to socialising.",
                "related_topic": "Daily Management",
                "quizzes": [
                    {"question": "What should you look for when buying snacks?", "correct": "Low sugar, high fibre", "wrong": ["High sugar", "High fat", "Extra salt"]},
                    {"question": "How can you manage diabetes at work?", "correct": "Pack balanced meals and check sugar levels", "wrong": ["Skip lunch", "Drink energy drinks", "Avoid breaks"]},
                    {"question": "What is a good approach to dining out?", "correct": "Plan ahead and check menus", "wrong": ["Order randomly", "Skip food", "Only drink water"]},
                    {"question": "Which item is helpful during travel?", "correct": "Glucose tablets or snacks", "wrong": ["Sweets", "Coffee", "Bread"]},
                    {"question": "How should medication be stored on the go?", "correct": "In a cool, labelled container", "wrong": ["In a hot car", "Loose in bag", "Unlabelled box"]},
                    {"question": "What social situation might affect blood sugar?", "correct": "Drinking alcohol", "wrong": ["Chatting", "Listening to music", "Watching TV"]},
                    {"question": "What does planning your shopping list help with?", "correct": "Avoiding unhealthy food choices", "wrong": ["Saving money only", "Buying in bulk", "Choosing quickly"]},
                    {"question": "What’s a helpful app feature for diabetes?", "correct": "Meal and glucose logging", "wrong": ["Games only", "Video playback", "Weather tracking"]},
                    {"question": "How should you handle blood sugar lows socially?", "correct": "Carry fast-acting sugar and inform friends", "wrong": ["Ignore it", "Hide it", "Drink alcohol"]},
                    {"question": "What can help you prepare for the day ahead?", "correct": "Meal prep and activity planning", "wrong": ["Avoiding food", "Sleeping late", "Skipping meds"]},
                ]
            },
            {
                "level": 8,
                "title": "Family & Support",
                "description": "Involve family and friends in your care and create a supportive environment.",
                "related_topic": "Community",
                "quizzes": [
                    {"question": "Why is involving family in diabetes care helpful?", "correct": "They can support daily routines", "wrong": ["They can fix it", "They do the work", "They monitor insulin"]},
                    {"question": "What should you teach your support circle?", "correct": "Signs of high and low blood sugar", "wrong": ["How to use the app", "Your favourite foods", "Your sleep time"]},
                    {"question": "How can family help in emergencies?", "correct": "Know how to use glucagon or call for help", "wrong": ["Hide it", "Panic", "Give sweets"]},
                    {"question": "What is a benefit of peer support groups?", "correct": "Sharing experiences and advice", "wrong": ["Getting free insulin", "No benefit", "Creating drama"]},
                    {"question": "How can kids support diabetic parents?", "correct": "Help with reminders and healthy meals", "wrong": ["Cook alone", "Skip meds", "Argue"]},
                    {"question": "What helps create a supportive home?", "correct": "Open conversations and shared goals", "wrong": ["Ignore issues", "Blame others", "Avoid help"]},
                    {"question": "How often should check-ins happen with carers?", "correct": "Weekly or as needed", "wrong": ["Yearly", "Only if sick", "Rarely"]},
                    {"question": "Who can be part of your support network?", "correct": "Family, friends, and healthcare professionals", "wrong": ["Only your doctor", "Only online groups", "Just neighbours"]},
                    {"question": "What should a support plan include?", "correct": "Emergency contacts and medication list", "wrong": ["Birthday reminders", "Social media", "Playlists"]},
                    {"question": "Support from others improves:", "correct": "Self-management and motivation", "wrong": ["Insulin production", "Genetics", "Sugar cravings"]},
                ]
            },
            {
                "level": 9,
                "title": "Tech & Tools",
                "description": "Explore modern tools like CGMs, apps, and smart devices for diabetes.",
                "related_topic": "Technology",
                "quizzes": [
                    {"question": "What does CGM stand for?", "correct": "Continuous Glucose Monitor", "wrong": ["Cardiac Gear Monitor", "Carbohydrate Gauge Monitor", "Cyclic Glucose Meter"]},
                    {"question": "Which app feature is most useful?", "correct": "Glucose tracking", "wrong": ["Game scores", "Camera filters", "Music library"]},
                    {"question": "Why is cloud syncing useful?", "correct": "It allows remote data sharing", "wrong": ["Slows down devices", "Increases glucose", "Shows ads"]},
                    {"question": "What device syncs with a fitness tracker?", "correct": "Smartphone", "wrong": ["TV", "Radio", "Oven"]},
                    {"question": "What is a benefit of smart insulin pens?", "correct": "They track doses automatically", "wrong": ["They play music", "They glow in dark", "They need charging"]},
                    {"question": "Which tool can reduce finger pricks?", "correct": "CGM", "wrong": ["Watch", "Headphones", "Weighing scale"]},
                    {"question": "Why is Bluetooth helpful?", "correct": "Connects health devices easily", "wrong": ["Plays music", "Watches TV", "Prints reports"]},
                    {"question": "How often should devices be calibrated?", "correct": "As recommended by manufacturer", "wrong": ["Never", "Once a year", "Randomly"]},
                    {"question": "What helps with meal insights?", "correct": "Photo logging meals", "wrong": ["Hiding snacks", "Counting calories only", "Guessing meals"]},
                    {"question": "Apps with reminders help by:", "correct": "Reducing missed doses", "wrong": ["Sending memes", "Sharing selfies", "Playing videos"]},
                ]
            },
            {
                "level": 10,
                "title": "Healthy Habits",
                "description": "Build habits around sleep, stress, and daily routines for long-term success.",
                "related_topic": "Wellbeing",
                "quizzes": [
                    {"question": "What is a good bedtime habit?", "correct": "Turning off screens before bed", "wrong": ["Watching TV", "Eating sugar", "Drinking coffee"]},
                    {"question": "What helps reduce stress?", "correct": "Deep breathing", "wrong": ["Yelling", "Skipping meals", "Fasting"]},
                    {"question": "A habit tracker helps to:", "correct": "Stay consistent with goals", "wrong": ["Track weight only", "Count steps", "Skip routines"]},
                    {"question": "What time should you wake up daily?", "correct": "At a consistent time", "wrong": ["Whenever", "When tired", "Only on work days"]},
                    {"question": "Why should you plan meals?", "correct": "Avoid unhealthy choices", "wrong": ["Spend more", "Eat late", "Lose appetite"]},
                    {"question": "How much water should you drink daily?", "correct": "Around 1.5 to 2 litres", "wrong": ["None", "5 litres", "Only with meals"]},
                    {"question": "What helps with mood swings?", "correct": "Balanced blood sugar", "wrong": ["Extra sugar", "Caffeine", "Skipping meals"]},
                    {"question": "Daily exercise helps with:", "correct": "Stabilising glucose", "wrong": ["Burning protein", "Building fat", "Staying still"]},
                    {"question": "A consistent routine supports:", "correct": "Better glucose management", "wrong": ["High sugar", "Mental stress", "Poor sleep"]},
                    {"question": "How can you create new habits?", "correct": "Start small and build up", "wrong": ["Do everything at once", "Skip days", "Wait for motivation"]},
                ]
            }
        ]

        for s in sets:
            quiz_set, _ = QuizSet.objects.get_or_create(
                level=s["level"],
                defaults={"title": s["title"], "description": s["description"], "related_topic": s["related_topic"]}
            )
            for quiz in s["quizzes"]:
                Quiz.objects.get_or_create(
                    quiz_set=quiz_set,
                    question=quiz["question"],
                    defaults={
                        "correct_answer": quiz["correct"],
                        "wrong_answers": quiz["wrong"]
                    }
                )

        self.stdout.write(self.style.SUCCESS("✅ Seeded 10 topic-based quiz sets with 10 questions each."))
