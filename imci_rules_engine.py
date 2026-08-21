"""
WHO IMCI Decision-Tree Rules Engine & Referral Formatter
Person B & C Core Integration Layer.

Now multilingual-aware: when a transcript language is detected (see asha_extractor),
localized referral fields are generated alongside the canonical English output so
the PHC doctor / ASHA worker can receive guidance in their own language. Hindi is
fully localized; other detected languages fall back to English with the detected
language recorded for future translation packs.
"""

from typing import Dict, Any, List
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


def evaluate_imci_rules(
    extracted_data: Dict[str, Any], patient_id: str = "P-101", language: str = "en"
) -> Dict[str, Any]:
    """
    Evaluates extracted clinical entities against WHO IMCI decision trees.
    Produces triage level, clinical actions, 10s TTS script, and SMS/WhatsApp payload.
    `language` carries the detected transcript language for localized outputs.
    """
    fields = extracted_data.get("extracted_fields", {})
    age_m = fields.get("age_months")
    rr = fields.get("respiratory_rate")
    fever_days = fields.get("fever_days", 0)

    has_chest_indrawing = fields.get("has_chest_indrawing", False)
    has_convulsions = fields.get("has_convulsions", False)
    has_vomiting_everything = fields.get("has_vomiting_everything", False)
    has_lethargy = fields.get("has_lethargy", False)
    symptoms = fields.get("symptoms", [])

    # General Danger Signs (WHO IMCI)
    general_danger_signs = []
    if has_convulsions:
        general_danger_signs.append("Convulsions")
    if has_lethargy:
        general_danger_signs.append("Lethargy/Unresponsiveness")
    if has_vomiting_everything:
        general_danger_signs.append("Vomiting Everything")

    # Fast Breathing Assessment
    is_fast_breathing = False
    if rr is not None:
        if age_m is not None and age_m < 2:
            is_fast_breathing = (rr >= 60)
        elif age_m is not None and 2 <= age_m < 12:
            is_fast_breathing = (rr >= 50)
        elif age_m is not None and age_m >= 12:
            is_fast_breathing = (rr >= 40)
        else:
            is_fast_breathing = (rr >= 50)

    # Classification Logic
    if general_danger_signs or (has_chest_indrawing and (age_m is not None and age_m < 2)):
        triage_level = "RED"
        diagnosis = "SEVERE PNEUMONIA / VERY SEVERE DISEASE"
        urgency = "URGENT HOSPITAL REFERRAL"
        actions = [
            "Give first dose of appropriate oral antibiotic before transfer",
            "Keep child warm during transport",
            "Refer IMMEDIATELY to nearest hospital / First Referral Unit (FRU)",
        ]
        primary_danger = general_danger_signs[0] if general_danger_signs else "Severe chest indrawing"
    elif has_chest_indrawing or is_fast_breathing:
        triage_level = "YELLOW"
        diagnosis = "PNEUMONIA (Fast Breathing)"
        urgency = "REFER TO PHC WITHIN 24 HOURS"
        actions = [
            "Give oral Amoxicillin for 5 days",
            "Soothe throat and relieve cough with safe remedy",
            "Advise mother when to return immediately if signs worsen",
            "Refer to Primary Health Centre (PHC)",
        ]
        primary_danger = "Chest indrawing" if has_chest_indrawing else f"Fast breathing ({rr}/min)"
    elif "diarrhea" in symptoms:
        triage_level = "YELLOW" if fever_days > 7 else "GREEN"
        diagnosis = "DIARRHEA / GASTROENTERITIS"
        urgency = "PHC CLINIC VISIT" if fever_days > 7 else "HOME CARE WITH ORS"
        actions = [
            "Give extra fluid (ORS solution & Zinc supplement for 14 days)",
            "Continue feeding child",
            "Advise when to return immediately",
        ]
        primary_danger = "Persistent diarrhea" if fever_days > 7 else "Acute diarrhea"
    elif "fever" in symptoms:
        if fever_days > 7:
            triage_level = "YELLOW"
            diagnosis = "FEVER - POSSIBLE MALARIA / TYPHOID"
            urgency = "REFER TO PHC FOR BLOOD TEST"
            actions = [
                "Perform RDT test for Malaria if available",
                "Give Paracetamol for high fever (≥38.5°C)",
                "Refer to PHC for evaluation",
            ]
            primary_danger = f"High fever ({fever_days} days)"
        else:
            triage_level = "GREEN"
            diagnosis = "FEVER - MILD ACUTE FEBRILE ILLNESS"
            urgency = "HOME CARE"
            actions = [
                "Give Paracetamol for fever",
                "Ensure adequate hydration",
                "Follow up in 2 days if fever persists",
            ]
            primary_danger = f"Mild fever ({fever_days} days)"
    else:
        triage_level = "GREEN"
        diagnosis = "NO PNEUMONIA / MILD ILLNESS"
        urgency = "HOME CARE"
        actions = [
            "Soothe throat with home remedy",
            "Advise mother when to return if signs worsen",
        ]
        primary_danger = "No acute danger signs"

    # --- PERSON B & C FORMATTERS (English canonical) ---
    # 1. 10-Second TTS Audio Script
    age_str = f"{age_m}-month-old" if age_m is not None else "child"
    rr_str = f"RR {rr}" if rr is not None else "normal breathing"
    tts_script = f"{triage_level} Alert. {patient_id}, {age_str} with {primary_danger}, {rr_str}. Diagnosis: {diagnosis}. Action: {urgency}."

    # 2. 140-Character SMS Snippet
    sms_text = f"[{triage_level}] {patient_id} | Age:{age_m or 'N/A'}m | {primary_danger} | RR:{rr or 'N/A'} | Action:{urgency[:20]}"[:140]

    # 3. WhatsApp Deep-Link URL
    encoded_text = urllib.parse.quote(f"*EMERGENCY TELE-TRIAGE REFERRAL*\n\n*Patient ID:* {patient_id}\n*Severity:* {triage_level}\n*Diagnosis:* {diagnosis}\n*Vitals:* Age {age_m or 'N/A'}m, RR {rr or 'N/A'}, Fever {fever_days}d\n*Danger Sign:* {primary_danger}\n*Action Required:* {urgency}")
    whatsapp_url = f"https://api.whatsapp.com/send?text={encoded_text}"

    result: Dict[str, Any] = {
        "patient_id": patient_id,
        "language": language,
        "triage_level": triage_level,
        "diagnosis": diagnosis,
        "urgency": urgency,
        "primary_danger": primary_danger,
        "actions": actions,
        "is_fast_breathing": is_fast_breathing,
        "general_danger_signs": general_danger_signs,
        "tts_script": tts_script,
        "sms_snippet": sms_text,
        "whatsapp_url": whatsapp_url,
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
        encoded_local = urllib.parse.quote(f"*आपातकालीन टेली-ट्राइज रेफरल*\n\n*रोगी ID:* {patient_id}\n*गंभीरता:* {triage_level}\n*निदान:* {loc_diagnosis}\n*वाइटल:* उम्र {age_m or 'N/A'}m, सांस {rr or 'N/A'}, बुखार {fever_days}d\n*खतरे का लक्षण:* {loc_danger}\n*आवश्यक कार्रवाई:* {loc_urgency}")

        result.update({
            "tts_lang": "hi-IN",
            "tts_script_local": tts_script_local,
            "diagnosis_local": loc_diagnosis,
            "urgency_local": loc_urgency,
            "primary_danger_local": loc_danger,
            "actions_local": loc_actions,
            "sms_snippet_local": sms_local,
            "whatsapp_url_local": f"https://api.whatsapp.com/send?text={encoded_local}",
        })

    return result
