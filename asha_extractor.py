"""
ASHA Speech-to-Text & Symptom Extraction Layer (Person C)
Deterministic, offline rule-based Entity Extraction Engine.
"""

import re
from typing import Dict, Any, List, Optional


THESAURUS: Dict[str, List[str]] = {
    "fever": ["bukhar", "bukar", "taap", "fever", "garam body", "garam hai"],
    "chest_indrawing": [
        "chhati dhasna",
        "chest drawing",
        "chest indrawing",
        "chhati phoolna",
        "saans lene me dikkat",
        "saans lene mein dikkat",
        "stridor",
        "wheeze",
    ],
    "diarrhea": ["dast", "loose motion", "pakhana", "diarrhea", "dull stool"],
    "vomiting": ["ulti", "vomit", "vomiting"],
    "vomiting_everything": ["ulti ho rahi hai sab", "sab ulti", "kha nahi raha", "vomiting everything", "har cheez ulti"],
    "convulsions": ["jhatke", "seizure", "mirgi", "fit", "aenthang"],
    "lethargy": ["behoosh", "sota rehta hai", "unresponsive", "lethargic", "susti"],
}


def parse_asha_transcript(transcript: str) -> Dict[str, Any]:
    """
    Parses raw Hindi/Hinglish/English ASHA transcriptions into structured IMCI data schema.
    """
    if not transcript or not isinstance(transcript, str):
        return {
            "raw_transcript": transcript or "",
            "extracted_fields": {
                "age_months": None,
                "respiratory_rate": None,
                "fever_days": 0,
                "symptoms": [],
                "has_chest_indrawing": False,
                "has_convulsions": False,
                "has_vomiting": False,
                "has_vomiting_everything": False,
                "has_lethargy": False,
            },
            "extraction_confidence": 0.0,
        }

    text_lower = transcript.lower()

    # --- 1. AGE EXTRACTION ---
    age_months: Optional[int] = None
    month_match = re.search(r'(\d+)\s*(-|\s)?\s*(mahine|mahina|month|months|m)\b', text_lower)
    if month_match:
        age_months = int(month_match.group(1))
    else:
        year_match = re.search(r'(\d+(?:\.\d+)?)\s*(-|\s)?\s*(saal|year|years|yr|yrs)\b', text_lower)
        if year_match:
            age_months = int(float(year_match.group(1)) * 12)

    # --- 2. RESPIRATORY RATE EXTRACTION ---
    respiratory_rate: Optional[int] = None
    rr_patterns = [
        r'(\d+)\s*(?:saans\s*rate|saans/min|saans\s*per\s*min|breaths\s*per\s*minute|breaths/min|\/min)',
        r'(?:rr|respiratory\s*rate|rate|saans)\s*(?:of|is|:)?\s*(\d+)',
        r'(\d+)\s*(?:saans|breaths)\b',
    ]

    for pat in rr_patterns:
        match = re.search(pat, text_lower)
        if match:
            num_str = match.group(1) if match.group(1) else match.group(2)
            if num_str:
                respiratory_rate = int(num_str)
                break

    # --- 3. SYMPTOM MATCHING ---
    detected_symptoms: List[str] = []

    for s_key, terms in THESAURUS.items():
        for term in terms:
            if re.search(r'\b' + re.escape(term) + r'\b', text_lower) or term in text_lower:
                detected_symptoms.append(s_key)
                break

    has_fever = "fever" in detected_symptoms
    has_chest_indrawing = "chest_indrawing" in detected_symptoms
    has_convulsions = "convulsions" in detected_symptoms
    has_vomiting = "vomiting" in detected_symptoms or "vomiting_everything" in detected_symptoms
    has_vomiting_everything = "vomiting_everything" in detected_symptoms
    has_lethargy = "lethargy" in detected_symptoms

    # --- 4. FEVER DURATION EXTRACTION ---
    fever_days: int = 0
    if has_fever or "din" in text_lower or "day" in text_lower:
        fever_day_match = re.search(r'(\d+)\s*(?:din|day|days)\s*(?:se)?(?:\s*(?:bukhar|fever))?', text_lower)
        if not fever_day_match:
            fever_day_match = re.search(r'(?:bukhar|fever)\s*(?:for|se)?\s*(\d+)\s*(?:din|day|days)', text_lower)

        if fever_day_match:
            fever_days = int(fever_day_match.group(1))

    # --- 5. CONFIDENCE CALCULATION ---
    filled_slots = 0
    if age_months is not None:
        filled_slots += 1
    if respiratory_rate is not None:
        filled_slots += 1
    if fever_days > 0:
        filled_slots += 1
    if len(detected_symptoms) > 0:
        filled_slots += 2
    else:
        filled_slots += 1

    confidence = round(min(1.0, filled_slots / 5.0), 2)

    return {
        "raw_transcript": transcript,
        "extracted_fields": {
            "age_months": age_months,
            "respiratory_rate": respiratory_rate,
            "fever_days": fever_days,
            "symptoms": detected_symptoms,
            "has_chest_indrawing": has_chest_indrawing,
            "has_convulsions": has_convulsions,
            "has_vomiting": has_vomiting,
            "has_vomiting_everything": has_vomiting_everything,
            "has_lethargy": has_lethargy,
        },
        "extraction_confidence": confidence,
    }
