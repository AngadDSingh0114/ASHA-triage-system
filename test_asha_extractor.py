"""
Unit Tests for ASHA Transcript Parser & Referral Note Generator
"""

import unittest
from asha_extractor import parse_asha_transcript, generate_referral_note


class TestASHAExtractor(unittest.TestCase):

    def test_1_full_hinglish_phrase(self):
        transcript = "8 mahine ka bachha, 3 din se bukhar aur 55 saans rate"
        res = parse_asha_transcript(transcript)

        fields = res["extracted_fields"]
        self.assertEqual(fields["age_months"], 8)
        self.assertEqual(fields["fever_days"], 3)
        self.assertEqual(fields["respiratory_rate"], 55)
        self.assertIn("fever", fields["symptoms"])
        self.assertGreater(res["extraction_confidence"], 0.5)

    def test_2_english_audio_transcription(self):
        transcript = "8 month child with fever for 2 days and chest indrawing"
        res = parse_asha_transcript(transcript)

        fields = res["extracted_fields"]
        self.assertEqual(fields["age_months"], 8)
        self.assertEqual(fields["fever_days"], 2)
        self.assertTrue(fields["has_chest_indrawing"])
        self.assertIn("chest_indrawing", fields["symptoms"])

        note = generate_referral_note(res, "YELLOW_PHC")
        self.assertIn("Suspected pneumonia", note)
        self.assertIn("Refer to PHC within 24 hours", note)

    def test_3_partial_input_missing_vitals(self):
        transcript = "dast aur ulti ho rahi hai 2 din se"
        res = parse_asha_transcript(transcript)

        fields = res["extracted_fields"]
        self.assertIsNone(fields["age_months"])
        self.assertIsNone(fields["respiratory_rate"])
        self.assertTrue(fields["has_vomiting"])
        self.assertIn("diarrhea", fields["symptoms"])
        self.assertIn("vomiting", fields["symptoms"])

    def test_4_severe_danger_signs(self):
        transcript = "jhatke aa rahe hain aur behoosh hai"
        res = parse_asha_transcript(transcript)

        fields = res["extracted_fields"]
        self.assertTrue(fields["has_convulsions"])
        self.assertTrue(fields["has_lethargy"])
        self.assertIn("convulsions", fields["symptoms"])
        self.assertIn("lethargy", fields["symptoms"])

        note = generate_referral_note(res, "RED_URGENT")
        self.assertIn("Severe illness / Danger signs present", note)
        self.assertIn("Refer IMMEDIATELY", note)

    def test_5_edge_case_with_noise(self):
        transcript = "hello micro check 1 2 3 random noise fast test no symptoms"
        res = parse_asha_transcript(transcript)

        fields = res["extracted_fields"]
        self.assertIsNone(fields["age_months"])
        self.assertIsNone(fields["respiratory_rate"])
        self.assertFalse(fields["has_chest_indrawing"])
        self.assertFalse(fields["has_convulsions"])
        self.assertEqual(len(fields["symptoms"]), 0)


if __name__ == "__main__":
    unittest.main()
