"""
Unit Tests for ASHA Transcript Parser & Referral Note Generator (multilingual)
"""

import unittest
from asha_extractor import parse_asha_transcript, generate_referral_note, detect_language


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

    # ------------------------------------------------------------------
    # Multilingual coverage
    # ------------------------------------------------------------------
    def test_6_tamil_fever_fast_breathing(self):
        transcript = "8 maadham kuzhanthai, 3 naal kaaychal, 55 uyir kaa"  # age/fever + RR
        res = parse_asha_transcript(transcript)
        self.assertEqual(res["language"], "ta")
        self.assertIn("fever", res["extracted_fields"]["symptoms"])

    def test_7_telugu_chest_indrawing(self):
        transcript = "chaati padipovadam undi, 4 roju nunchi jvaram"
        res = parse_asha_transcript(transcript)
        self.assertIn("chest_indrawing", res["extracted_fields"]["symptoms"])
        self.assertIn("fever", res["extracted_fields"]["symptoms"])

    def test_8_bengali_convulsions_lethargy(self):
        transcript = "khichuni hocche ar chele ta ochchhonna"
        res = parse_asha_transcript(transcript)
        self.assertIn("convulsions", res["extracted_fields"]["symptoms"])
        self.assertIn("lethargy", res["extracted_fields"]["symptoms"])

    def test_9_marathi_diarrhea_vomiting(self):
        transcript = "atisar ani ulti 2 divas pasun"
        res = parse_asha_transcript(transcript)
        self.assertIn("diarrhea", res["extracted_fields"]["symptoms"])
        self.assertIn("vomiting", res["extracted_fields"]["symptoms"])

    def test_10_kannada_language_detection(self):
        transcript = "bane jvara mattu vanti ide"
        self.assertEqual(detect_language(transcript), "kn")

    def test_11_malayalam_detection(self):
        transcript = "kuttikk panni matram chardhi onnu"
        self.assertEqual(detect_language(transcript), "ml")

    def test_12_multilingual_age_in_years(self):
        transcript = "2 varusham child ku bukhar 4 days"
        res = parse_asha_transcript(transcript)
        self.assertEqual(res["extracted_fields"]["age_months"], 24)
        self.assertEqual(res["extracted_fields"]["fever_days"], 4)

    def test_13_hindi_localized_referral_note(self):
        transcript = "8 mahine ka bachha, 3 din se bukhar aur 55 saans rate"
        res = parse_asha_transcript(transcript)
        note = generate_referral_note(res, "YELLOW_PHC", lang="hi")
        self.assertIn("निमोनिया", note)
        self.assertIn("PHC", note)


if __name__ == "__main__":
    unittest.main()
