"""
Comprehensive Unit Tests for Person D (Backend, Sync Queue & SQLite DB)
"""

import unittest
import os
import uuid
from local_db import LocalTriageDB
from server import CentralDBManager
from seed_data import GROUNDING_STATS, DEMO_PATIENT_SCENARIOS
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
        self.assertEqual(pending[0]["assessment"]["triage_color"], "YELLOW")

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
        self.assertGreaterEqual(len(DEMO_PATIENT_SCENARIOS), 10)

    def test_clinical_benchmark_dataset_coverage(self):
        from seed_data import CLINICAL_BENCHMARK_SCENARIOS, generate_benchmark_sync_payloads

        self.assertGreaterEqual(len(CLINICAL_BENCHMARK_SCENARIOS), 14)
        payloads = generate_benchmark_sync_payloads()
        self.assertEqual(len(payloads), len(CLINICAL_BENCHMARK_SCENARIOS))

        colors = set(p["assessment"]["triage_color"] for p in payloads)
        self.assertIn("RED", colors)
        self.assertIn("YELLOW", colors)
        self.assertIn("GREEN", colors)

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
        self.assertGreater(stats["green_cases"], 0)
        self.assertEqual(stats["total_triaged"], len(payloads))


if __name__ == "__main__":
    unittest.main()


