import re
from collections import Counter
from textblob import TextBlob

def extract_common_words(notes_list):
    """ Extracts common words from user notes, filtering out filler words. """
    text = " ".join(notes_list).lower()
    words = re.findall(r'\b[a-zA-Z]{3,}\b', text)  # Extract words (min 3 letters)

    # **Expanded Stopwords List**
    stopwords = {
        "the", "and", "you", "your", "with", "for", "are", "this", "was", "that",
        "but", "have", "from", "they", "i", "me", "my", "mine", "we", "our", "ours",
        "he", "his", "him", "she", "her", "hers", "it", "its", "a", "an", "in",
        "to", "on", "of", "at", "as", "so", "is", "be", "been", "being", "by",
        "am", "was", "were", "do", "does", "did", "has", "had", "will", "can",
        "could", "would", "should", "if", "then", "or", "not", "just", "like",
        "really", "very", "some", "many", "much", "thing", "things"
    }

    # **Filter words**
    filtered_words = [word for word in words if word not in stopwords]

    # **Find top 5 most common words**
    common_words = Counter(filtered_words).most_common(5)
    return [word for word, count in common_words]

def analyze_sentiment(notes_list):
    """ Detects emotional tone in user notes using TextBlob. """
    all_text = " ".join(notes_list)
    sentiment_score = TextBlob(all_text).sentiment.polarity  # Score: -1 (negative) to 1 (positive)

    if sentiment_score < -0.2:
        return "Frustration or Negative Sentiment"
    elif sentiment_score > 0.2:
        return "Positive or Neutral"
    else:
        return "Confusion or Unclear Information"

def detect_extra_information(notes_list):
    """ Extracts structured insights from user notes, such as portion sizes, skipped meals, and routine changes. """
    extracted_info = []

    portion_keywords = ["portion", "serving", "plate", "bowls", "cups"]
    meal_keywords = ["breakfast", "lunch", "dinner", "snack", "meal"]
    routine_keywords = ["work schedule", "sleep", "diet", "exercise", "changed"]

    for note in notes_list:
        words = note.lower().split()

        # **Detect Portion Sizes (e.g., "Had 2 portions of rice")**
        for i, word in enumerate(words):
            if word in portion_keywords and i > 0 and words[i-1].isdigit():
                extracted_info.append(f"Portion size: {words[i-1]} {word}")

        # **Detect Meal Skipping (e.g., "Skipped breakfast")**
        for word in words:
            if word in meal_keywords and ("skip" in words or "missed" in words):
                extracted_info.append(f"Skipped meal: {word}")

        # **Detect Routine Changes (e.g., "Changed my workout routine")**
        for word in words:
            if word in routine_keywords:
                extracted_info.append(f"Routine change detected: {word}")

    return extracted_info

def detect_critical_symptoms(notes_list):
    """ Detects serious health concerns from user notes. """
    critical_keywords = ["blurred vision", "faint", "weak", "dizzy", "nausea", "shaking"]
    concerns = [note for note in notes_list if any(word in note.lower() for word in critical_keywords)]
    return concerns if concerns else None

