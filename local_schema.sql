-- =====================================================================
-- WHO IMCI Tele-Triage: Local SQLite Schema & Sync Queue (Person D)
-- =====================================================================

-- 1. Patients Master Table
CREATE TABLE IF NOT EXISTS patients (
    patient_id TEXT PRIMARY KEY,
    full_name TEXT NOT NULL,
    age_months INTEGER NOT NULL,
    gender TEXT CHECK(gender IN ('M', 'F', 'O')),
    guardian_name TEXT,
    village_name TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 2. Triage Assessments & Clinical Outcomes Table
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

CREATE INDEX IF NOT EXISTS idx_sync_status ON triage_assessments(sync_status);
CREATE INDEX IF NOT EXISTS idx_triage_color ON triage_assessments(triage_color);
CREATE INDEX IF NOT EXISTS idx_patient_lookup ON triage_assessments(patient_id);

