import requests

RXNORM_API_URL = "https://rxnav.nlm.nih.gov/REST/rxcui.json?name={}&search=1"

def fetch_medication_details(med_name):
    """Fetch medication details from RxNorm API."""
    try:
        response = requests.get(RXNORM_API_URL.format(med_name))
        response.raise_for_status()  # Raise exception for HTTP errors
        
        data = response.json()
        rxnorm_ids = data.get("idGroup", {}).get("rxnormId", [])

        if rxnorm_ids:
            return {"name": med_name, "rxnorm_ids": rxnorm_ids}  # Return all IDs
        
        return {"name": med_name, "rxnorm_ids": "Not Found"}
    
    except requests.RequestException as e:
        print(f"RxNorm API Error: {e}")
        return {"name": med_name, "rxnorm_ids": "API Error"}
