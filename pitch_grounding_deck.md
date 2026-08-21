# ASHA / PHC AI-Assisted Tele-Triage Companion
## Hackathon Pitch, Data Grounding & 3-Minute Demo Script (Person D)

---

## 📑 Slide-by-Slide Pitch Deck Outline

### Slide 1: The Problem — The Frontline Pediatric Crisis
* **The Reality:** A single ASHA (Accredited Social Health Activist) worker in rural India oversees **1,000 to 1,200+ people** across remote villages, often conducting 30–40 household visits daily with zero on-field clinical decision support tools.
* **The Clinical Toll (NFHS-5 National Data):**
  * India's rural Under-5 Mortality Rate (U5MR) stands at **35.2 per 1,000 live births** (exceeding 45/1,000 in high-priority tribal districts).
  * **Childhood Pneumonia & Acute Respiratory Infections (ARI)** account for **14.3%** of under-5 mortality.
  * **Diarrheal Dehydration** accounts for **9.8%**.
  * **Over 68%** of these child deaths are preventable with early acute triage and timely referral.
* **The Connectivity Barrier:** **42.7% of Sub-Health Centres (SHCs)** and rural field zones suffer from zero or unstable cellular connectivity. Cloud-only AI applications fail completely in the field.

---

### Slide 2: Our Solution — 100% Offline-First AI Tele-Triage
* **Voice-First Input (Indic Speech):** ASHA workers speak naturally in Hindi / Hinglish / Regional dialects (*"8 mahine ka bachha, 3 din se bukhar, 56 saans rate"*).
* **Deterministic Clinical NLU:** Extracts structured pediatric vitals (Age, Respiratory Rate, Fever duration) and danger signs without requiring manual typing.
* **On-Device WHO IMCI Decision Engine:** Instant, zero-latency clinical evaluation running entirely on-device (no cloud call needed for the triage decision).
* **Color-Coded Protocol Actions:** Returns **RED (Urgent Hospital)**, **YELLOW (PHC Clinic in 24h)**, or **GREEN (Home Care with ORS)**.
* **10-Second Doctor Brief & Opportunistic Sync:** Generates a concise audio summary and syncs to the PHC Doctor Dashboard automatically as soon as connectivity returns.

---

### Slide 3: System Architecture & Data Flow

```
   ┌─────────────────────────────────────────────────────────────┐
   │                  ON-DEVICE MOBILE CLIENT                     │
   │                                                             │
   │   [Voice Input (Hindi/Hinglish)]                            │
   │               │                                             │
   │               ▼                                             │
   │   [Speech-to-Text & Entity Extractor (Person C)]            │
   │               │                                             │
   │               ▼                                             │
   │   [WHO IMCI Rules Engine (Person B)]                         │
   │               │                                             │
   │               ▼                                             │
   │   [RED / YELLOW / GREEN Triage + 10s TTS Audio Brief]       │
   │               │                                             │
   │               ▼                                             │
   │   [Local SQLite DB & Outbox Queue (Person D)] ── (Offline)  │
   └───────────────────────────────┬─────────────────────────────┘
                                   │
                     (On Connectivity Reconnect)
                                   │
                                   ▼
   ┌─────────────────────────────────────────────────────────────┐
   │              PHC CENTRAL INGESTION GATEWAY                   │
   │                                                             │
   │   [Idempotent Batch Sync Ingestion API (POST /api/sync)]     │
   │               │                                             │
   │               ▼                                             │
   │   [Central SQLite / PostgreSQL Database]                    │
   │               │                                             │
   │               ▼                                             │
   │   [Live PHC Doctor Triage Console (phc_dashboard.html)]     │
   │    • Priority Sorting (RED > YELLOW > GREEN)                │
   │    • 10s Audio Brief Playback                               │
   │    • Case Acknowledgment & Prescription Tracking             │
   └─────────────────────────────────────────────────────────────┘
```

---

### Slide 4: Clinical Defensibility (Why Expert Rules > Black-Box GenAI)
* **Zero Hallucination Tolerance:** In triage, an LLM hallucinating medication dosage or missing an infant's convulsion is life-threatening.
* **WHO IMCI Standardized Cutoffs:**
  * Age $< 2$ months: $\text{Respiratory Rate} \ge 60\text{ bpm} \rightarrow$ **RED (Severe Disease)**
  * Age $2\text{--}11$ months: $\text{Respiratory Rate} \ge 50\text{ bpm} \rightarrow$ **YELLOW (Pneumonia)**
  * Age $12\text{--}59$ months: $\text{Respiratory Rate} \ge 40\text{ bpm} \rightarrow$ **YELLOW (Pneumonia)**
  * General Danger Signs (*convulsions*, *lethargy*, *vomiting everything*) $\rightarrow$ **RED (Immediate Transfer)**
* **Auditable & Explainable:** Every referral note explicitly cites the exact clinical indicator that triggered the alert.

---

### Slide 5: Roadmap & National Health Integration
* **Integration with Ayushman Bharat Digital Mission (ABDM):** ABHA Health ID generation and FHIR-compliant record exchange.
* **IndicASR Dialect Expansion:** Expanding on-device ASR across 12 Indian regional languages via AI4Bharat IndicVoices.
* **Community Epidemiological Heatmaps:** Aggregating anonymous village-level triage spikes to detect pneumonia or malaria outbreaks in advance.

---

## ⏱️ 3-Minute Live Judging Demo Script

| Time | Presenter Action | Screen Shown | Spoken Pitch Script |
| :--- | :--- | :--- | :--- |
| **0:00 – 0:30** | Introduce problem & set up demo environment. | ASHA App (`index.html`) set to **Airplane Mode (Offline)** | *"Frontline ASHA workers cover over 1,000 people in rural areas with poor connectivity. Watch as we perform a complete triage assessment with zero internet."* |
| **0:30 – 1:15** | Select **RED Case** preset (*"jhatke aa rahe hain aur behoosh hai"*). | ASHA App (`index.html`) | *"The ASHA worker speaks in Hindi. The on-device engine extracts convulsions and lethargy, instantly returning a RED Alert under WHO IMCI guidelines with emergency transfer instructions."* Click **"Play 10s Audio Brief"** and then **"Save Assessment to Local Database"** (Queue shows `1 Pending`). |
| **1:15 – 1:45** | Select **GREEN Case** preset (*"dast aur ulti ho rahi hai subah se"*). | ASHA App (`index.html`) | *"For mild diarrhea without severe dehydration, it flags GREEN — Home Care with ORS and Zinc. This proves the tool avoids overwhelming hospitals with unnecessary referrals."* Click **"Save Assessment"** (Queue shows `2 Pending`). |
| **1:45 – 2:20** | **The Big Sync Moment:** Click **"Airplane Mode"** to toggle back to **"Online (Auto-Sync)"**. | ASHA App (`index.html`) $\rightarrow$ Switch to PHC Dashboard (`phc_dashboard.html`) | *"Now, the ASHA worker reaches the main road or returns to the village sub-centre where 2G/WiFi connects. The local SQLite outbox automatically flushes the batch payload to the Primary Health Centre."* |
| **2:20 – 3:00** | Show PHC Doctor Console updating in real-time with the RED alert at the top. | PHC Dashboard (`phc_dashboard.html`) | *"At the Primary Health Centre, the doctor's console instantly updates. The RED emergency case is prioritized at the top. The doctor plays the 10-second audio summary, reviews the vitals, and clicks 'Mark Acknowledged' to prepare emergency oxygen before the child arrives."* |

---

## 📊 Key Data Points to Memorize for Q&A

1. **What dataset did you ground your triage thresholds on?**
   * *Answer:* WHO IMCI (Integrated Management of Childhood Illness) guidelines adopted by the Ministry of Health and Family Welfare (MoHFW), Government of India.
2. **What dataset justifies the problem size?**
   * *Answer:* NFHS-5 (National Family Health Survey 2019–21) and HMIS standard reports showing rural Under-5 Mortality at 35.2/1,000 and pneumonia causing 14.3% of deaths.
3. **Why not just call an LLM API in the cloud?**
   * *Answer:* 42.7% of rural health sub-centres face intermittent or zero connectivity. Furthermore, clinical safety requires deterministic, auditable decision trees with zero latency and zero hallucination risk on ₹6,000 Android devices.

