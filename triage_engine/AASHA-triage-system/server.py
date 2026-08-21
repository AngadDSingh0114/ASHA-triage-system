"""
Zero-Dependency Backend Ingestion & PHC Doctor Central Server (Person D)
Provides REST API for batch sync, real-time triage queries, doctor acknowledgment,
and serves the offline ASHA Companion & PHC Doctor Live Monitoring Dashboard.
"""

import http.server
import socketserver
import json
import sqlite3
import os
import sys
import urllib.parse
from datetime import datetime
from typing import Dict, Any, List

PORT = 8000
DB_FILE = "phc_central.db"

# Grounding Statistics for Hackathon Pitch & PHC Reference
GROUNDING_STATS = {
    "problem_context": "Pediatric Rural Triage Crisis & Connectivity Barrier",
    "asha_coverage_ratio": "1 ASHA per 1,000–1,200 rural population (covering up to 40+ households/day)",
    "under_5_mortality_rate": "35.2 per 1,000 live births (NFHS-5 National Average; >45 in rural high-priority districts)",
    "leading_causes_of_u5_death": [
        {"cause": "Childhood Pneumonia & Acute Respiratory Infections (ARI)", "percentage": "14.3%"},
        {"cause": "Diarrheal Diseases & Dehydration", "percentage": "9.8%"},
        {"cause": "Neonatal Infections / Sepsis", "percentage": "11.2%"}
    ],
    "delayed_referral_impact": "Over 68% of preventable under-5 deaths occur due to delayed triage and lack of early warning referral from community level to PHC/FRU.",
    "connectivity_gap": "42.7% of Sub-Health Centres (SHCs) in aspirational and tribal districts operate in zero or intermittent 2G/unstable cellular connectivity, making cloud-only AI apps unviable.",
    "clinical_justification": "WHO IMCI guidelines provide deterministic, high-sensitivity decision trees for frontline non-clinical workers where false-negatives (missed severe cases) are life-threatening."
}

# Realistic Initial Benchmark Cases
DEMO_PATIENT_SCENARIOS = [
    {
        "patient": {
            "patient_id": "P-MH-101",
            "full_name": "Aarav Shinde",
            "age_months": 8,
            "gender": "M",
            "guardian_name": "Pooja Shinde",
            "village_name": "Khed Shivapur"
        },
        "assessment": {
            "assessment_id": "SEED-P-MH-101",
            "asha_id": "ASHA-MH-PUNE-012",
            "temperature_c": 38.8,
            "respiratory_rate": 56,
            "heart_rate": 118,
            "spo2": 95,
            "fever_days": 3,
            "symptoms": ["fever", "chest_indrawing", "fast_breathing"],
            "has_chest_indrawing": True,
            "has_convulsions": False,
            "has_vomiting_everything": False,
            "has_lethargy": False,
            "triage_color": "YELLOW",
            "diagnosis": "PNEUMONIA (Fast Breathing & Chest Indrawing)",
            "urgency": "REFER TO PHC WITHIN 24 HOURS",
            "primary_danger": "Fast breathing (56/min)",
            "actions": ["Give oral Amoxicillin for 5 days", "Soothe throat and cough", "Refer to PHC clinic"],
            "referral_note": "YELLOW Alert. P-MH-101, 8-month-old with Fast breathing (56/min), RR 56. Diagnosis: PNEUMONIA. Action: REFER TO PHC WITHIN 24 HOURS.",
            "assessed_at": "2026-08-21T09:30:00Z"
        }
    },
    {
        "patient": {
            "patient_id": "P-MH-102",
            "full_name": "Ananya Patil",
            "age_months": 14,
            "gender": "F",
            "guardian_name": "Ramesh Patil",
            "village_name": "Velhe"
        },
        "assessment": {
            "assessment_id": "SEED-P-MH-102",
            "asha_id": "ASHA-MH-PUNE-012",
            "temperature_c": 39.5,
            "respiratory_rate": 44,
            "heart_rate": 130,
            "spo2": 92,
            "fever_days": 2,
            "symptoms": ["convulsions", "lethargy", "fever"],
            "has_chest_indrawing": False,
            "has_convulsions": True,
            "has_vomiting_everything": False,
            "has_lethargy": True,
            "triage_color": "RED",
            "diagnosis": "SEVERE PNEUMONIA / VERY SEVERE DISEASE",
            "urgency": "URGENT HOSPITAL REFERRAL",
            "primary_danger": "Convulsions & Lethargy",
            "actions": ["Give first dose of antibiotic", "Keep child warm", "Refer IMMEDIATELY to hospital/FRU"],
            "referral_note": "RED Alert. P-MH-102, 14-month-old with Convulsions, lethargy. Diagnosis: SEVERE DISEASE. Action: URGENT HOSPITAL REFERRAL.",
            "assessed_at": "2026-08-21T09:45:00Z"
        }
    },
    {
        "patient": {
            "patient_id": "P-MH-103",
            "full_name": "Kabir Jadhav",
            "age_months": 18,
            "gender": "M",
            "guardian_name": "Sunita Jadhav",
            "village_name": "Bhor"
        },
        "assessment": {
            "assessment_id": "SEED-P-MH-103",
            "asha_id": "ASHA-MH-PUNE-012",
            "temperature_c": 37.2,
            "respiratory_rate": 32,
            "heart_rate": 100,
            "spo2": 98,
            "fever_days": 0,
            "symptoms": ["diarrhea", "vomiting"],
            "has_chest_indrawing": False,
            "has_convulsions": False,
            "has_vomiting_everything": False,
            "has_lethargy": False,
            "triage_color": "GREEN",
            "diagnosis": "DIARRHEA / GASTROENTERITIS",
            "urgency": "HOME CARE WITH ORS",
            "primary_danger": "Acute diarrhea without severe dehydration",
            "actions": ["Give extra fluid (ORS & Zinc for 14 days)", "Continue feeding child"],
            "referral_note": "GREEN Alert. P-MH-103, 18-month-old with Acute diarrhea. Action: HOME CARE WITH ORS.",
            "assessed_at": "2026-08-21T10:00:00Z"
        }
    }
]


class CentralDBManager:
    def __init__(self, db_path: str = DB_FILE):
        self.db_path = db_path
        self.init_db()

    def get_conn(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        return conn

    def init_db(self):
        with self.get_conn() as conn:
            c = conn.cursor()
            c.execute("""
            CREATE TABLE IF NOT EXISTS patients (
                patient_id TEXT PRIMARY KEY,
                full_name TEXT NOT NULL,
                age_months INTEGER NOT NULL,
                gender TEXT,
                guardian_name TEXT,
                village_name TEXT,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            );
            """)
            c.execute("""
            CREATE TABLE IF NOT EXISTS triage_records (
                assessment_id TEXT PRIMARY KEY,
                patient_id TEXT NOT NULL,
                asha_id TEXT NOT NULL,
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
                doctor_acknowledged BOOLEAN DEFAULT 0,
                doctor_notes TEXT,
                assessed_at DATETIME NOT NULL,
                synced_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (patient_id) REFERENCES patients(patient_id)
            );
            """)
            c.execute("CREATE INDEX IF NOT EXISTS idx_rec_color ON triage_records(triage_color);")
            c.execute("CREATE INDEX IF NOT EXISTS idx_rec_ack ON triage_records(doctor_acknowledged);")
            conn.commit()

    def ingest_batch(self, payload: Dict[str, Any]) -> List[str]:
        asha_id = payload.get("asha_id", "ASHA-UNKNOWN")
        records = payload.get("records", [])
        synced_ids = []

        with self.get_conn() as conn:
            c = conn.cursor()
            for item in records:
                p = item.get("patient", {})
                a = item.get("assessment", {})
                p_id = p.get("patient_id") or a.get("patient_id")
                ass_id = a.get("assessment_id")

                if not p_id or not ass_id:
                    continue

                c.execute("""
                INSERT INTO patients (patient_id, full_name, age_months, gender, guardian_name, village_name)
                VALUES (?, ?, ?, ?, ?, ?)
                ON CONFLICT(patient_id) DO UPDATE SET
                    full_name=excluded.full_name,
                    age_months=excluded.age_months,
                    gender=excluded.gender,
                    guardian_name=excluded.guardian_name,
                    village_name=excluded.village_name;
                """, (
                    p_id,
                    p.get("full_name", "Unknown Child"),
                    p.get("age_months", 12),
                    p.get("gender", "M"),
                    p.get("guardian_name", ""),
                    p.get("village_name", "Sector 4"),
                ))

                symptoms = a.get("symptoms", [])
                actions = a.get("actions", [])

                c.execute("""
                INSERT INTO triage_records (
                    assessment_id, patient_id, asha_id,
                    temperature_c, respiratory_rate, heart_rate, spo2, fever_days,
                    symptoms_json, has_chest_indrawing, has_convulsions, has_vomiting_everything, has_lethargy,
                    triage_color, diagnosis, urgency, primary_danger, actions_json, referral_note,
                    assessed_at, synced_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(assessment_id) DO UPDATE SET
                    doctor_acknowledged=triage_records.doctor_acknowledged,
                    synced_at=excluded.synced_at;
                """, (
                    ass_id,
                    p_id,
                    a.get("asha_id", asha_id),
                    a.get("temperature_c"),
                    a.get("respiratory_rate"),
                    a.get("heart_rate"),
                    a.get("spo2"),
                    a.get("fever_days", 0),
                    json.dumps(symptoms),
                    1 if a.get("has_chest_indrawing") else 0,
                    1 if a.get("has_convulsions") else 0,
                    1 if a.get("has_vomiting_everything") else 0,
                    1 if a.get("has_lethargy") else 0,
                    a.get("triage_color", "GREEN"),
                    a.get("diagnosis", "Mild Illness"),
                    a.get("urgency", "Home Care"),
                    a.get("primary_danger", "None"),
                    json.dumps(actions),
                    a.get("referral_note", "No note provided"),
                    a.get("assessed_at", datetime.utcnow().isoformat() + "Z"),
                    datetime.utcnow().isoformat() + "Z"
                ))
                synced_ids.append(ass_id)

            conn.commit()
        return synced_ids

    def get_triage_records(self, color_filter: str = None) -> List[Dict[str, Any]]:
        with self.get_conn() as conn:
            c = conn.cursor()
            query = """
            SELECT 
                r.*,
                p.full_name, p.age_months, p.gender, p.guardian_name, p.village_name
            FROM triage_records r
            JOIN patients p ON r.patient_id = p.patient_id
            """
            params = []
            if color_filter and color_filter.upper() in ['RED', 'YELLOW', 'GREEN']:
                query += " WHERE r.triage_color = ?"
                params.append(color_filter.upper())

            query += """
            ORDER BY 
                CASE r.triage_color 
                    WHEN 'RED' THEN 1 
                    WHEN 'YELLOW' THEN 2 
                    WHEN 'GREEN' THEN 3 
                    ELSE 4 
                END ASC,
                r.assessed_at DESC
            """
            c.execute(query, params)
            rows = c.fetchall()

            out = []
            for r in rows:
                item = dict(r)
                item["symptoms"] = json.loads(item["symptoms_json"]) if item["symptoms_json"] else []
                item["actions"] = json.loads(item["actions_json"]) if item["actions_json"] else []
                out.append(item)
            return out

    def acknowledge_record(self, assessment_id: str, doctor_notes: str = "") -> bool:
        with self.get_conn() as conn:
            c = conn.cursor()
            c.execute("""
            UPDATE triage_records 
            SET doctor_acknowledged = 1, doctor_notes = ?
            WHERE assessment_id = ?
            """, (doctor_notes, assessment_id))
            conn.commit()
            return c.rowcount > 0

    def get_stats(self) -> Dict[str, Any]:
        with self.get_conn() as conn:
            c = conn.cursor()
            c.execute("SELECT COUNT(*) as total FROM triage_records")
            total = c.fetchone()["total"]

            c.execute("SELECT COUNT(*) as cnt FROM triage_records WHERE triage_color = 'RED'")
            red_count = c.fetchone()["cnt"]

            c.execute("SELECT COUNT(*) as cnt FROM triage_records WHERE triage_color = 'YELLOW'")
            yellow_count = c.fetchone()["cnt"]

            c.execute("SELECT COUNT(*) as cnt FROM triage_records WHERE triage_color = 'GREEN'")
            green_count = c.fetchone()["cnt"]

            c.execute("SELECT COUNT(*) as cnt FROM triage_records WHERE doctor_acknowledged = 1")
            ack_count = c.fetchone()["cnt"]

            return {
                "total_triaged": total,
                "red_alerts": red_count,
                "yellow_cases": yellow_count,
                "green_cases": green_count,
                "acknowledged_cases": ack_count,
                "pending_doctor_action": max(0, (red_count + yellow_count) - ack_count)
            }


central_db = CentralDBManager()


class TriageRequestHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, PATCH, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization')
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        query = urllib.parse.parse_qs(parsed.query)

        if path == "/api/records":
            color = query.get("color", [None])[0]
            records = central_db.get_triage_records(color_filter=color)
            self._send_json(200, {"success": True, "count": len(records), "records": records})
        elif path == "/api/stats":
            stats = central_db.get_stats()
            self._send_json(200, {"success": True, "stats": stats})
        elif path == "/api/grounding-stats":
            self._send_json(200, {"success": True, "grounding": GROUNDING_STATS})
        elif path == "/api/health":
            self._send_json(200, {"status": "online", "timestamp": datetime.utcnow().isoformat() + "Z"})
        else:
            super().do_GET()

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        if path == "/api/sync/batch":
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length)
            try:
                payload = json.loads(body.decode('utf-8'))
                synced_ids = central_db.ingest_batch(payload)
                self._send_json(200, {
                    "success": True, 
                    "synced_count": len(synced_ids), 
                    "synced_ids": synced_ids,
                    "server_time": datetime.utcnow().isoformat() + "Z"
                })
            except Exception as e:
                self._send_json(400, {"success": False, "error": str(e)})

        elif path == "/api/seed":
            for item in DEMO_PATIENT_SCENARIOS:
                batch_payload = {
                    "asha_id": "ASHA-MH-PUNE-012",
                    "records": [item]
                }
                central_db.ingest_batch(batch_payload)
            self._send_json(200, {"success": True, "message": f"Seeded {len(DEMO_PATIENT_SCENARIOS)} benchmark cases."})

        elif path.startswith("/api/records/") and path.endswith("/acknowledge"):
            parts = path.strip("/").split("/")
            assessment_id = parts[2]
            content_length = int(self.headers.get('Content-Length', 0))
            doctor_notes = ""
            if content_length > 0:
                body = self.rfile.read(content_length)
                try:
                    data = json.loads(body.decode('utf-8'))
                    doctor_notes = data.get("doctor_notes", "")
                except Exception:
                    pass
            success = central_db.acknowledge_record(assessment_id, doctor_notes)
            self._send_json(200, {"success": success, "assessment_id": assessment_id})
        else:
            self._send_json(404, {"error": "Endpoint not found"})

    def _send_json(self, status_code: int, data: Dict[str, Any]):
        response = json.dumps(data).encode('utf-8')
        self.send_response(status_code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(response)))
        self.end_headers()
        self.wfile.write(response)


def run_server(port: int = PORT):
    current_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(current_dir)
    socketserver.TCPServer.allow_reuse_address = True
    
    # Pre-seed if database empty
    stats = central_db.get_stats()
    if stats["total_triaged"] == 0:
        for item in DEMO_PATIENT_SCENARIOS:
            central_db.ingest_batch({"asha_id": "ASHA-MH-PUNE-012", "records": [item]})

    print("=" * 60, flush=True)
    print("[SERVER] ASHA / PHC Tele-Triage Central Backend Server", flush=True)
    print(f"[STATUS] Running on http://localhost:{port}", flush=True)
    print(f"[ASHA APP]       http://localhost:{port}/index.html", flush=True)
    print(f"[PHC DASHBOARD]  http://localhost:{port}/phc_dashboard.html", flush=True)
    print("=" * 60, flush=True)
    print("Press Ctrl+C to stop the server.", flush=True)

    with socketserver.TCPServer(("", port), TriageRequestHandler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nServer gracefully stopped.", flush=True)


if __name__ == "__main__":
    run_server()
