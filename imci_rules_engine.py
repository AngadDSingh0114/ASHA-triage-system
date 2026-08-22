"""
WHO IMCI / IMNCI Decision-Tree Rules Engine & Referral Formatter
Person B & C Core Integration Layer.

Now powered by a strict field-by-field classifier ported from the external
TypeScript Triage_Engine (engine.ts / referralNote.ts), with worst-flag-wins
aggregation, young-infant catch-all RED rule, and full rule_trace arrays.
Localization/TTS/SMS/WhatsApp formatters are preserved as a post-processing layer.
"""

from typing import Any, Dict, List, Optional
import urllib.parse


# ---------------------------------------------------------------------------
# Localization packs (currently Hindi). Extend by adding new language codes.
# ---------------------------------------------------------------------------
URGENCY_HI: Dict[str, str] = {
    "URGENT HOSPITAL REFERRAL": "तुरंत अस्पताल रेफर करें",
    "REFER TO PHC WITHIN 24 HOURS": "24 घंटे के भीतर PHC भेजें",
    "PHC CLINIC VISIT": "PHC क्लिनिक जाएं",
    "HOME CARE WITH ORS": "घर पर ORS से देखभाल",
    "HOME CARE": "घर पर देखभाल",
    "REFER TO PHC FOR BLOOD TEST": "जांच के लिए PHC भेजें",
}

DIAGNOSIS_HI: Dict[str, str] = {
    "SEVERE PNEUMONIA / VERY SEVERE DISEASE": "गंभीर निमोनिया / अत्यंत गंभीर बीमारी",
    "PNEUMONIA (Fast Breathing)": "निमोनिया (तेज सांस)",
    "DIARRHEA / GASTROENTERITIS": "दस्त / आंत्रशोथ",
    "FEVER - POSSIBLE MALARIA / TYPHOID": "बुखार - संभव मलेरिया / टाइफाइड",
    "FEVER - MILD ACUTE FEBRILE ILLNESS": "बुखार - हल्का तीव्र ज्वर",
    "NO PNEUMONIA / MILD ILLNESS": "कोई निमोनिया नहीं / हल्की बीमारी",
    "POSSIBLE_SERIOUS_BACTERIAL_INFECTION": "संभव गंभीर जीवाणु संक्रमण",
    "SEVERE_DEHYDRATION": "गंभीर निर्जलीकरण",
    "SOME_DEHYDRATION": "कुछ निर्जलीकरण",
    "NO_DEHYDRATION": "निर्जलीकरण नहीं",
    "FEVER": "बुखार",
    "FEVER_PROLONGED": "लंबे समय तक बुखार",
    "VERY_SEVERE_FEBRILE_DISEASE": "अत्यंत गंभीर ज्वर रोग",
    "MASTOIDITIS": "मैस्टोइडाइटिस",
    "ACUTE_EAR_INFECTION": "तीव्र कान संक्रमण",
}

DANGER_HI: Dict[str, str] = {
    "Convulsions": "दौरे",
    "Lethargy/Unresponsiveness": "सुस्ती / बेहोशी",
    "Vomiting Everything": "सब उल्टी",
    "Chest indrawing": "छाती धंसना",
    "Persistent diarrhea": "लगातार दस्त",
    "Acute diarrhea": "तेज दस्त",
    "No acute danger signs": "कोई तत्काल खतरे के लक्षण नहीं",
    "Severe chest indrawing": "गंभीर छाती धंसना",
    "not able to drink/breastfeed": "पीने में तकलीफ / स्तनपान नहीं",
    "vomits everything": "सब उल्टी",
    "lethargic or unconscious": "सुस्ती / बेहोशी",
    "young infant (<2mo) with positive symptom": "1 महीने का बच्चा (<2 महीने) संकेत positive",
    "stiff neck": "गर्दन अकड़",
    "mastoid swelling": "कान पीछे सूजन",
    "ear pain or discharge": "कान दर्द / स्राव",
    "blood in stool": "मल में खून",
    "sunken eyes": "आँखें धंसी",
}

ACTIONS_HI: Dict[str, str] = {
    "Give first dose of appropriate oral antibiotic before transfer": "स्थानांतरण से पहले उचित मौखिक एंटीबायोटिक की पहली खुराक दें",
    "Keep child warm during transport": "यात्रा के दौरान बच्चे को गर्म रखें",
    "Refer IMMEDIATELY to nearest hospital / First Referral Unit (FRU)": "तुरंत नजदीकी अस्पताल / FRU भेजें",
    "Give oral Amoxicillin for 5 days": "5 दिन तक मौखिक एमोक्सिसिलिन दें",
    "Soothe throat and relieve cough with safe remedy": "सुरक्षित उपाय से गला शांत करें और खांसी कम करें",
    "Advise mother when to return immediately if signs worsen": "लक्षण बिगड़ने पर तुरंत लौटने की सलाह दें",
    "Refer to Primary Health Centre (PHC)": "प्राथमिक स्वास्थ्य केंद्र (PHC) भेजें",
    "Give extra fluid (ORS solution & Zinc supplement for 14 days)": "अतिरिक्त तरल (ORS घोल और 14 दिन तक जिंक) दें",
    "Continue feeding child": "बच्चे को खाना जारी रखें",
    "Advise when to return immediately": "तुरंत लौटने की सलाह दें",
    "Perform RDT test for Malaria if available": "उपलब्ध हो तो मलेरिया की RDT जांच करें",
    "Give Paracetamol for high fever (≥38.5°C)": "तेज बुखार (≥38.5°C) पर पैरासिटामोल दें",
    "Refer to PHC for evaluation": "जांच के लिए PHC भेजें",
    "Give Paracetamol for fever": "बुखार के लिए पैरासिटामोल दें",
    "Ensure adequate hydration": "पर्याप्त पानी दें",
    "Follow up in 2 days if fever persists": "बुखार बना रहे तो 2 दिन में फॉलो-अप करें",
    "Soothe throat with home remedy": "घरेलू उपाय से गला शांत करें",
    "Advise mother when to return if signs worsen": "लक्षण बिगड़ने पर लौटने की सलाह दें",
}

LOCALIZATION: Dict[str, Dict[str, Dict[str, str]]] = {
    "hi": {
        "urgency": URGENCY_HI,
        "diagnosis": DIAGNOSIS_HI,
        "danger": DANGER_HI,
        "action": ACTIONS_HI,
    },
}


def _tr(text: str, lang: str, category: str) -> str:
    """Translate a canonical English phrase into `lang` if a pack exists."""
    pack = LOCALIZATION.get(lang, {}).get(category, {})
    return pack.get(text, text)


# ---------------------------------------------------------------------------
# Ported TypeScript Engine Types & Constants
# ---------------------------------------------------------------------------

FLAG_RANK: Dict[str, int] = {
    "green": 0,
    "yellow": 1,
    "red": 2,
}


class ConditionResult:
    def __init__(self, name: str, classification: str, flag: str, reasonTrace: List[str]):
        self.name = name
        self.classification = classification
        self.flag = flag
        self.reasonTrace = reasonTrace

    def to_dict(self) -> Dict[str, Any]:
        return {
            "name": self.name,
            "classification": self.classification,
            "flag": self.flag,
            "reasonTrace": self.reasonTrace,
        }


class TriageResult:
    def __init__(self, flag: str, conditions: List[ConditionResult], rule_trace: List[str], override_reason: Optional[str] = None):
        self.flag = flag
        self.conditions = conditions
        self.rule_trace = rule_trace
        self.override_reason = override_reason

    def to_dict(self) -> Dict[str, Any]:
        return {
            "flag": self.flag,
            "conditions": [c.to_dict() for c in self.conditions],
            "rule_trace": self.rule_trace,
            "override_reason": self.override_reason,
        }


# ---------------------------------------------------------------------------
# Step 1: General Danger Signs
# ---------------------------------------------------------------------------

def check_general_danger_signs(symptoms: Dict[str, Any]) -> List[str]:
    present: List[str] = []
    if symptoms.get("not_able_to_drink_or_breastfeed"):
        present.append("not able to drink/breastfeed")
    if symptoms.get("vomits_everything"):
        present.append("vomits everything")
    if symptoms.get("convulsions"):
        present.append("convulsions")
    if symptoms.get("lethargic_or_unconscious"):
        present.append("lethargic or unconscious")
    return present


# ---------------------------------------------------------------------------
# Step 2a: Pneumonia Classification
# ---------------------------------------------------------------------------

def classify_pneumonia(patient: Dict[str, Any], vitals: Dict[str, Any], symptoms: Dict[str, Any]) -> Optional[ConditionResult]:
    if not symptoms.get("cough_or_difficulty_breathing"):
        return None

    age_m = patient.get("age_months")
    rr = vitals.get("resp_rate_bpm") or 0
    rr_cutoff = 60 if (age_m is not None and age_m < 2) else (50 if (age_m is not None and age_m < 12) else 40)
    fast_breathing = rr >= rr_cutoff

    if age_m is not None and age_m < 2 and (fast_breathing or symptoms.get("chest_indrawing") or symptoms.get("stridor_calm_child")):
        return ConditionResult(
            name="pneumonia",
            classification="POSSIBLE_SERIOUS_BACTERIAL_INFECTION",
            flag="red",
            reasonTrace=[f"age {age_m}mo (<2mo) with positive sign -> refer per young-infant scope decision"],
        )

    if symptoms.get("chest_indrawing") or symptoms.get("stridor_calm_child"):
        return ConditionResult(
            name="pneumonia",
            classification="SEVERE_PNEUMONIA",
            flag="red",
            reasonTrace=[f"chest_indrawing={bool(symptoms.get('chest_indrawing'))}, stridor={bool(symptoms.get('stridor_calm_child'))}"],
        )

    if fast_breathing:
        return ConditionResult(
            name="pneumonia",
            classification="PNEUMONIA",
            flag="yellow",
            reasonTrace=[f"RR {rr} >= cutoff {rr_cutoff} for age {age_m}mo"],
        )

    return ConditionResult(
        name="pneumonia",
        classification="NO_PNEUMONIA",
        flag="green",
        reasonTrace=["below RR cutoff, no indrawing/stridor"],
    )


# ---------------------------------------------------------------------------
# Step 2b: Diarrhoea Classification
# ---------------------------------------------------------------------------

def classify_diarrhoea(patient: Dict[str, Any], vitals: Dict[str, Any], symptoms: Dict[str, Any]) -> Optional[ConditionResult]:
    if not symptoms.get("diarrhoea"):
        return None

    severe_count = sum([
        symptoms.get("lethargic_or_unconscious", False),
        symptoms.get("sunken_eyes", False),
        symptoms.get("drinking") == "poor_or_unable",
        symptoms.get("skin_pinch") == "very_slow",
    ])

    some_count = sum([
        symptoms.get("restless_irritable", False),
        symptoms.get("sunken_eyes", False),
        symptoms.get("drinking") == "eager_thirsty",
        symptoms.get("skin_pinch") == "slow",
    ])

    if severe_count >= 2:
        result = ConditionResult(
            name="diarrhoea",
            classification="SEVERE_DEHYDRATION",
            flag="red",
            reasonTrace=[f"{severe_count} severe-row signs"],
        )
    elif some_count >= 2:
        result = ConditionResult(
            name="diarrhoea",
            classification="SOME_DEHYDRATION",
            flag="yellow",
            reasonTrace=[f"{some_count} some-row signs"],
        )
    else:
        result = ConditionResult(
            name="diarrhoea",
            classification="NO_DEHYDRATION",
            flag="green",
            reasonTrace=["<2 signs in either row"],
        )

    if symptoms.get("blood_in_stool"):
        result.classification += "+DYSENTERY"
        result.reasonTrace.append("blood in stool -> dysentery")
        if result.flag == "green":
            result.flag = "yellow"

    diarrhoea_days = symptoms.get("diarrhoea_days") or 0
    if diarrhoea_days >= 14:
        result.classification += "+PERSISTENT"
        result.reasonTrace.append(f"diarrhoea_days={diarrhoea_days} >= 14 -> persistent, refer for assessment")
        if result.flag == "green":
            result.flag = "yellow"

    return result


# ---------------------------------------------------------------------------
# Step 2c: Fever Classification
# ---------------------------------------------------------------------------

def classify_fever(patient: Dict[str, Any], vitals: Dict[str, Any], symptoms: Dict[str, Any]) -> Optional[ConditionResult]:
    temp_c = vitals.get("temp_c") or 0
    fever_days = symptoms.get("fever_days") or 0
    has_fever = temp_c >= 37.5 or fever_days > 0

    if not has_fever:
        return None

    if symptoms.get("stiff_neck"):
        return ConditionResult(
            name="fever",
            classification="VERY_SEVERE_FEBRILE_DISEASE",
            flag="red",
            reasonTrace=["stiff neck present"],
        )

    if fever_days >= 7:
        return ConditionResult(
            name="fever",
            classification="FEVER_PROLONGED",
            flag="yellow",
            reasonTrace=[f"fever_days={fever_days} >= 7 -> refer for assessment"],
        )

    return ConditionResult(
        name="fever",
        classification="FEVER_LOW_RISK",
        flag="green",
        reasonTrace=["fever <7 days, no stiff neck, no general danger sign"],
    )


# ---------------------------------------------------------------------------
# Step 2d: Ear Problem Classification
# ---------------------------------------------------------------------------

def classify_ear_problem(patient: Dict[str, Any], vitals: Dict[str, Any], symptoms: Dict[str, Any]) -> Optional[ConditionResult]:
    if not symptoms.get("ear_pain_or_discharge") and not symptoms.get("mastoid_swelling"):
        return None

    if symptoms.get("mastoid_swelling"):
        return ConditionResult(
            name="ear problem",
            classification="MASTOIDITIS",
            flag="red",
            reasonTrace=["mastoid swelling present"],
        )

    return ConditionResult(
        name="ear problem",
        classification="ACUTE_EAR_INFECTION",
        flag="yellow",
        reasonTrace=["ear pain or discharge present, no mastoid swelling"],
    )


# ---------------------------------------------------------------------------
# Step 3: Aggregation — Worst Flag Wins
# ---------------------------------------------------------------------------

def classify(triage_input: Dict[str, Any]) -> TriageResult:
    patient = triage_input.get("patient", {})
    vitals = triage_input.get("vitals", {})
    symptoms = triage_input.get("symptoms", {})

    danger_signs = check_general_danger_signs(symptoms)

    # Young infant (<2 months) catch-all — §3.2
    age_m = patient.get("age_months")
    if age_m is not None and age_m < 2 and not danger_signs:
        def _is_positive(v):
            if isinstance(v, bool):
                return v is True
            if isinstance(v, (int, float)):
                return v > 0
            if isinstance(v, str):
                return v not in ("immediate", "normal")
            return False

        has_any_positive = any(_is_positive(v) for v in symptoms.values())
        if has_any_positive:
            danger_signs.append("young infant (<2mo) with positive symptom")

    conditions = [
        classify_pneumonia(patient, vitals, symptoms),
        classify_diarrhoea(patient, vitals, symptoms),
        classify_fever(patient, vitals, symptoms),
        classify_ear_problem(patient, vitals, symptoms),
    ]
    conditions = [c for c in conditions if c is not None]

    flag: str = "red" if danger_signs else "green"

    trace: List[str] = [
        f"general danger signs: {', '.join(danger_signs)}" if danger_signs else "general danger signs: none present"
    ]

    for c in conditions:
        if FLAG_RANK.get(c.flag, 0) > FLAG_RANK.get(flag, 0):
            flag = c.flag
        trace.append(f"{c.name}: {'; '.join(c.reasonTrace)} -> {c.classification} ({c.flag})")

    # Fail-safe: if nothing fired and no data was entered -> YELLOW
    if not conditions and not danger_signs:
        def _is_positive(v):
            if isinstance(v, bool):
                return v is True
            if isinstance(v, (int, float)):
                return v > 0
            if isinstance(v, str):
                return v not in ("immediate", "normal")
            return False

        has_any_symptom = any(_is_positive(v) for v in symptoms.values())
        if not has_any_symptom:
            flag = "yellow"
            trace.append("insufficient data entered -> defaulting to YELLOW, complete assessment manually")

    return TriageResult(flag=flag, conditions=conditions, rule_trace=trace, override_reason=None)


# ---------------------------------------------------------------------------
# Referral Note Generator (ported from referralNote.ts)
# ---------------------------------------------------------------------------

def generate_referral_note_engine(triage_input: Dict[str, Any], result: TriageResult) -> str:
    age_m = triage_input.get("patient", {}).get("age_months", 0)
    if age_m is None:
        age_label = "child"
    elif age_m < 12:
        age_label = f"{age_m}-month-old"
    else:
        age_label = f"{int(age_m // 12)}-year-old"

    sorted_conditions = sorted(result.conditions, key=lambda c: FLAG_RANK.get(c.flag, 0), reverse=True)
    worst = sorted_conditions[0] if sorted_conditions else None
    condition_label = worst.classification.replace("_", " ").lower() if worst else "danger sign(s)"

    findings: List[str] = []
    vitals = triage_input.get("vitals", {})
    symptoms = triage_input.get("symptoms", {})

    if vitals.get("resp_rate_bpm"):
        findings.append(f"fast breathing ({vitals['resp_rate_bpm']}/min)")
    if symptoms.get("chest_indrawing"):
        findings.append("chest indrawing")
    if symptoms.get("stridor_calm_child"):
        findings.append("stridor in calm child")
    if symptoms.get("diarrhoea"):
        findings.append(f"diarrhoea {symptoms.get('diarrhoea_days') or '?'} days")
    if symptoms.get("blood_in_stool"):
        findings.append("blood in stool")
    if vitals.get("temp_c"):
        findings.append(f"fever {vitals['temp_c']}°C")
    if symptoms.get("stiff_neck"):
        findings.append("stiff neck")
    if symptoms.get("lethargic_or_unconscious"):
        findings.append("lethargic/unconscious")
    if symptoms.get("convulsions"):
        findings.append("convulsions")
    if symptoms.get("vomits_everything"):
        findings.append("vomits everything")
    if symptoms.get("not_able_to_drink_or_breastfeed"):
        findings.append("not able to drink/breastfeed")
    if symptoms.get("mastoid_swelling"):
        findings.append("mastoid swelling")
    if symptoms.get("ear_pain_or_discharge"):
        findings.append("ear pain or discharge")

    findings_str = ", ".join(findings) if findings else "clinical assessment pending"
    danger_note = "no danger signs" if result.rule_trace[0].endswith("none present") else "danger sign(s) present"
    urgency = "URGENTLY" if result.flag == "red" else "within 24h"

    return f"Suspected {condition_label} — {findings_str} in {age_label}, {danger_note}. Refer to PHC {urgency}."


# ---------------------------------------------------------------------------
# Adapter: NLP extracted fields -> TriageInput-shaped dict
# ---------------------------------------------------------------------------

def adapt_to_engine_input(extracted_fields: Dict[str, Any], temperature_f: Optional[float] = None) -> Dict[str, Any]:
    temp_c = None
    if temperature_f is not None:
        temp_c = round((temperature_f - 32.0) * (5.0 / 9.0), 1)
    elif extracted_fields.get("temperature_c") is not None:
        temp_c = extracted_fields["temperature_c"]
    elif extracted_fields.get("temperature_f") is not None:
        temp_c = round((extracted_fields["temperature_f"] - 32.0) * (5.0 / 9.0), 1)

    symptoms_list = extracted_fields.get("symptoms", []) or []

    def _has(key: str) -> bool:
        return key in symptoms_list

    diarrhoea_days = extracted_fields.get("diarrhoea_days") or (extracted_fields.get("fever_days") if _has("diarrhea") else 0)

    # Best-effort enum defaults; NLP cannot reliably distinguish these yet
    skin_pinch = "immediate"
    drinking = "normal"

    return {
        "patient": {
            "age_months": extracted_fields.get("age_months"),
        },
        "vitals": {
            "resp_rate_bpm": extracted_fields.get("respiratory_rate"),
            "temp_c": temp_c,
        },
        "symptoms": {
            "cough_or_difficulty_breathing": _has("cough") or _has("breathing") or _has("chest_indrawing"),
            "chest_indrawing": extracted_fields.get("has_chest_indrawing", False),
            "stridor_calm_child": False,
            "diarrhoea": _has("diarrhea"),
            "diarrhoea_days": diarrhoea_days,
            "blood_in_stool": extracted_fields.get("has_blood_in_stool", False),
            "restless_irritable": extracted_fields.get("has_restless_irritable", False),
            "sunken_eyes": extracted_fields.get("has_sunken_eyes", False),
            "skin_pinch": skin_pinch,
            "drinking": drinking,
            "fever_days": extracted_fields.get("fever_days") or 0,
            "stiff_neck": extracted_fields.get("has_stiff_neck", False),
            "not_able_to_drink_or_breastfeed": extracted_fields.get("has_unable_to_drink", False),
            "vomits_everything": extracted_fields.get("has_vomiting_everything", False),
            "convulsions": extracted_fields.get("has_convulsions", False),
            "lethargic_or_unconscious": extracted_fields.get("has_lethargy", False),
            "ear_pain_or_discharge": extracted_fields.get("has_ear_pain", False),
            "mastoid_swelling": extracted_fields.get("has_mastoid_swelling", False),
        },
    }


# ---------------------------------------------------------------------------
# Main entry point: evaluate_imci_rules
# ---------------------------------------------------------------------------

def evaluate_imci_rules(
    extracted_data: Dict[str, Any], patient_id: str = "P-101", language: str = "en"
) -> Dict[str, Any]:
    """
    Evaluates extracted clinical entities against the strict WHO IMCI / IMNCI
    decision-tree engine. Produces triage flag, per-condition classifications,
    rule trace, and formatted interface payloads.
    """
    fields = extracted_data.get("extracted_fields", {})

    # Adapter: NLP fields -> Engine input
    engine_input = adapt_to_engine_input(fields)

    # Core classification
    result = classify(engine_input)

    # Referral note (English canonical)
    referral_note = generate_referral_note_engine(engine_input, result)

    # Build English interface payload
    age_m = fields.get("age_months")
    rr = fields.get("respiratory_rate")
    fever_days = fields.get("fever_days", 0)

    triage_level = result.flag.upper()
    conditions = result.conditions
    rule_trace = result.rule_trace

    worst_condition = None
    if conditions:
        worst_condition = sorted(conditions, key=lambda c: FLAG_RANK.get(c.flag, 0), reverse=True)[0]

    # Determine diagnosis/urgency/actions from worst condition or danger-sign fallback
    if worst_condition:
        diagnosis = worst_condition.classification.replace("_", " ")
    elif result.flag == "red":
        diagnosis = "SEVERE PNEUMONIA / VERY SEVERE DISEASE"
    elif result.flag == "yellow":
        diagnosis = "PNEUMONIA FAST BREATHING"
    else:
        diagnosis = "NO PNEUMONIA / MILD ILLNESS"

    urgency_map = {
        "red": "URGENT HOSPITAL REFERRAL",
        "yellow": "REFER TO PHC WITHIN 24 HOURS",
        "green": "HOME CARE",
    }
    urgency = urgency_map.get(result.flag, "HOME CARE")

    primary_danger = rule_trace[0].replace("general danger signs: ", "") if rule_trace else "None"

    actions = []
    if worst_condition:
        if worst_condition.name == "pneumonia":
            if result.flag == "red":
                actions = [
                    "Give first dose of appropriate oral antibiotic before transfer",
                    "Keep child warm during transport",
                    "Refer IMMEDIATELY to nearest hospital / First Referral Unit (FRU)",
                ]
            else:
                actions = [
                    "Give oral Amoxicillin for 5 days",
                    "Soothe throat and relieve cough with safe remedy",
                    "Advise mother when to return immediately if signs worsen",
                    "Refer to Primary Health Centre (PHC)",
                ]
        elif worst_condition.name == "diarrhoea":
            actions = [
                "Give extra fluid (ORS solution & Zinc supplement for 14 days)",
                "Continue feeding child",
                "Advise when to return immediately",
            ]
        elif worst_condition.name == "fever":
            if result.flag == "red":
                actions = ["Refer IMMEDIATELY to hospital for meningitis assessment", "Keep child warm", "Monitor breathing"]
            elif fever_days >= 7:
                actions = [
                    "Perform RDT test for Malaria if available",
                    "Give Paracetamol for high fever (≥38.5°C)",
                    "Refer to PHC for evaluation",
                ]
            else:
                actions = [
                    "Give Paracetamol for fever",
                    "Ensure adequate hydration",
                    "Follow up in 2 days if fever persists",
                ]
        elif worst_condition.name == "ear problem":
            actions = [
                "Refer to PHC for ear examination",
                "Keep ear dry",
                "Advise when to return immediately",
            ]
    if not actions:
        actions = ["Soothe throat with home remedy", "Advise mother when to return if signs worsen"]

    # 10-Second TTS Audio Script
    age_str = f"{age_m}-month-old" if age_m is not None else "child"
    rr_str = f"RR {rr}" if rr is not None else "normal breathing"
    tts_script = f"{triage_level} Alert. {patient_id}, {age_str} with {primary_danger}, {rr_str}. Diagnosis: {diagnosis}. Action: {urgency}."

    # 140-Character SMS Snippet
    sms_text = f"[{triage_level}] {patient_id} | Age:{age_m or 'N/A'}m | {primary_danger} | RR:{rr or 'N/A'} | Action:{urgency[:20]}"[:140]

    # WhatsApp Deep-Link URL
    encoded_text = urllib.parse.quote(
        f"*EMERGENCY TELE-TRIAGE REFERRAL*\n\n*Patient ID:* {patient_id}\n*Severity:* {triage_level}\n*Diagnosis:* {diagnosis}\n*Vitals:* Age {age_m or 'N/A'}m, RR {rr or 'N/A'}, Fever {fever_days}d\n*Danger Sign:* {primary_danger}\n*Action Required:* {urgency}"
    )
    whatsapp_url = f"https://api.whatsapp.com/send?text={encoded_text}"

    result_payload: Dict[str, Any] = {
        "patient_id": patient_id,
        "language": language,
        "triage_level": triage_level,
        "diagnosis": diagnosis,
        "urgency": urgency,
        "primary_danger": primary_danger,
        "actions": actions,
        "is_fast_breathing": any(c.name == "pneumonia" and "fast breathing" in "; ".join(c.reasonTrace).lower() for c in conditions),
        "general_danger_signs": check_general_danger_signs(engine_input.get("symptoms", {})),
        "conditions": [c.to_dict() for c in conditions],
        "rule_trace": rule_trace,
        "tts_script": tts_script,
        "sms_snippet": sms_text,
        "whatsapp_url": whatsapp_url,
        "referral_note": referral_note,
    }

    # --- Localized variants (Hindi today; English fallback otherwise) ---
    if language in LOCALIZATION:
        loc_danger = _tr(primary_danger, language, "danger")
        loc_diagnosis = _tr(diagnosis, language, "diagnosis")
        loc_urgency = _tr(urgency, language, "urgency")
        loc_actions = [_tr(a, language, "action") for a in actions]
        loc_age = f"{age_m} महीने का" if age_m is not None else "बच्चा"
        loc_rr = f"सांस {rr}" if rr is not None else "सामान्य सांस"

        tts_script_local = f"{triage_level} अलर्ट। {patient_id}, {loc_age} {loc_danger}, {loc_rr}। निदान: {loc_diagnosis}। कार्रवाई: {loc_urgency}।"
        sms_local = f"[{triage_level}] {patient_id} | उम्र:{age_m or 'N/A'}m | {loc_danger} | सांस:{rr or 'N/A'} | कार्रवाई:{loc_urgency[:20]}"[:140]
        encoded_local = urllib.parse.quote(
            f"*आपातकालीन टेली-ट्राइज रेफरल*\n\n*रोगी ID:* {patient_id}\n*गंभीरता:* {triage_level}\n*निदान:* {loc_diagnosis}\n*वाइटल:* उम्र {age_m or 'N/A'}m, सांस {rr or 'N/A'}, बुखार {fever_days}d\n*खतरे का लक्षण:* {loc_danger}\n*आवश्यक कार्रवाई:* {loc_urgency}"
        )

        result_payload.update({
            "tts_lang": "hi-IN",
            "tts_script_local": tts_script_local,
            "diagnosis_local": loc_diagnosis,
            "urgency_local": loc_urgency,
            "primary_danger_local": loc_danger,
            "actions_local": loc_actions,
            "sms_snippet_local": sms_local,
            "whatsapp_url_local": f"https://api.whatsapp.com/send?text={encoded_local}",
        })

    return result_payload
