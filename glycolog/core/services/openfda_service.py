import requests
from urllib.parse import quote

OPENFDA_SEARCH_URL = "https://api.fda.gov/drug/label.json"

def search_openfda_drugs(query: str = "", limit=20):
    try:
        if query.strip() == "":
            # Default to a search for the most common medications as fallback
            url = f"{OPENFDA_SEARCH_URL}?limit={limit}"
        else:
            # Use wildcard + OR search for both brand and generic names
            raw_search = f'openfda.brand_name:{query}* OR openfda.generic_name:{query}*'
            encoded_query = quote(raw_search)
            url = f"{OPENFDA_SEARCH_URL}?search={encoded_query}&limit={limit}"

        response = requests.get(url)
        response.raise_for_status()
        data = response.json()

        results = []
        for item in data.get("results", []):
            names = item.get("openfda", {})
            brand_names = names.get("brand_name", [])
            generic_names = names.get("generic_name", [])

            all_names = list(set(brand_names + generic_names))
            for name in all_names:
                results.append({
                    "name": name,
                    "id": item.get("id", "N/A")
                })

        return results

    except requests.exceptions.HTTPError as e:
        print(f"[OpenFDA] HTTPError: {e.response.status_code} - {e.response.text}")
    except Exception as e:
        print(f"[OpenFDA] General Error: {e}")

    return []

def fetch_openfda_drug_details(fda_id: str):
    """
    Fetches detailed drug information for a given OpenFDA ID.
    Returns brand name, generic name, indications, and dosage text.
    """
    try:
        url = f"{OPENFDA_SEARCH_URL}?search=id:{fda_id}"
        response = requests.get(url)
        response.raise_for_status()
        results = response.json().get("results", [])

        if not results:
            return {}

        result = results[0]
        openfda_info = result.get("openfda", {})

        return {
            "name": openfda_info.get("brand_name", ["Unknown"])[0],
            "generic_name": openfda_info.get("generic_name", [""])[0],
            "indications": result.get("indications_and_usage", [""])[0],
            "dosage_and_administration": result.get("dosage_and_administration", [""])[0],
        }
    except Exception as e:
        print(f"[OpenFDA] Error fetching drug details: {e}")
        return {}
