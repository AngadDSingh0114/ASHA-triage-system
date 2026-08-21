# ASHA Tele-Triage System (WHO IMCI Protocol)

> **Offline-First AI-Assisted Tele-Triage Companion for ASHA / PHC Healthcare Workers in Rural India**  
> Speech-to-Text & Symptom Entity Extraction Engine, WHO IMCI Rules Classifier, Local SQLite & Outbox Sync Queue, 10-Second TTS Audio Brief, and Real-Time PHC Doctor Ingestion Dashboard.

---

## 🌟 Architecture & Team Split

| Role | Module | Key Responsibilities |
| :--- | :--- | :--- |
| **Person A** | Mobile App / UI | Offline form fallback, result cards, offline indicators. |
| **Person B** | On-Device Decision Engine | WHO IMCI rules logic, age-banded respiratory thresholds, danger signs. |
| **Person C** | STT & NLP Extractor | Hindi/Hinglish thesaurus, vitals slot filling, 10s audio script synthesis. |
| **Person D** | **Backend / Sync + Data** | **Local SQLite schema, opportunistic sync-on-reconnect queue, live PHC doctor console, and NFHS-5/HMIS data grounding.** |

---

## 📁 Repository Structure

```text
.
├── local_schema.sql        # SQLite DDL Schema for on-device & server databases
├── local_db.py             # Local SQLite DAO & Offline Sync Outbox Manager (Person D)
├── server.py               # Zero-Dependency Central Ingestion API & Static Web Server (Person D)
├── seed_data.py            # NFHS-5/HMIS Health Stats & Realistic IMCI Benchmark Cases (Person D)
├── phc_dashboard.html      # Live PHC Doctor Tele-Triage Ingestion Console (Person D)
├── index.html              # ASHA Field Companion App with Offline Queue & Airplane Toggle
├── asha_extractor.py       # Speech/NLP Entity Extraction & Regional Hindi Thesaurus (Person C)
├── imci_rules_engine.py    # WHO IMCI Decision-Tree Rules Engine & Formatters (Person B)
├── tts_synthesizer.py      # On-Device Text-to-Speech (TTS) Audio Synthesizer
├── test_sync_backend.py    # Unit Tests for Backend, Sync Engine & Database (Person D)
├── test_asha_extractor.py  # Unit Tests for Entity Extractor
├── test_imci_rules.py      # Unit Tests for Rules Engine & Full Pipeline
└── README.md               # Master Documentation
```

---

## 🚀 Quick Start & Usage

### 1. Start the Central Backend & Dashboards
Run the zero-dependency Python server:
```bash
python server.py
```
This serves:
* 📱 **ASHA Field Companion App:** `http://localhost:8000/index.html`
* 🩺 **PHC Doctor Live Dashboard:** `http://localhost:8000/phc_dashboard.html`

### 2. Run All Automated Unit Tests
```bash
python -m unittest discover
```
*Runs all 14 unit tests across NLP extraction, IMCI rules engine, local SQLite outbox, and backend sync.*

---

## 🔁 "Airplane Mode" Sync-on-Reconnect Demo Flow

1. **Open ASHA App (`/index.html`)**: Click the top right badge to switch to **"Airplane Mode (Offline)"**.
2. **Perform Offline Triage**: Select a preset (e.g. *Convulsions - RED* or *Fast Breathing - YELLOW*) and click **"Save Assessment to Local Database"**.
3. **Inspect Queue**: Notice the queue badge increments (`1 Pending`), securely stored on the local device without network.
4. **Restore Connectivity**: Click the badge to toggle **"Online (Auto-Sync)"**.
5. **Instant Ingestion**: The outbox flushes to the central backend via `POST /api/sync/batch`.
6. **Open PHC Doctor Dashboard (`/phc_dashboard.html`)**: The doctor console updates in real time with the inbound priority alert, clinical vitals, and 10s audio brief.

---

## 📊 Clinical Grounding (NFHS-5 & MoHFW)

* **Under-5 Mortality Rate (U5MR):** 35.2 per 1,000 live births (NFHS-5). Over 68% of preventable child deaths in rural India stem from delayed diagnosis of acute pneumonia and diarrhea.
* **WHO IMCI Protocol Justification:** Deterministic decision trees with age-specific cutoffs (<2m: $\ge$60 bpm, 2-11m: $\ge$50 bpm, 12-59m: $\ge$40 bpm) provide high-sensitivity safety for non-clinical frontline workers.
* **Offline Requirement:** 42.7% of rural health sub-centres face intermittent cellular coverage, making cloud-dependent triage systems unsafe.

---

## 📜 License
MIT License. Developed for pediatric tele-triage hackathon initiative.
