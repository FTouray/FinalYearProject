import cv2
import pytesseract
import re

def extract_text_from_image(image_path):
    """Extract text from a medication label using OCR."""
    try:
        image = cv2.imread(image_path)
        if image is None:
            raise ValueError("Invalid image path or corrupted image file.")

        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        text = pytesseract.image_to_string(gray)
        return text.strip() if text.strip() else "No text detected"
    
    except Exception as e:
        print(f"OCR Error: {e}")
        return "OCR failed"

def parse_dosage_info(text):
    """Extracts dosage and frequency patterns from scanned text."""
    dosage = re.search(r"\d+\s?mg", text, re.IGNORECASE)
    frequency = re.search(r"(once|twice|three times|daily|every \d+ hours)", text, re.IGNORECASE)
    return {
        "dosage": dosage.group(0) if dosage else None,
        "frequency": frequency.group(0) if frequency else None
    }


