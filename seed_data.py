"""
Data Grounding & Realistic Dataset Seeder (Person D)
Includes NFHS-5 & HMIS Grounding Stats + Realistic WHO IMCI Test Scenarios.
"""

from typing import Dict, Any, List

GROUNDING_STATS = {
    "problem_context": "Pediatric Rural Triage Crisis & Connectivity Barrier",
    "asha_coverage_ratio": "1 ASHA per 1,000–1,200 rural population (covering up to 40+ households/day)",
    "under_5_mortality_rate": "35.2 per 1,000 live births (NFHS-5 National Average; >45 in rural high-priority districts)",
    "leading_causes_of_u5_death": [
        {"cause": "Childhood Pneumonia & Acute Respiratory Infections (ARI)", "percentage": "14.3%"},
        {"cause": "Diarrheal Diseases & Dehydration", "percentage": "9.8%"},
        {"cause": "Neonatal Infections / Sepsis", "percentage": "11.2%"}
    ],
    "delayed_referral_impact": "Over 68% of preventable under-5 deaths occur due to delayed triage and lack of early warning referral from community level to PHC/FRU.",
    "connectivity_gap": "42.7% of Sub-Health Centres (SHCs) in aspirational and tribal districts operate in zero or intermittent 2G/unstable cellular connectivity, making cloud-only AI apps unviable.",
    "clinical_justification": "WHO IMCI guidelines provide deterministic, high-sensitivity decision trees for frontline non-clinical workers where false-negatives (missed severe cases) are life-threatening."
}

DEMO_PATIENT_SCENARIOS: List[Dict[str, Any]] = [
    {
        "patient": {
            "patient_id": "P-MH-101",
            "full_name": "Aarav Shinde",
            "age_months": 8,
            "gender": "M",
            "guardian_name": "Pooja Shinde",
            "village_name": "Khed Shivapur"
        },
        "extracted_fields": {
            "age_months": 8,
            "respiratory_rate": 56,
            "temperature_c": 38.8,
            "fever_days": 3,
            "symptoms": ["fever", "chest_indrawing"],
            "has_chest_indrawing": True,
            "has_convulsions": False,
            "has_vomiting_everything": False,
            "has_lethargy": False
        },
        "transcript": "8 mahine ka bachha, 3 din se bukhar aur 56 saans rate chhati dhas rahi hai",
        "expected_color": "YELLOW",
        "expected_condition": "PNEUMONIA (Fast Breathing & Chest Indrawing)"
    },
    {
        "patient": {
            "patient_id": "P-MH-102",
            "full_name": "Ananya Patil",
            "age_months": 14,
            "gender": "F",
            "guardian_name": "Ramesh Patil",
            "village_name": "Velhe"
        },
        "extracted_fields": {
            "age_months": 14,
            "respiratory_rate": 44,
            "temperature_c": 39.5,
            "fever_days": 2,
            "symptoms": ["convulsions", "lethargy", "fever"],
            "has_chest_indrawing": False,
            "has_convulsions": True,
            "has_vomiting_everything": False,
            "has_lethargy": True
        },
        "transcript": "bachhi ko jhatke aa rahe hain aur bilkul behoosh susti hai",
        "expected_color": "RED",
        "expected_condition": "SEVERE PNEUMONIA / VERY SEVERE DISEASE"
    },
    {
        "patient": {
            "patient_id": "P-MH-103",
            "full_name": "Kabir Jadhav",
            "age_months": 18,
            "gender": "M",
            "guardian_name": "Sunita Jadhav",
            "village_name": "Bhor"
        },
        "extracted_fields": {
            "age_months": 18,
            "respiratory_rate": 32,
            "temperature_c": 37.2,
            "fever_days": 0,
            "symptoms": ["diarrhea", "vomiting"],
            "has_chest_indrawing": False,
            "has_convulsions": False,
            "has_vomiting_everything": False,
            "has_lethargy": False
        },
        "transcript": "dast aur ulti ho rahi hai subah se par doodh pee raha hai",
        "expected_color": "GREEN",
        "expected_condition": "DIARRHEA / GASTROENTERITIS (Mild)"
    }
]


def seed_local_db(local_db_instance):
    from imci_rules_engine import evaluate_imci_rules

    print("Seeding local database with realistic IMCI cases...", flush=True)
    for item in DEMO_PATIENT_SCENARIOS:
        extracted = {"extracted_fields": item["extracted_fields"]}
        triage = evaluate_imci_rules(extracted, patient_id=item["patient"]["patient_id"])
        local_db_instance.record_triage_assessment(
            extracted_data=extracted,
            triage_result=triage,
            patient_info=item["patient"],
            asha_id="ASHA-MH-PUNE-012"
        )
    print(f"Successfully seeded {len(DEMO_PATIENT_SCENARIOS)} cases into local database.", flush=True)


if __name__ == "__main__":
    from local_db import LocalTriageDB
    db = LocalTriageDB("local_triage.db")
    seed_local_db(db)
