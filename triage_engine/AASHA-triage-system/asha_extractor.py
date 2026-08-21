"""
ASHA Speech-to-Text & Symptom Extraction Layer (Person C)
Deterministic, offline, MULTILINGUAL rule-based Entity Extraction Engine.

Supports Hindi / Hinglish / English plus major Indian languages:
Tamil, Telugu, Bengali, Marathi, Kannada, Malayalam, Gujarati, Punjabi, Odia, Urdu.

The engine is a transparent, auditable thesaurus of symptom terms per language.
All terms are written in Latin transliteration so they match ASR / speech-to-text
output regardless of script. Native-speaker review is recommended before deployment.
"""

import re
from typing import Dict, Any, List, Optional


# ---------------------------------------------------------------------------
# Language registry
# ---------------------------------------------------------------------------
LANGUAGES: Dict[str, str] = {
    "en": "English",
    "hi": "Hindi / Hinglish",
    "ur": "Urdu",
    "ta": "Tamil",
    "te": "Telugu",
    "bn": "Bengali",
    "mr": "Marathi",
    "kn": "Kannada",
    "ml": "Malayalam",
    "gu": "Gujarati",
    "pa": "Punjabi",
    "or": "Odia",
}


# ---------------------------------------------------------------------------
# Symptom thesaurus (per language, Latin transliteration)
# Each symptom maps to {language_code: [terms...]}
# ---------------------------------------------------------------------------
SYMPTOM_TERMS: Dict[str, Dict[str, List[str]]] = {
    "fever": {
        "en": ["fever", "temperature", "high temperature", "garam body", "garam hai"],
        "hi": ["bukhar", "bukar", "taap", "jwar", "garam"],
        "ur": ["bukhar", "bukar", "taap"],
        "ta": ["kaaychal", "jvaram", "veppam"],
        "te": ["jvaram", "jwaram", "veyivaram"],
        "bn": ["jwor", "jor", "jara"],
        "mr": ["taap", "tapan", "jwara"],
        "kn": ["jvara", "jvar", "bisilu"],
        "ml": ["panni", "pani", "jwaram"],
        "gu": ["tav", "taav", "juar"],
        "pa": ["bukhar", "bukar", "taap"],
        "or": ["jwara", "jara"],
    },
    "chest_indrawing": {
        "en": ["chest indrawing", "chest drawing", "chest retraction", "stridor", "wheeze", "retractions"],
        "hi": ["chhati dhasna", "chhati phoolna", "saans lene me dikkat", "saans lene mein dikkat", "chhati dhabna"],
        "ur": ["chhati dhasna", "chhati phoolna", "saans mein dikkat"],
        "ta": ["marbu ullizhuthal", "edai ullizhuthal"],
        "te": ["chaati padipovadam", "chaati lopala", "eddala posagipovadam"],
        "bn": ["buk doba", "buk dhonba", "buka dubano"],
        "mr": ["chhati dhasne", "chhati bugne", "shwas ghetana anantar"],
        "kn": ["ede olagade", "ede olage", "shareera olagade"],
        "ml": ["nenchu ullilekku", "nench ullilekk", "uravil olichu"],
        "gu": ["chaati dobavu", "chhati dobi", "shwas ma rai dikkt"],
        "pa": ["chhati dabna", "chhati dhasna", "saah vich dushwari"],
        "or": ["chhati duba", "chhati dhasiba", "shwas re kasht"],
    },
    "diarrhea": {
        "en": ["diarrhea", "loose motion", "loose stools", "watery stool"],
        "hi": ["dast", "pakhana", "dast lagna", "paani jaisa dast"],
        "ur": ["dast", "pakhana", "dast lagna"],
        "ta": ["vayitruppokku", "peenipokku", "kozhuppokku"],
        "te": ["virechanalu", "neeru poka"],
        "bn": ["atisar", "oshodh", "ponod"],
        "mr": ["atisar", "dhakya", "jhalya"],
        "kn": ["bhedi", "atisara", "neeru mala"],
        "ml": ["athisaaram", "vayarupokku", "jaladhosham"],
        "gu": ["jhada", "dule dast", "dhava"],
        "pa": ["dast", "hoya", "dhava"],
        "or": ["jhada", "atisar", "soda"],
    },
    "vomiting": {
        "en": ["vomiting", "vomit", "throwing up", "puking"],
        "hi": ["ulti", "ulti aa rahi hai"],
        "ur": ["ulti", "qaee", "ulti aa rahi hai"],
        "ta": ["vaanthi", "okkam", "vizhuppu"],
        "te": ["vaanti", "venti", "vanti"],
        "bn": ["bombi", "boma", "bomni"],
        "mr": ["ulti", "odata", "kadhi"],
        "kn": ["vaanti", "vamathu", "bombi"],
        "ml": ["chardhi", "vaanthi", "ozhippu"],
        "gu": ["ol", "olo", "olkhi"],
        "pa": ["ulti", "olna", "kai"],
        "or": ["baanta", "banta", "bankhi"],
    },
    "vomiting_everything": {
        "en": ["vomiting everything", "throwing up everything", "cannot keep anything down", "everything comes back up"],
        "hi": ["sab ulti", "sab kuch ulti", "kha nahi raha", "kuch nahi kha raha", "ulti ho rahi hai sab"],
        "ur": ["sab ulti", "kha nahi raha", "sab kuch ulti"],
        "ta": ["ellam vaanthi", "sapdura edukkala", "onnum vizha mateengra"],
        "te": ["anthaa vaanti", "emi thinagalenu", "anthaa venti"],
        "bn": ["sob bombi", "kichu khete pare na", "sab bombi"],
        "mr": ["sagla ulti", "khancha yet nahi", "saglya goshti ulti"],
        "kn": ["elli vaanti", "ennu thinabardu", "ella vamathu"],
        "ml": ["ellam chardhi", "onnuthinum kazhikkilla", "ellam vaanthi"],
        "gu": ["badhu ol", "kai shakay nathi", "bau ol"],
        "pa": ["sab ulti", "kujh nahi kha sakda", "sab kujh ulti"],
        "or": ["sabu banta", "kichhi khaiparheni", "sabu bankhi"],
    },
    "convulsions": {
        "en": ["convulsions", "seizure", "fit", "fits", "spasms"],
        "hi": ["jhatke", "mirgi", "aenthang", "dardane"],
        "ur": ["jhatke", "mirgi", "dore"],
        "ta": ["valippu", "pidippu", "potu", "pittam"],
        "te": ["mirigi", "piduvatamu", "mokkala", "spasam"],
        "bn": ["khichuni", "mrigi", "aekare"],
        "mr": ["akadi", "mirgi", "daura"],
        "kn": ["selete", "mirugi", "mooka"],
        "ml": ["pidippu", "mirugam", "pittam"],
        "gu": ["khenchan", "mirgi", "dhara"],
        "pa": ["daure", "mirgi", "jhatke"],
        "or": ["baat", "mrigi", "aakade"],
    },
    "lethargy": {
        "en": ["lethargy", "unresponsive", "lethargic", "unconscious", "not waking", "weak and dull"],
        "hi": ["behoosh", "sota rehta hai", "susti", "hosh nahi", "jaag nahi raha"],
        "ur": ["behoosh", "sota rehta hai", "hosh nahi"],
        "ta": ["mayakkam", "unarchi", "ezhumbamattu", "sella unarchi"],
        "te": ["chetana levu", "mookam", "ezharu ledu"],
        "bn": ["ochchhonna", "behosh", "songhopto", "jagena"],
        "mr": ["behosh", "sust", "jagatch nahi", "behoshi"],
        "kn": ["bedhuda", "jadate", "chelivillada", "jagalla"],
        "ml": ["bodharahithyam", "unarcha", "ezhunilkkilla", "manasilla"],
        "gu": ["behosh", "benaan", "jaagta nathi", "benaan"],
        "pa": ["behosh", "sust", "jag nahi raha", "hosh nahi"],
        "or": ["besudh", "behosi", "jagena", "chetanahin"],
    },
}


# Flattened thesaurus (backwards-compatible view, all languages merged)
THESAURUS: Dict[str, List[str]] = {
    s_key: [t for lang_terms in lang_map.values() for t in lang_terms]
    for s_key, lang_map in SYMPTOM_TERMS.items()
}


# ---------------------------------------------------------------------------
# Multilingual number words (falls back when ASR emits words instead of digits)
# ---------------------------------------------------------------------------
NUMBER_WORDS: Dict[str, int] = {
    # Hindi / Marathi / Gujarati / Punjabi / Bengali (Devanagari/Bengali family)
    "ek": 1, "do": 2, "teen": 3, "char": 4, "panch": 5,
    "cheh": 6, "saat": 7, "aath": 8, "nau": 9, "das": 10,
    # Tamil
    "onnu": 1, "rendu": 2, "moondru": 3, "naalu": 4, "anju": 5,
    "aaru": 6, "ezhu": 7, "ettu": 8, "onbadhu": 9, "pathu": 10,
    # Telugu
    "okati": 1, "moodu": 3, "naalugu": 4, "aidu": 5, "eduru": 7,
    "tommidi": 9, "padi": 10,
    # Kannada
    "ondu": 1, "yeradu": 2, "mooru": 3, "naalku": 4, "elu": 7,
    "entu": 8, "ombattu": 9, "hattu": 10,
    # Malayalam
    "randu": 2, "moonnu": 3, "anchu": 5,
}


# ---------------------------------------------------------------------------
# Multilingual unit words
# ---------------------------------------------------------------------------
MONTH_WORDS: List[str] = [
    "mahine", "mahina", "month", "months", "masam", "masalu", "maasam",
    "maadham", "maadam", "matham", "matha", "maheen", "tingal", "maas",
    "mahina",
]
DAY_WORDS: List[str] = [
    "din", "day", "days", "naal", "naalu", "roju", "divasam", "divas", "dina",
    "divasangal",
]
YEAR_WORDS: List[str] = [
    "saal", "year", "years", "yr", "yrs", "varusham", "varush", "samvatsaram",
    "bachhar", "varsha", "varsh", "barsh", "varusham",
]


def _alt(words: List[str]) -> str:
    """Build a regex alternation sorted longest-first to avoid partial matches."""
    return "(?:" + "|".join(re.escape(w) for w in sorted(set(words), key=len, reverse=True)) + ")"


_MONTH_ALT = _alt(MONTH_WORDS)
_DAY_ALT = _alt(DAY_WORDS)
_YEAR_ALT = _alt(YEAR_WORDS)


def _word_to_number(text_lower: str) -> Optional[int]:
    for word, value in NUMBER_WORDS.items():
        if re.search(r"\b" + re.escape(word) + r"\b", text_lower):
            return value
    return None


def detect_language(transcript: str) -> str:
    """
    Best-effort, transliteration-based language detection.
    Counts symptom-term hits per language and returns the dominant code.
    Falls back to 'en' when no signal is found.
    """
    text_lower = (transcript or "").lower()
    if not text_lower.strip():
        return "en"

    scores: Dict[str, int] = {code: 0 for code in LANGUAGES}
    for lang_map in SYMPTOM_TERMS.values():
        for lang, terms in lang_map.items():
            for term in terms:
                if re.search(r"\b" + re.escape(term) + r"\b", text_lower) or term in text_lower:
                    scores[lang] += 1

    best_lang = max(scores, key=lambda k: scores[k])
    if scores[best_lang] == 0:
        return "en"
    return best_lang


def parse_asha_transcript(transcript: str) -> Dict[str, Any]:
    """
    Parses raw multilingual ASHA transcriptions into structured IMCI data schema.
    """
    if not transcript or not isinstance(transcript, str):
        return {
            "raw_transcript": transcript or "",
            "language": "en",
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
    language = detect_language(transcript)

    # --- 1. AGE EXTRACTION (digits or number words, months or years) ---
    age_months: Optional[int] = None
    month_match = re.search(r"(\d+)\s*(?:-| )?\s*" + _MONTH_ALT + r"\b", text_lower)
    if month_match:
        age_months = int(month_match.group(1))
    else:
        year_match = re.search(r"(\d+(?:\.\d+)?)\s*(?:-| )?\s*" + _YEAR_ALT + r"\b", text_lower)
        if year_match:
            age_months = int(float(year_match.group(1)) * 12)
        else:
            wnum = _word_to_number(text_lower)
            if wnum is not None:
                if re.search(_MONTH_ALT + r"\b", text_lower):
                    age_months = wnum
                elif re.search(_YEAR_ALT + r"\b", text_lower):
                    age_months = wnum * 12

    # --- 2. RESPIRATORY RATE EXTRACTION ---
    respiratory_rate: Optional[int] = None
    rr_patterns = [
        r"(\d+)\s*(?:saans\s*rate|saans/min|saans\s*per\s*min|breaths\s*per\s*minute|breaths/min|\/min)",
        r"(?:rr|respiratory\s*rate|rate|saans|shwas|uchchwasam|kaal|mozhi)\s*(?:of|is|:)?\s*(\d+)",
        r"(\d+)\s*(?:saans|breaths|shwas)\b",
    ]
    for pat in rr_patterns:
        match = re.search(pat, text_lower)
        if match:
            num_str = match.group(1) if match.group(1) else match.group(2)
            if num_str:
                respiratory_rate = int(num_str)
                break

    # --- 3. SYMPTOM MATCHING (all languages) ---
    detected_symptoms: List[str] = []
    for s_key, lang_map in SYMPTOM_TERMS.items():
        for term in (t for terms in lang_map.values() for t in terms):
            if re.search(r"\b" + re.escape(term) + r"\b", text_lower) or term in text_lower:
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
    if has_fever or re.search(_DAY_ALT + r"\b", text_lower):
        fever_day_match = re.search(
            r"(\d+)\s*" + _DAY_ALT + r"\s*(?:se)?(?:\s*(?:bukhar|jwar|fever|jvaram|kaaychal|panni))?",
            text_lower,
        )
        if not fever_day_match:
            fever_day_match = re.search(
                r"(?:bukhar|jwar|fever|jvaram|kaaychal|panni)\s*(?:for|se)?\s*(\d+)\s*" + _DAY_ALT,
                text_lower,
            )
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
        "language": language,
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


# ---------------------------------------------------------------------------
# Localized referral note generator
# ---------------------------------------------------------------------------
_REFERRAL_TEMPLATES: Dict[str, Dict[str, str]] = {
    "YELLOW_PHC": {
        "en": "Suspected pneumonia. Refer to PHC within 24 hours.",
        "hi": "संदिग्ध निमोनिया। 24 घंटे के भीतर PHC भेजें।",
    },
    "RED_URGENT": {
        "en": "Severe illness / Danger signs present. Refer IMMEDIATELY to hospital.",
        "hi": "गंभीर बीमारी / खतरे के लक्षण मौजूद। तुरंत अस्पताल रेफर करें।",
    },
    "GREEN_HOME": {
        "en": "Mild illness. Home care advised; return if signs worsen.",
        "hi": "हल्की बीमारी। घर पर देखभाल; लक्षण बिगड़ें तो वापस आएं।",
    },
}


def generate_referral_note(extract: Dict[str, Any], triage_code: str, lang: Optional[str] = None) -> str:
    """
    Produces a human-readable clinical referral note. English clinical detail is
    always included (required by downstream systems); a localized header is
    prepended when the detected / requested language has a translation.
    """
    lang = lang or extract.get("language", "en")
    fields = extract.get("extracted_fields", {})

    template = _REFERRAL_TEMPLATES.get(triage_code, _REFERRAL_TEMPLATES["GREEN_HOME"])
    localized = template.get(lang, template["en"])

    age = fields.get("age_months")
    rr = fields.get("respiratory_rate")
    symptoms = ", ".join(fields.get("symptoms", [])) or "none"

    header = f"[Referral Note] Patient age: {age or 'N/A'} months | RR: {rr or 'N/A'} | Symptoms: {symptoms}\n"
    note = header + localized
    if lang in _REFERRAL_TEMPLATES[triage_code] and lang != "en":
        note += "\n" + template["en"]
    return note

