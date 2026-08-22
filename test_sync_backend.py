"""
Comprehensive Unit Tests for Person D (Backend, Sync Queue & SQLite DB)
"""

import unittest
import os
import uuid
from local_db import LocalTriageDB
from server import CentralDBManager
from seed_data import GROUNDING_STATS, DEMO_PATIENT_SCENARIOS, CLINICAL_BENCHMARK_SCENARIOS, generate_benchmark_sync_payloads
from imci_rules_engine import evaluate_imci_rules


class TestBackendAndSync(unittest.TestCase):

    def setUp(self):
        self.test_id = uuid.uuid4().hex[:8]
        self.test_local_db_path = f"test_local_{self.test_id}.db"
        self.test_central_db_path = f"test_central_{self.test_id}.db"

        self.local_db = LocalTriageDB(self.test_local_db_path)
        self.central_db = CentralDBManager(self.test_central_db_path)

    def tearDown(self):
        for f in [self.test_local_db_path, self.test_central_db_path]:
            if os.path.exists(f):
                try:
                    os.remove(f)
                except Exception:
                    pass

    def test_local_db_offline_storage_and_queue(self):
        patient_info = {
            "patient_id": "P-TEST-01",
            "full_name": "Test Child",
            "age_months": 9,
            "gender": "M",
            "guardian_name": "Test Guardian",
            "village_name": "Test Village"
        }
        extracted = {
            "extracted_fields": {
                "age_months": 9,
                "respiratory_rate": 55,
                "temperature_c": 38.5,
                "fever_days": 2,
                "symptoms": ["fever", "chest_indrawing"],
                "has_chest_indrawing": True
            }
        }
        triage = evaluate_imci_rules(extracted, patient_id="P-TEST-01")
        
        res = self.local_db.record_triage_assessment(
            extracted_data=extracted,
            triage_result=triage,
            patient_info=patient_info
        )
        self.assertEqual(res["sync_status"], "PENDING")

        pending = self.local_db.get_pending_sync_records()
        self.assertEqual(len(pending), 1)
        self.assertEqual(pending[0]["patient"]["full_name"], "Test Child")
        self.assertEqual(pending[0]["assessment"]["triage_color"], "RED")

        self.local_db.mark_records_synced([res["assessment_id"]])
        pending_after = self.local_db.get_pending_sync_records()
        self.assertEqual(len(pending_after), 0)

    def test_central_server_batch_ingestion_and_priority_ordering(self):
        batch_payload = {
            "asha_id": "ASHA-MH-PUNE-012",
            "records": [
                {
                    "patient": {"patient_id": "P-GREEN", "full_name": "Green Child", "age_months": 18, "gender": "F"},
                    "assessment": {
                        "assessment_id": "ASS-G",
                        "triage_color": "GREEN",
                        "diagnosis": "Mild Cold",
                        "urgency": "Home Care",
                        "primary_danger": "None",
                        "referral_note": "Green referral note",
                        "assessed_at": "2026-08-21T10:00:00Z"
                    }
                },
                {
                    "patient": {"patient_id": "P-RED", "full_name": "Red Child", "age_months": 6, "gender": "M"},
                    "assessment": {
                        "assessment_id": "ASS-R",
                        "triage_color": "RED",
                        "diagnosis": "Severe Pneumonia",
                        "urgency": "URGENT HOSPITAL",
                        "primary_danger": "Convulsions",
                        "referral_note": "Red urgent note",
                        "assessed_at": "2026-08-21T10:05:00Z"
                    }
                }
            ]
        }

        synced_ids = self.central_db.ingest_batch(batch_payload)
        self.assertEqual(len(synced_ids), 2)

        records = self.central_db.get_triage_records()
        self.assertEqual(len(records), 2)
        self.assertEqual(records[0]["triage_color"], "RED")
        self.assertEqual(records[1]["triage_color"], "GREEN")

        success = self.central_db.acknowledge_record("ASS-R", "Doctor received patient at FRU")
        self.assertTrue(success)

        stats = self.central_db.get_stats()
        self.assertEqual(stats["total_triaged"], 2)
        self.assertEqual(stats["red_alerts"], 1)
        self.assertEqual(stats["green_cases"], 1)
        self.assertEqual(stats["acknowledged_cases"], 1)

    def test_grounding_stats_integrity(self):
        self.assertIn("under_5_mortality_rate", GROUNDING_STATS)
        self.assertIn("connectivity_gap", GROUNDING_STATS)
        self.assertGreaterEqual(len(DEMO_PATIENT_SCENARIOS), 3)

    def test_clinical_benchmark_dataset_coverage(self):
        self.assertGreaterEqual(len(CLINICAL_BENCHMARK_SCENARIOS), 14)
        payloads = generate_benchmark_sync_payloads()
        self.assertEqual(len(payloads), len(CLINICAL_BENCHMARK_SCENARIOS))

        colors = set(p["assessment"]["triage_color"] for p in payloads)
        self.assertIn("RED", colors)
        self.assertIn("YELLOW", colors)

        # Ingest full benchmark suite into central database
        synced_ids = self.central_db.ingest_batch({
            "asha_id": "ASHA-MH-PUNE-012",
            "records": payloads
        })
        self.assertEqual(len(synced_ids), len(payloads))

        # Check priority sorting (RED cases must appear first)
        records = self.central_db.get_triage_records()
        self.assertEqual(records[0]["triage_color"], "RED")

        # Stats summary validation
        stats = self.central_db.get_stats()
        self.assertGreater(stats["red_alerts"], 0)
        self.assertGreater(stats["yellow_cases"], 0)
        self.assertEqual(stats["total_triaged"], len(payloads))

    def test_redis_gateway_ingestion_and_caching(self):
        from redis_gateway import PHCRedisGateway

        gw = PHCRedisGateway()
        # Test Ingestion Queue
        q_len = gw.push_ingestion_queue({"asha_id": "ASHA-TEST", "records": []})
        self.assertGreaterEqual(q_len, 1)

        # Test Emergency Pub/Sub Broadcasting
        pub_count = gw.publish_emergency_alert({
            "patient_id": "P-RED-TEST",
            "triage_color": "RED",
            "diagnosis": "Severe Pneumonia",
            "urgency": "URGENT HOSPITAL"
        })
        self.assertGreaterEqual(pub_count, 1)

        # Test Fast Cache
        gw.cache_stats({"total_triaged": 42, "red_alerts": 5}, ttl_seconds=10)
        cached = gw.get_cached_stats()
        self.assertIsNotNone(cached)
        self.assertEqual(cached["total_triaged"], 42)

        gw.invalidate_cache()
        invalidated = gw.get_cached_stats()
        self.assertIsNone(invalidated)

    def test_patient_phone_storage_and_sync(self):
        patient_info = {
            "patient_id": "P-PHONE-01",
            "full_name": "Rohan Deshmukh",
            "age_months": 14,
            "gender": "M",
            "guardian_name": "Sunita Deshmukh",
            "village_name": "Khed Shivapur",
            "patient_phone": "+91 98230 11223"
        }
        extracted = {
            "extracted_fields": {
                "age_months": 14,
                "respiratory_rate": 30,
                "temperature_c": 37.5,
                "fever_days": 1,
                "symptoms": ["cough"]
            }
        }
        triage = evaluate_imci_rules(extracted, patient_id="P-PHONE-01")
        
        # Test local db records patient phone
        self.local_db.record_triage_assessment(
            extracted_data=extracted,
            triage_result=triage,
            patient_info=patient_info
        )
        pending = self.local_db.get_pending_sync_records()
        self.assertEqual(len(pending), 1)
        self.assertEqual(pending[0]["patient"]["patient_phone"], "+91 98230 11223")

        # Test central DB ingestion stores patient_phone
        synced_ids = self.central_db.ingest_batch({
            "asha_id": "ASHA-MH-PUNE-012",
            "records": pending
        })
        self.assertEqual(len(synced_ids), 1)
        records = self.central_db.get_triage_records()
        self.assertEqual(records[0]["patient_phone"], "+91 98230 11223")

    def test_patient_callback_report_generation(self):
        from server import format_patient_callback_sms, format_patient_callback_whatsapp
        
        sample_record = {
            "full_name": "Aarav Shinde",
            "patient_id": "P-101",
            "age_months": 14,
            "triage_color": "RED",
            "diagnosis": "Severe Pneumonia / Very Severe Disease",
            "urgency": "URGENT HOSPITAL REFERRAL",
            "actions": ["Give first dose of amoxicillin", "Keep child warm during transit", "Refer immediately to FRU"]
        }
        doctor_info = {
            "full_name": "Dr. Anjali Deshmukh, MD",
            "phc_name": "Khed PHC",
            "phone_number": "+91 98765 43210"
        }
        
        sms = format_patient_callback_sms(sample_record, doctor_info)
        self.assertIn("EMERGENCY RED FLAG", sms)
        self.assertIn("Aarav Shinde", sms)
        self.assertIn("+91 98765 43210", sms)

        wa = format_patient_callback_whatsapp(sample_record, doctor_info)
        self.assertIn("TELE-TRIAGE REPORT", wa)
        self.assertIn("RED ALERT", wa)
        self.assertIn("Dr. Anjali Deshmukh", wa)

    def test_phone_extraction_from_transcripts(self):
        from asha_extractor import parse_asha_transcript
        
        # Test English transcript with phone number
        res_en = parse_asha_transcript("14 month child with fever for 2 days, respiratory rate 48, phone 9823011223")
        self.assertEqual(res_en["extracted_fields"]["patient_phone"], "+91 98230 11223")

        # Test Hindi transcript with phone number
        res_hi = parse_asha_transcript("1 saal ka bachha bukhar hai, mobile number 9890123456")
        self.assertEqual(res_hi["extracted_fields"]["patient_phone"], "+91 98901 23456")


if __name__ == "__main__":
    unittest.main()


