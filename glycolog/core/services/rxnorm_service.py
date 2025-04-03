import requests
import re

BASE_RXNORM_URL = "https://rxnav.nlm.nih.gov/REST"
RXNORM_API_URL = "https://rxnav.nlm.nih.gov/REST" 

def search_rxnorm(query: str):
    """
    Searches RxNorm by medication name (approximate match).
    Returns a list of dicts, each containing 'name' and 'rxcui'.
    """
    endpoint = f"{BASE_RXNORM_URL}/drugs.json"
    params = {"name": query}
    try:
        response = requests.get(endpoint, params=params)
        response.raise_for_status()
        data = response.json()
        
        results = []
        drug_group = data.get("drugGroup", {})
        concept_group = drug_group.get("conceptGroup", [])
        
        for group in concept_group:
            concept_properties = group.get("conceptProperties")
            if concept_properties:
                for prop in concept_properties:
                    rxcui = prop.get("rxcui")
                    name = prop.get("name")
                    if rxcui and name:
                        results.append({"name": name, "rxcui": rxcui})
        return results
    except Exception as e:
        print(f"RxNorm search error: {e}")
        return []
    
def search_rxnorm_partial(query: str):
    """
    Calls /drugs.json with ?name=<query>&search=1 to allow partial/approx matches.
    Best for short queries or slightly fuzzy matches.
    """
    endpoint = f"{BASE_RXNORM_URL}/drugs.json"
    params = {
        "name": query,
        "search": "1",  # Enable partial/approx matching
    }
    try:
        response = requests.get(endpoint, params=params)
        response.raise_for_status()
        data = response.json()

        results = []
        drug_group = data.get("drugGroup", {})
        concept_group = drug_group.get("conceptGroup", [])

        # Example parse (same as your existing logic).
        for group in concept_group:
            concept_properties = group.get("conceptProperties")
            if concept_properties:
                for prop in concept_properties:
                    rxcui = prop.get("rxcui")
                    name = prop.get("name")
                    if rxcui and name:
                        results.append({"rxcui": rxcui, "name": name})
        return results

    except Exception as e:
        print(f"[search_rxnorm_partial] RxNorm error: {e}")
        return []
    
def search_rxnorm_approx(term: str, max_entries=10):
    """
    Calls /approximateTerm.json to handle fuzzy/approximate matching.
    1) We get a list of candidate RxCUIs from the approximateTerm call.
    2) For each RxCUI, we do a second request to /rxcui/<rxcui>/properties.json to get the name.
    3) Filter out any names that *don’t* start with the search term.
    Returns a list of dicts: [{"rxcui": "...", "name": "..."}, ...]
    """

    endpoint = f"{BASE_RXNORM_URL}/approximateTerm.json"
    params = {
        "term": term,
        "maxEntries": str(max_entries),
    }
    try:
        r = requests.get(endpoint, params=params)
        r.raise_for_status()
        data = r.json()
    except Exception as e:
        print(f"[search_rxnorm_approx] approximateTerm error: {e}")
        return []

    group = data.get("approximateGroup", {})
    candidates = group.get("candidate", [])  # each has "rxcui", "score", "rank", etc.
    if not candidates:
        return []

    results = []
    term_lower = term.lower()  # so we can do case-insensitive comparisons

    for candidate in candidates:
        rxcui = candidate.get("rxcui")
        if not rxcui:
            continue

        # Step 2: fetch the official name from /rxcui/<rxcui>/properties.json
        name = fetch_rxnorm_name(rxcui)
        if not name:
            continue

        # Step 3: Enforce "starts with" check
        # e.g., if term = "par", we only keep "Paracetamol" or "Paricalcitol" (case-insensitive).
        if name.lower().startswith(term_lower):
            results.append({"rxcui": rxcui, "name": name})

    return results

def fetch_rxnorm_name(rxcui: str) -> str:
    """
    Helper to get the official drug name from /rxcui/<rxcui>/properties.json
    Returns an empty string if anything fails.
    """
    if not rxcui:
        return ""
    endpoint = f"{BASE_RXNORM_URL}/rxcui/{rxcui}/properties.json"
    try:
        r = requests.get(endpoint)
        r.raise_for_status()
        data = r.json()
        properties = data.get("properties", {})
        return properties.get("name", "")
    except Exception as e:
        print(f"[fetch_rxnorm_name] error for rxcui {rxcui}: {e}")
        return ""

def fetch_rxnorm_details(rxcui: str):
    """
    Fetches details for a specific RxCUI.
    Returns a dict including name, dosage_forms, default_frequency, etc.
    """
    if not rxcui:
        return {}
    endpoint = f"{BASE_RXNORM_URL}/rxcui/{rxcui}/properties.json"
    try:
        response = requests.get(endpoint)
        response.raise_for_status()
        data = response.json()
        
        properties = data.get("properties", {})
        name = properties.get("name", "")
        dosage_forms = []   # If you want to fill this in, see next function
        default_frequency = "Once daily"  # placeholder

        return {
            "name": name,
            "dosage_forms": dosage_forms,
            "default_frequency": default_frequency,
        }
    except Exception as e:
        print(f"RxNorm details error: {e}")
        return {}

def fetch_dosage_forms_from_rxnorm(rxcui: str):
    """
    Given an RXCUI, fetch common dosage forms from RxNorm.
    Example returns: ["Metformin 500 MG Oral Tablet", "Metformin 1000 MG Oral Tablet"]
    """
    try:
        url = f"{RXNORM_API_URL}/rxcui/{rxcui}/related.json?tty=SCD"
        response = requests.get(url)
        response.raise_for_status()

        dosage_forms = []
        concept_groups = response.json().get("relatedGroup", {}).get("conceptGroup", [])
        for group in concept_groups:
            for concept in group.get("conceptProperties", []):
                name = concept.get("name")
                if name:
                    dosage_forms.append(name)

        return {
            "rxcui": rxcui,
            "dosage_forms": dosage_forms
        }
    except Exception as e:
        print(f"[RxNorm Dosage Error] {e}")
        return {
            "rxcui": rxcui,
            "dosage_forms": []
        }

def guess_default_frequency(med_name: str, dosage_forms: list[str]) -> str:
    """
    Attempts to infer a good default frequency from name or dosage info.
    """
    text = f"{med_name} {' '.join(dosage_forms)}".lower()

    # Very basic heuristics — expand to fit your needs
    if "extended release" in text or "xr" in text:
        return "Once daily"
    if "twice" in text or "2 times" in text or "bid" in text:
        return "Twice daily"
    if "three times" in text or "3 times" in text or "tid" in text:
        return "Three times daily"
    if "as needed" in text or "prn" in text:
        return "As needed"
    if re.search(r'\bnight\b|\bbedtime\b', text):
        return "At bedtime"

    return "Once daily"  # fallback