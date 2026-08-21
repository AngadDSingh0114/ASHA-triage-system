# ASHA Triage - Diagnoses by Risk Category

> Maps every diagnosis the WHO IMCI rules engine can produce to its risk category
> (RED / YELLOW / GREEN), the keyword/vital conditions that trigger it, the urgency,
> and the clinical actions. Derived from `imci_rules_engine.py`.

Risk categories:
- **RED** = URGENT HOSPITAL REFERRAL (very severe / danger signs)
- **YELLOW** = REFER TO PHC (within 24h or for evaluation)
- **GREEN** = HOME CARE (mild illness / ORS)

## RED - Urgent Hospital Referral

### SEVERE PNEUMONIA / VERY SEVERE DISEASE
- **Trigger conditions (any):**
  - Convulsions present (`convulsions` keyword)
  - Lethargy / unresponsiveness present (`lethargy` keyword)
  - Chest indrawing present AND age < 2 months
- **Urgency:** URGENT HOSPITAL REFERRAL
- **Primary danger sign shown:** first detected danger sign, else "Severe chest indrawing"
- **Actions:**
  1. Give first dose of appropriate oral antibiotic before transfer
  2. Keep child warm during transport
  3. Refer IMMEDIATELY to nearest hospital / First Referral Unit (FRU)

## YELLOW - Refer to PHC

### PNEUMONIA (Fast Breathing)
- **Trigger conditions (any):**
  - Chest indrawing present (`chest_indrawing` keyword)
  - Fast breathing: RR >= 60 if age < 2m, RR >= 50 if 2-11m, RR >= 40 if >= 12m
- **Urgency:** REFER TO PHC WITHIN 24 HOURS
- **Primary danger sign shown:** "Chest indrawing" or "Fast breathing (RR/min)"
- **Actions:**
  1. Give oral Amoxicillin for 5 days
  2. Soothe throat and relieve cough with safe remedy
  3. Advise mother when to return immediately if signs worsen
  4. Refer to Primary Health Centre (PHC)

### DIARRHEA / GASTROENTERITIS (persistent)
- **Trigger conditions:**
  - Diarrhea symptom present AND fever_days > 7
- **Urgency:** PHC CLINIC VISIT
- **Primary danger sign shown:** "Persistent diarrhea"
- **Actions:**
  1. Give extra fluid (ORS solution & Zinc supplement for 14 days)
  2. Continue feeding child
  3. Advise when to return immediately

### FEVER - POSSIBLE MALARIA / TYPHOID
- **Trigger conditions:**
  - Fever symptom present AND fever_days > 7
- **Urgency:** REFER TO PHC FOR BLOOD TEST
- **Primary danger sign shown:** "High fever (N days)"
- **Actions:**
  1. Perform RDT test for Malaria if available
  2. Give Paracetamol for high fever (>=38.5 C)
  3. Refer to PHC for evaluation

## GREEN - Home Care

### DIARRHEA / GASTROENTERITIS (acute)
- **Trigger conditions:**
  - Diarrhea symptom present AND fever_days <= 7
- **Urgency:** HOME CARE WITH ORS
- **Primary danger sign shown:** "Acute diarrhea"
- **Actions:**
  1. Give extra fluid (ORS solution & Zinc supplement for 14 days)
  2. Continue feeding child
  3. Advise when to return immediately

### FEVER - MILD ACUTE FEBRILE ILLNESS
- **Trigger conditions:**
  - Fever symptom present AND fever_days <= 7
- **Urgency:** HOME CARE
- **Primary danger sign shown:** "Mild fever (N days)"
- **Actions:**
  1. Give Paracetamol for fever
  2. Ensure adequate hydration
  3. Follow up in 2 days if fever persists

### NO PNEUMONIA / MILD ILLNESS
- **Trigger conditions:**
  - No danger signs, no fever, no diarrhea detected
- **Urgency:** HOME CARE
- **Primary danger sign shown:** "No acute danger signs"
- **Actions:**
  1. Soothe throat with home remedy
  2. Advise mother when to return if signs worsen

## Decision priority (evaluated top-down)

1. RED if convulsions / lethargy / (chest indrawing AND age < 2m)
2. else YELLOW if chest indrawing / fast breathing
3. else YELLOW/GREEN by diarrhea + fever duration
4. else YELLOW/GREEN by fever duration
5. else GREEN (no acute illness)

General danger signs recorded for any RED case: Convulsions, Lethargy/Unresponsiveness,
Vomiting Everything (when present).
