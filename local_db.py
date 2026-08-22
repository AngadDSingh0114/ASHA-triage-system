"""
Local SQLite Database & Offline Sync Queue Manager (Person D)
Handles offline storage, local CRUD operations, and sync-payload compilation.
"""

import sqlite3
import json
import uuid
from datetime import datetime
from typing import Dict, Any, List, Optional


class LocalTriageDB:
    def __init__(self, db_path: str = "local_triage.db"):
        self.db_path = db_path
        self.init_db()

    def get_connection(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        return conn

    def init_db(self):
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
            CREATE TABLE IF NOT EXISTS patients (
                patient_id TEXT PRIMARY KEY,
                full_name TEXT NOT NULL,
                age_months INTEGER NOT NULL,
                gender TEXT CHECK(gender IN ('M', 'F', 'O')),
                guardian_name TEXT,
                village_name TEXT,
                patient_phone TEXT,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            );
            """)
            cursor.execute("""
            CREATE TABLE IF NOT EXISTS triage_assessments (
                assessment_id TEXT PRIMARY KEY,
                patient_id TEXT NOT NULL,
                asha_id TEXT NOT NULL DEFAULT 'ASHA-001',
                temperature_c REAL,
                respiratory_rate INTEGER,
                heart_rate INTEGER,
                spo2 INTEGER,
                fever_days INTEGER DEFAULT 0,
                symptoms_json TEXT NOT NULL,
                has_chest_indrawing BOOLEAN DEFAULT 0,
                has_convulsions BOOLEAN DEFAULT 0,
                has_vomiting_everything BOOLEAN DEFAULT 0,
                has_lethargy BOOLEAN DEFAULT 0,
                triage_color TEXT NOT NULL CHECK(triage_color IN ('RED', 'YELLOW', 'GREEN')),
                diagnosis TEXT NOT NULL,
                urgency TEXT NOT NULL,
                primary_danger TEXT,
                actions_json TEXT,
                referral_note TEXT NOT NULL,
                sync_status TEXT DEFAULT 'PENDING' CHECK(sync_status IN ('PENDING', 'SYNCING', 'SYNCED', 'FAILED')),
                doctor_acknowledged BOOLEAN DEFAULT 0,
                assessed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                synced_at DATETIME,
                FOREIGN KEY (patient_id) REFERENCES patients(patient_id)
            );
            """)
            cursor.execute("CREATE INDEX IF NOT EXISTS idx_sync_status ON triage_assessments(sync_status);")

            # Check migrations for patients table
            cursor.execute("PRAGMA table_info(patients);")
            cols = [r["name"] for r in cursor.fetchall()]
            if "patient_phone" not in cols:
                cursor.execute("ALTER TABLE patients ADD COLUMN patient_phone TEXT;")

            conn.commit()

    def upsert_patient(self, patient_data: Dict[str, Any]) -> str:
        p_id = patient_data.get("patient_id") or f"P-{uuid.uuid4().hex[:6].upper()}"
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
            INSERT INTO patients (patient_id, full_name, age_months, gender, guardian_name, village_name, patient_phone)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(patient_id) DO UPDATE SET
                full_name=excluded.full_name,
                age_months=excluded.age_months,
                gender=excluded.gender,
                guardian_name=excluded.guardian_name,
                village_name=excluded.village_name,
                patient_phone=excluded.patient_phone;
            """, (
                p_id,
                patient_data.get("full_name", "Unknown Child"),
                int(patient_data.get("age_months", 12)),
                patient_data.get("gender", "M"),
                patient_data.get("guardian_name", ""),
                patient_data.get("village_name", "Village Ward 4"),
                patient_data.get("patient_phone", ""),
            ))
            conn.commit()
        return p_id

    def record_triage_assessment(self, 
                                 extracted_data: Dict[str, Any], 
                                 triage_result: Dict[str, Any], 
                                 patient_info: Optional[Dict[str, Any]] = None,
                                 asha_id: str = "ASHA-MH-PUNE-012") -> Dict[str, Any]:
        patient_info = patient_info or {}
        patient_id = triage_result.get("patient_id") or patient_info.get("patient_id") or f"P-{uuid.uuid4().hex[:6].upper()}"
        patient_info["patient_id"] = patient_id
        
        self.upsert_patient(patient_info)

        assessment_id = str(uuid.uuid4())
        fields = extracted_data.get("extracted_fields", {})
        symptoms = fields.get("symptoms", [])
        actions = triage_result.get("actions", [])
        referral_note = triage_result.get("referral_note") or triage_result.get("tts_script") or "IMCI Clinical Assessment Note"

        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
            INSERT INTO triage_assessments (
                assessment_id, patient_id, asha_id,
                temperature_c, respiratory_rate, heart_rate, spo2, fever_days,
                symptoms_json, has_chest_indrawing, has_convulsions, has_vomiting_everything, has_lethargy,
                triage_color, diagnosis, urgency, primary_danger, actions_json, referral_note,
                sync_status, assessed_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'PENDING', ?)
            """, (
                assessment_id,
                patient_id,
                asha_id,
                fields.get("temperature_c", 37.5),
                fields.get("respiratory_rate"),
                fields.get("heart_rate"),
                fields.get("spo2"),
                fields.get("fever_days", 0),
                json.dumps(symptoms),
                1 if fields.get("has_chest_indrawing") else 0,
                1 if fields.get("has_convulsions") else 0,
                1 if fields.get("has_vomiting_everything") else 0,
                1 if fields.get("has_lethargy") else 0,
                triage_result.get("triage_level", "GREEN"),
                triage_result.get("diagnosis", "Mild Illness"),
                triage_result.get("urgency", "Home Care"),
                triage_result.get("primary_danger", "None"),
                json.dumps(actions),
                referral_note,
                datetime.utcnow().isoformat() + "Z"
            ))
            conn.commit()

        return {
            "assessment_id": assessment_id,
            "patient_id": patient_id,
            "sync_status": "PENDING"
        }

    def get_pending_sync_records(self, limit: int = 50) -> List[Dict[str, Any]]:
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
            SELECT 
                t.*,
                p.full_name, p.age_months, p.gender, p.guardian_name, p.village_name, p.patient_phone
            FROM triage_assessments t
            JOIN patients p ON t.patient_id = p.patient_id
            WHERE t.sync_status IN ('PENDING', 'FAILED')
            ORDER BY t.assessed_at ASC
            LIMIT ?
            """, (limit,))
            rows = cursor.fetchall()

            records = []
            for row in rows:
                r = dict(row)
                records.append({
                    "assessment_id": r["assessment_id"],
                    "patient": {
                        "patient_id": r["patient_id"],
                        "full_name": r["full_name"],
                        "age_months": r["age_months"],
                        "gender": r["gender"],
                        "guardian_name": r["guardian_name"],
                        "village_name": r["village_name"],
                        "patient_phone": r["patient_phone"]
                    },
                    "assessment": {
                        "assessment_id": r["assessment_id"],
                        "asha_id": r["asha_id"],
                        "temperature_c": r["temperature_c"],
                        "respiratory_rate": r["respiratory_rate"],
                        "heart_rate": r["heart_rate"],
                        "spo2": r["spo2"],
                        "fever_days": r["fever_days"],
                        "symptoms": json.loads(r["symptoms_json"]) if r["symptoms_json"] else [],
                        "has_chest_indrawing": bool(r["has_chest_indrawing"]),
                        "has_convulsions": bool(r["has_convulsions"]),
                        "has_vomiting_everything": bool(r["has_vomiting_everything"]),
                        "has_lethargy": bool(r["has_lethargy"]),
                        "triage_color": r["triage_color"],
                        "diagnosis": r["diagnosis"],
                        "urgency": r["urgency"],
                        "primary_danger": r["primary_danger"],
                        "actions": json.loads(r["actions_json"]) if r["actions_json"] else [],
                        "referral_note": r["referral_note"],
                        "assessed_at": r["assessed_at"]
                    }
                })
            return records

    def mark_records_synced(self, assessment_ids: List[str]):
        if not assessment_ids:
            return
        with self.get_connection() as conn:
            cursor = conn.cursor()
            placeholders = ",".join("?" for _ in assessment_ids)
            cursor.execute(f"""
            UPDATE triage_assessments 
            SET sync_status = 'SYNCED', synced_at = ?
            WHERE assessment_id IN ({placeholders})
            """, [datetime.utcnow().isoformat() + "Z"] + assessment_ids)
            conn.commit()

    def get_all_records(self) -> List[Dict[str, Any]]:
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
            SELECT t.*, p.full_name, p.age_months, p.village_name, p.patient_phone
            FROM triage_assessments t
            JOIN patients p ON t.patient_id = p.patient_id
            ORDER BY t.assessed_at DESC
            """)
            return [dict(row) for row in cursor.fetchall()]
