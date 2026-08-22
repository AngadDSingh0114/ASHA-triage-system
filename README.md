# ASHA Tele-Triage System (WHO IMCI Protocol)

> **Offline-first AI Tele-Triage Companion for ASHA / PHC Healthcare Workers in Rural India**  
> Speech-to-Text & Symptom Entity Extraction Engine, WHO IMCI Decision-Tree Classifier, 10-Second TTS Audio Synthesizer, and Emergency WhatsApp/SMS Referral Dispatch.

---

## 🌟 Overview

In rural primary healthcare, frontline ASHA workers need fast, deterministic, offline triage tools to assess pediatric illness under WHO IMCI (Integrated Management of Childhood Illness) guidelines.

This project delivers **Person C's Speech-to-Text & Symptom Extraction Layer** integrated with **Person B's strict WHO IMCI/IMNCI decision-tree engine** (ported from TypeScript), providing:
1. **Multilingual Speech Recognition & Rule-Based Entity Extractor**: Parses raw speech transcripts in **Hindi, Hinglish, English, Tamil, Telugu, Bengali, Marathi, Kannada, Malayalam, Gujarati, Punjabi, Odia, and Urdu** into structured clinical JSON data, with automatic language detection and number-word/digit understanding.
2. **Strict WHO IMCI/IMNCI Decision-Tree Engine**: Evaluates age-banded respiratory thresholds, dehydration tiers, ear-problem classifications, and general danger signs to assign triage levels (**RED - Hospital Referral**, **YELLOW - PHC Clinic**, **GREEN - Home Care**). Outputs per-condition `classifications`, `rule_trace[]`, and `referral_note`.
3. **NLP-to-Engine Adapter**: Converts extracted NLP fields into engine-ready input, including temperature conversion (F→C), symptom normalization, and default handling for missing vitals.
4. **10-Second TTS Audio Summary Synthesizer**: Generates synthesized audio briefs for PHC doctors to listen instantly on mobile.
5. **1-Tap WhatsApp & SMS Emergency Dispatch**: Pre-formats compact 140-character emergency SMS text and deep-linked WhatsApp messages.

---

## 📁 Repository Structure

```text
.
├── asha_extractor.py       # Entity Extractor & Regional Hindi/Hinglish Thesaurus + adapt_to_engine_input()
├── imci_rules_engine.py    # WHO IMCI Decision-Tree Rules Engine (ported from TypeScript)
├── tts_synthesizer.py      # On-Device Text-to-Speech (TTS) Synthesizer
├── server.py               # Zero-dependency HTTP backend serving /api/parse, /api/sync, /api/records
├── index.html              # Standalone Offline Interactive ASHA Dashboard UI (calls /api/parse)
├── lib/
│   ├── models/
│   │   └── patient_triage_model.dart   # Flutter model with ported TriageResult.evaluate()
│   └── services/
│       └── asha_nlp_extractor.dart     # Expanded Dart NLP service with new symptom fields
├── test_asha_extractor.py  # Unit Tests for Entity Extractor
├── test_imci_rules.py     # Unit Tests for Rules Engine & Full Pipeline
└── README.md               # Documentation
```

---

## 🚀 Quick Start & Usage

### 1. Run Interactive Dashboard (Web UI)
Start the Python backend and open the dashboard:
```bash
python server.py
# Open http://localhost:8000/index.html
```
Features:
- Live Speech-to-Text microphone input (multilingual; Hindi/Hinglish default).
- Real-time vitals slot-filling & extraction confidence score.
- Automatic language detection with color-coded WHO IMCI triage card and specific clinical protocol guidelines.
- Per-condition classifications and rule trace log from the strict decision-tree engine.
- 1-Click 10-second audio summary player (localized script when a translation pack exists).
- 1-Tap WhatsApp referral sharing button (localized message where available).

### 2. Run Python Core & Automated Tests
Execute the unit test suite across clinical test cases:
```bash
python -m unittest test_imci_rules.py test_asha_extractor.py
```

### 3. Example Code Usage
```python
from asha_extractor import parse_asha_transcript
from imci_rules_engine import evaluate_imci_rules, adapt_to_engine_input

transcript = "8 mahine ka bachha, 3 din se bukhar aur 55 saans rate"

# 1. Parse Entity Slots
extracted = parse_asha_transcript(transcript)

# 2. Evaluate WHO IMCI Triage Rules
result = evaluate_imci_rules(extracted, patient_id="P-101")

print("Triage Level:", result["triage_level"])      # YELLOW
print("Diagnosis:", result["diagnosis"])            # PNEUMONIA
print("Conditions:", result["conditions"])          # [{'name': 'pneumonia', 'flag': 'yellow', ...}]
print("Rule Trace:", result["rule_trace"])          # ['general danger signs: none present', ...]
print("Referral Note:", result["referral_note"])    # Suspected pneumonia — fast breathing (55/min) in 8-month-old, no danger signs. Refer to PHC within 24h.
print("10s TTS Script:", result["tts_script"])      # YELLOW Alert. P-101, 8-month-old with No acute danger signs, RR 55. Diagnosis: PNEUMONIA. Action: REFER TO PHC WITHIN 24 HOURS.
```

---

## 🧪 Verified Test Scenarios

- **Test 1 (Full Hinglish)**: `"8 mahine ka bachha, 3 din se bukhar aur 55 saans rate"` -> Pneumonia (Fast Breathing: RR 55) -> `YELLOW`
- **Test 2 (Chest Indrawing)**: `"8 month child with fever for 2 days and chest indrawing"` -> Severe Pneumonia (Chest Indrawing) -> `RED`
- **Test 3 (Mild Diarrhea)**: `"dast ho rahi hai 2 din se, bachha normal hai"` -> Gastroenteritis + Fever -> `YELLOW`
- **Test 4 (Severe Danger Sign)**: `"jhatke aa rahe hain aur behoosh hai"` -> Severe Disease (Convulsions & Lethargy) -> `RED` (Urgent Referral)
- **Test 5 (Young Infant Catch-All)**: `"1 month old baby with cough and mild fever"` -> Young infant (<2mo) with positive symptom -> `RED`
- **Test 6 (Mastoid Swelling)**: `"child has ear discharge and swelling behind ear"` -> Mastoiditis -> `RED`
- **Test 7 (Ear Infection)**: `"child has ear pain"` -> Acute Ear Infection -> `YELLOW`
- **Test 8 (Diarrhea Dehydration)**: `"diarrhea, sunken eyes, restless irritable"` -> Some Dehydration -> `YELLOW`
- **Test 9 (Noise Edge Case)**: Random noise / unexpected words handled gracefully with default null fallbacks.

---

## 🔧 Architecture: NLP → Engine Integration

```
Raw Transcript (13 languages)
        │
        ▼
  asha_extractor.py (NLP)
  - Language detection
  - Symptom entity extraction
  - Vitals slot-filling
        │
        ▼
  adapt_to_engine_input()
  - Maps NLP fields → Engine schema
  - Converts temperature F → C
  - Normalizes symptom names
        │
        ▼
  imci_rules_engine.py (Strict Decision Tree)
  - check_general_danger_signs()
  - classify_pneumonia()
  - classify_diarrhoea()
  - classify_fever()
  - classify_ear_problem()
  - Worst-flag-wins aggregation
  - generate_referral_note_engine()
        │
        ▼
  TriageResult
  - triage_level (RED/YELLOW/GREEN)
  - conditions[] with classification, flag, reasonTrace
  - rule_trace[]
  - referral_note
  - tts_script, sms_snippet, whatsapp_url
```

---

## 🌐 Multilingual Coverage

The entity extractor matches symptom terms across 13 languages via a transparent, transliterated thesaurus (`SYMPTOM_TERMS` in `asha_extractor.py`). Language is auto-detected (`detect_language`) and carried through the pipeline. Localized referral outputs (TTS / SMS / WhatsApp) are fully generated for **Hindi** today; other detected languages fall back to English while the detected language is recorded for future translation packs. Unit tests cover Tamil, Telugu, Bengali, Marathi, Kannada, and Malayalam transcripts.

### Expanded Symptom Fields
New fields added to NLP extractor and engine:
- `blood_in_stool`, `sunken_eyes`, `unable_to_drink`, `stiff_neck`
- `ear_pain`, `mastoid_swelling`, `restless_irritable`
- `cough`, `breathing_difficulty`

> Note: Transliterated terms are best-effort and should be reviewed by native speakers before field deployment.

---

## 📜 License
MIT License. Developed for pediatric tele-triage hackathon initiative.
