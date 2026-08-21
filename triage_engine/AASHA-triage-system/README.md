# ASHA Tele-Triage System (WHO IMCI Protocol)

> **Offline-first AI Tele-Triage Companion for ASHA / PHC Healthcare Workers in Rural India**  
> Speech-to-Text & Symptom Entity Extraction Engine, WHO IMCI Rules Classifier, 10-Second TTS Audio Synthesizer, and Emergency WhatsApp/SMS Referral Dispatch.

---

## 🌟 Overview

In rural primary healthcare, frontline ASHA workers need fast, deterministic, offline triage tools to assess pediatric illness under WHO IMCI (Integrated Management of Childhood Illness) guidelines.

This project delivers **Person C's Speech-to-Text & Symptom Extraction Layer** integrated with **Person B's WHO IMCI Rules Engine**, providing:
1. **Multilingual Speech Recognition & Rule-Based Entity Extractor**: Parses raw speech transcripts in **Hindi, Hinglish, English, Tamil, Telugu, Bengali, Marathi, Kannada, Malayalam, Gujarati, Punjabi, Odia, and Urdu** into structured clinical JSON data, with automatic language detection and number-word/digit understanding.
2. **Deterministic WHO IMCI Rules Engine**: Evaluates age-banded respiratory thresholds and general danger signs to assign triage levels (**RED - Hospital Referral**, **YELLOW - PHC Clinic**, **GREEN - Home Care**).
3. **10-Second TTS Audio Summary Synthesizer**: Generates synthesized audio briefs for PHC doctors to listen instantly on mobile.
4. **1-Tap WhatsApp & SMS Emergency Dispatch**: Pre-formats compact 140-character emergency SMS text and deep-linked WhatsApp messages.

---

## 📁 Repository Structure

```text
.
├── asha_extractor.py       # Entity Extractor & Regional Hindi/Hinglish Thesaurus
├── imci_rules_engine.py    # WHO IMCI Decision-Tree Rules Engine & Formatters
├── tts_synthesizer.py      # On-Device Text-to-Speech (TTS) Synthesizer
├── index.html              # Standalone Offline Interactive ASHA Dashboard UI
├── test_asha_extractor.py  # Unit Tests for Entity Extractor
├── test_imci_rules.py     # Unit Tests for Rules Engine & Full Pipeline
└── README.md               # Documentation
```

---

## 🚀 Quick Start & Usage

### 1. Run Interactive Dashboard (Offline Web UI)
Open `index.html` in any web browser:
```bash
# Double-click index.html or open via browser
```
Features:
- Live Speech-to-Text microphone input (multilingual; Hindi/Hinglish default).
- Real-time vitals slot-filling & extraction confidence score.
- Automatic language detection with color-coded WHO IMCI triage card and specific clinical protocol guidelines.
- 1-Click 10-second audio summary player (localized script when a translation pack exists).
- 1-Tap WhatsApp referral sharing button (localized message where available).

### 2. Run Python Core & Automated Tests
Execute the unit test suite across clinical test cases:
```bash
python -m unittest test_imci_rules.py
```

### 3. Example Code Usage
```python
from asha_extractor import parse_asha_transcript
from imci_rules_engine import evaluate_imci_rules

transcript = "8 mahine ka bachha, 3 din se bukhar aur 55 saans rate"

# 1. Parse Entity Slots
extracted = parse_asha_transcript(transcript)

# 2. Evaluate WHO IMCI Triage Rules
result = evaluate_imci_rules(extracted, patient_id="P-101")

print("Triage Level:", result["triage_level"])  # YELLOW
print("Diagnosis:", result["diagnosis"])        # PNEUMONIA (Fast Breathing)
print("10s TTS Script:", result["tts_script"])  # YELLOW Alert. P-101...
```

---

## 🧪 Verified Test Scenarios

- **Test 1 (Full Hinglish)**: `"8 mahine ka bachha, 3 din se bukhar aur 55 saans rate"` -> Pneumonia (Fast Breathing: RR 55) -> `YELLOW`
- **Test 2 (English Speech)**: `"8 month child with fever for 2 days and chest indrawing"` -> Pneumonia (Chest Indrawing) -> `YELLOW`
- **Test 3 (Partial Input)**: `"dast aur ulti ho rahi hai 2 din se"` -> Gastroenteritis -> `GREEN` (Home Care ORS)
- **Test 4 (Severe Danger Sign)**: `"jhatke aa rahe hain aur behoosh hai"` -> Severe Disease (Convulsions & Lethargy) -> `RED` (Urgent Referral)
- **Test 5 (Noise Edge Case)**: Random noise / unexpected words handled gracefully with default null fallbacks.

### 🌐 Multilingual Coverage
The entity extractor matches symptom terms across 13 languages via a transparent, transliterated thesaurus (`SYMPTOM_TERMS` in `asha_extractor.py`). Language is auto-detected (`detect_language`) and carried through the pipeline. Localized referral outputs (TTS / SMS / WhatsApp) are fully generated for **Hindi** today; other detected languages fall back to English while the detected language is recorded for future translation packs. Unit tests cover Tamil, Telugu, Bengali, Marathi, Kannada, and Malayalam transcripts.

> Note: Transliterated terms are best-effort and should be reviewed by native speakers before field deployment.

---

## 📜 License
MIT License. Developed for pediatric tele-triage hackathon initiative.
