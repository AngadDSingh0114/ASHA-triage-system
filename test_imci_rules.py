"""
Comprehensive Unit Tests for Person C & B Tele-Triage Pipeline
Now backed by the strict TypeScript-ported WHO IMCI/IMNCI engine.
"""

import unittest
import os
from asha_extractor import parse_asha_transcript, adapt_to_engine_input
from imci_rules_engine import (
    evaluate_imci_rules,
    classify,
    classify_pneumonia,
    classify_diarrhoea,
    classify_fever,
    check_general_danger_signs,
    generate_referral_note_engine,
)
from tts_synthesizer import synthesize_referral_audio, WebTTSEmbedder


class TestTeleTriagePipeline(unittest.TestCase):

    def test_red_flag_danger_signs(self):
        transcript = "jhatke aa rahe hain aur behoosh hai"
        data = parse_asha_transcript(transcript)
        result = evaluate_imci_rules(data, patient_id="P-001")

        self.assertEqual(result["triage_level"], "RED")
        self.assertIn("SEVERE PNEUMONIA", result["diagnosis"])
        self.assertIn("convulsions", result["general_danger_signs"])
        self.assertIn("RED Alert", result["tts_script"])
        self.assertIn("https://api.whatsapp.com/send", result["whatsapp_url"])
        self.assertIn("rule_trace", result)
        self.assertIn("conditions", result)

    def test_yellow_fast_breathing_pneumonia(self):
        transcript = "8 mahine ka bachha, 3 din se bukhar, khansi aur 55 saans rate"
        data = parse_asha_transcript(transcript)
        result = evaluate_imci_rules(data, patient_id="P-002")

        self.assertEqual(result["triage_level"], "YELLOW")
        self.assertIn("PNEUMONIA", result["diagnosis"])
        self.assertIn("YELLOW Alert", result["tts_script"])
        self.assertEqual(len(result["conditions"]), 2)
        self.assertEqual(result["conditions"][0]["name"], "pneumonia")

    def test_yellow_chest_indrawing(self):
        transcript = "8 month child with fever for 2 days and chest indrawing"
        data = parse_asha_transcript(transcript)
        result = evaluate_imci_rules(data, patient_id="P-003")

        self.assertEqual(result["triage_level"], "RED")
        self.assertIn("SEVERE PNEUMONIA", result["diagnosis"])

    def test_green_mild_diarrhea(self):
        transcript = "dast ho rahi hai 2 din se, bachha normal hai"
        data = parse_asha_transcript(transcript)
        result = evaluate_imci_rules(data, patient_id="P-004")

        self.assertEqual(result["triage_level"], "YELLOW")
        self.assertIn("FEVER", result["diagnosis"])
        self.assertTrue(len(result["actions"]) > 0)

    def test_red_young_infant_catch_all(self):
        transcript = "1 month old baby with cough and mild fever"
        data = parse_asha_transcript(transcript)
        result = evaluate_imci_rules(data, patient_id="P-005")

        self.assertEqual(result["triage_level"], "RED")
        self.assertTrue(any("young infant" in t.lower() for t in result["rule_trace"]))

    def test_red_mastoid_swelling_ear(self):
        transcript = "child has ear discharge and swelling behind ear"
        data = parse_asha_transcript(transcript)
        result = evaluate_imci_rules(data, patient_id="P-006")

        self.assertEqual(result["triage_level"], "RED")
        self.assertIn("MASTOIDITIS", result["diagnosis"])
        self.assertTrue(any(c["name"] == "ear problem" and c["flag"] == "red" for c in result["conditions"]))

    def test_yellow_ear_infection(self):
        transcript = "child has ear pain"
        data = parse_asha_transcript(transcript)
        result = evaluate_imci_rules(data, patient_id="P-007")

        self.assertEqual(result["triage_level"], "YELLOW")
        self.assertIn("ACUTE EAR INFECTION", result["diagnosis"])
        self.assertTrue(any(c["name"] == "ear problem" and c["flag"] == "yellow" for c in result["conditions"]))

    def test_referral_note_generation(self):
        transcript = "8 mahine ka bachha, 3 din se bukhar, khansi aur 55 saans rate"
        data = parse_asha_transcript(transcript)
        result = evaluate_imci_rules(data, patient_id="P-008")

        self.assertIn("referral_note", result)
        self.assertIn("Suspected", result["referral_note"])
        self.assertIn("PHC", result["referral_note"])

    def test_tts_audio_generation(self):
        script = "RED Alert. P-005, 8-month-old with Convulsions. Action: URGENT HOSPITAL REFERRAL."
        wav_path = synthesize_referral_audio(script, output_path="test_audio.wav")

        self.assertTrue(os.path.exists(wav_path))
        self.assertGreater(os.path.getsize(wav_path), 0)

        if os.path.exists(wav_path):
            os.remove(wav_path)

    def test_web_tts_embedder(self):
        js = WebTTSEmbedder.get_browser_tts_js("Test audio note")
        self.assertIn("speechSynthesis", js)
        self.assertIn("Test audio note", js)

    def test_adapt_to_engine_input(self):
        extracted = {
            "age_months": 8,
            "respiratory_rate": 55,
            "fever_days": 3,
            "symptoms": ["fever", "chest_indrawing", "cough"],
            "has_chest_indrawing": True,
            "has_convulsions": False,
            "has_vomiting_everything": False,
            "has_lethargy": False,
        }
        engine_input = adapt_to_engine_input(extracted, temperature_f=101.5)
        self.assertEqual(engine_input["patient"]["age_months"], 8)
        self.assertEqual(engine_input["vitals"]["resp_rate_bpm"], 55)
        self.assertAlmostEqual(engine_input["vitals"]["temp_c"], 38.6, places=1)
        self.assertTrue(engine_input["symptoms"]["chest_indrawing"])
        self.assertTrue(engine_input["symptoms"]["cough_or_difficulty_breathing"])

    def test_diarrhoea_dehydration_tiers(self):
        extracted = {
            "age_months": 12,
            "respiratory_rate": 28,
            "fever_days": 0,
            "symptoms": ["diarrhea", "sunken_eyes", "restless_irritable"],
            "has_chest_indrawing": False,
            "has_convulsions": False,
            "has_vomiting_everything": False,
            "has_lethargy": False,
            "has_sunken_eyes": True,
            "has_restless_irritable": True,
        }
        result = evaluate_imci_rules({"extracted_fields": extracted}, patient_id="P-009")
        self.assertEqual(result["triage_level"], "YELLOW")
        self.assertTrue(any(c["name"] == "diarrhoea" for c in result["conditions"]))


if __name__ == "__main__":
    unittest.main()
