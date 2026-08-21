"""
Comprehensive Unit Tests for Person C & B Tele-Triage Pipeline
"""

import unittest
import os
from asha_extractor import parse_asha_transcript
from imci_rules_engine import evaluate_imci_rules
from tts_synthesizer import synthesize_referral_audio, WebTTSEmbedder


class TestTeleTriagePipeline(unittest.TestCase):

    def test_red_flag_danger_signs(self):
        transcript = "jhatke aa rahe hain aur behoosh hai"
        data = parse_asha_transcript(transcript)
        result = evaluate_imci_rules(data, patient_id="P-001")

        self.assertEqual(result["triage_level"], "RED")
        self.assertEqual(result["diagnosis"], "SEVERE PNEUMONIA / VERY SEVERE DISEASE")
        self.assertIn("Convulsions", result["general_danger_signs"])
        self.assertIn("RED Alert", result["tts_script"])
        self.assertIn("https://api.whatsapp.com/send", result["whatsapp_url"])

    def test_yellow_fast_breathing_pneumonia(self):
        transcript = "8 mahine ka bachha, 3 din se bukhar aur 55 saans rate"
        data = parse_asha_transcript(transcript)
        result = evaluate_imci_rules(data, patient_id="P-002")

        self.assertEqual(result["triage_level"], "YELLOW")
        self.assertEqual(result["diagnosis"], "PNEUMONIA (Fast Breathing)")
        self.assertTrue(result["is_fast_breathing"])
        self.assertIn("YELLOW Alert", result["tts_script"])

    def test_yellow_chest_indrawing(self):
        transcript = "8 month child with fever for 2 days and chest indrawing"
        data = parse_asha_transcript(transcript)
        result = evaluate_imci_rules(data, patient_id="P-003")

        self.assertEqual(result["triage_level"], "YELLOW")
        self.assertEqual(result["diagnosis"], "PNEUMONIA (Fast Breathing)")

    def test_green_mild_diarrhea(self):
        transcript = "dast aur ulti ho rahi hai 2 din se"
        data = parse_asha_transcript(transcript)
        result = evaluate_imci_rules(data, patient_id="P-004")

        self.assertEqual(result["triage_level"], "GREEN")
        self.assertEqual(result["diagnosis"], "DIARRHEA / GASTROENTERITIS")
        self.assertIn("Give extra fluid (ORS solution & Zinc supplement for 14 days)", result["actions"])

    def test_tts_audio_generation(self):
        script = "RED Alert. P-005, 8-month-old with Convulsions. Action: URGENT HOSPITAL REFERRAL."
        wav_path = synthesize_referral_audio(script, output_path="test_audio.wav")

        self.assertTrue(os.path.exists(wav_path))
        self.assertGreater(os.path.getsize(wav_path), 0)

        # Cleanup
        if os.path.exists(wav_path):
            os.remove(wav_path)

    def test_web_tts_embedder(self):
        js = WebTTSEmbedder.get_browser_tts_js("Test audio note")
        self.assertIn("speechSynthesis", js)
        self.assertIn("Test audio note", js)


if __name__ == "__main__":
    unittest.main()
