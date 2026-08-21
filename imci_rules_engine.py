"""
WHO IMCI Decision-Tree Rules Engine & Referral Formatter
Person B & C Core Integration Layer.
"""

from typing import Dict, Any, List
import urllib.parse


def evaluate_imci_rules(extracted_data: Dict[str, Any], patient_id: str = "P-101") -> Dict[str, Any]:
    """
    Evaluates extracted clinical entities against WHO IMCI decision trees.
    Produces triage level, clinical actions, 10s TTS script, and SMS/WhatsApp payload.
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

    # --- PERSON B & C FORMATTERS ---
    # 1. 10-Second TTS Audio Script
    age_str = f"{age_m}-month-old" if age_m is not None else "child"
    rr_str = f"RR {rr}" if rr is not None else "normal breathing"
    tts_script = f"{triage_level} Alert. {patient_id}, {age_str} with {primary_danger}, {rr_str}. Diagnosis: {diagnosis}. Action: {urgency}."

    # 2. 140-Character SMS Snippet
    sms_text = f"[{triage_level}] {patient_id} | Age:{age_m or 'N/A'}m | {primary_danger} | RR:{rr or 'N/A'} | Action:{urgency[:20]}"[:140]

    # 3. WhatsApp Deep-Link URL
    encoded_text = urllib.parse.quote(f"*EMERGENCY TELE-TRIAGE REFERRAL*\n\n*Patient ID:* {patient_id}\n*Severity:* {triage_level}\n*Diagnosis:* {diagnosis}\n*Vitals:* Age {age_m or 'N/A'}m, RR {rr or 'N/A'}, Fever {fever_days}d\n*Danger Sign:* {primary_danger}\n*Action Required:* {urgency}")
    whatsapp_url = f"https://api.whatsapp.com/send?text={encoded_text}"

    return {
        "patient_id": patient_id,
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
