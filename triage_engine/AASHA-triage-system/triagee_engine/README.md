# ASHA Triage Engine — WHO IMCI / IMNCI Decision Engine

> **Deterministic, on-device clinical triage rules engine** for ASHA/PHC workers.  
> No machine learning. No free-text generation. Every flag ships with a `rule_trace`.

## Overview

This engine implements the WHO Integrated Management of Childhood Illness (IMCI) / India's IMNCI guidelines as a deterministic rules engine. It takes structured symptoms and vitals as input and outputs a **RED/YELLOW/GREEN** triage flag with a **templated referral note**.

### Source
- [NHM IMNCI Chart Booklet (MoHFW India)](https://nhm.gov.in/images/pdf/programmes/child-health/guidelines/imnci_chart_booklet.pdf)
- [WHO IMCI Adaptation Guide](https://cdn.who.int/media/docs/default-source/mca-documents/child/imci-integrated-management-of-childhood-illness/adaptation-guide/imci_adaptation_guide_2c.pdf)

> ⚠️ **This is a hackathon prototype, not validated clinical software.** Cross-check against the booklet before presenting any number as fact.

## Architecture

```
TriageInput (patient + vitals + symptoms)
    │
    ├──▶ checkGeneralDangerSigns() ──▶ any present? → SHORT-CIRCUIT RED
    │
    ├──▶ Young infant (<2mo) catch-all ──▶ any positive symptom? → RED
    │
    ├──▶ classifyPneumonia()    ──▶ ConditionResult
    ├──▶ classifyDiarrhoea()    ──▶ ConditionResult
    ├──▶ classifyFever()        ──▶ ConditionResult
    │
    └──▶ Aggregation: worst flag wins (RED > YELLOW > GREEN)
              │
              ▼
         TriageResult { flag, conditions, rule_trace }
              │
              ▼
         generateReferralNote() ──▶ plain-language referral string
```

## Clinical Rules

### General Danger Signs (any one → 🔴 RED)
- Not able to drink or breastfeed
- Vomits everything
- Convulsions
- Lethargic or unconscious

### Young Infants (<2 months)
- **Any** positive symptom → 🔴 RED (refer immediately)

### Pneumonia (Cough or Difficulty Breathing)
| Signs | Classification | Flag |
|-------|---------------|------|
| Danger sign / chest indrawing / stridor | SEVERE_PNEUMONIA | 🔴 RED |
| Fast breathing only | PNEUMONIA | 🟡 YELLOW |
| Neither | NO_PNEUMONIA | 🟢 GREEN |

**RR cutoffs:** <2mo: ≥60 · 2–11mo: ≥50 · ≥12mo: ≥40

### Diarrhoea (Dehydration)
| Signs (≥2 from row) | Classification | Flag |
|---------------------|---------------|------|
| Lethargic, sunken eyes, poor drinking, very slow pinch | SEVERE_DEHYDRATION | 🔴 RED |
| Restless, sunken eyes, eager/thirsty, slow pinch | SOME_DEHYDRATION | 🟡 YELLOW |
| <2 signs | NO_DEHYDRATION | 🟢 GREEN |

**Modifiers:** Blood in stool → +DYSENTERY · ≥14 days → +PERSISTENT

### Fever (Simplified)
| Signs | Classification | Flag |
|-------|---------------|------|
| Stiff neck | VERY_SEVERE_FEBRILE_DISEASE | 🔴 RED |
| ≥7 days | FEVER_PROLONGED | 🟡 YELLOW |
| Otherwise | FEVER | 🟡 YELLOW |

### Safety: Fail-Safe Defaults
- **Missing data → YELLOW** ("insufficient data, complete assessment manually")
- **Never** defaults to GREEN on incomplete input

## API Usage

```typescript
import { classify, generateReferralNote, TriageInput } from './src';

const input: TriageInput = {
  patient: { age_months: 8 },
  vitals: { resp_rate_bpm: 58, temp_c: 38.6 },
  symptoms: {
    cough_or_difficulty_breathing: true,
    chest_indrawing: false,
    fever_days: 1,
  },
};

const result = classify(input);
console.log(result.flag);        // "yellow"
console.log(result.rule_trace);  // ["general danger signs: none present", "pneumonia: RR 58 >= 50..."]

const note = generateReferralNote(input, result);
console.log(note);
// "Suspected pneumonia — fast breathing (58/min), fever 38.6°C in 8-month-old, no danger signs. Refer to PHC within 24h."
```

## Test Suite

20 test cases covering all IMNCI scenarios:

| # | Condition | Expected |
|---|-----------|----------|
| 1–4 | Pneumonia (standard) | GREEN/YELLOW/RED |
| 5–6 | Pneumonia (boundary: exact cutoff, young infant) | YELLOW/RED |
| 7 | Danger sign short-circuit | RED |
| 8–10 | Diarrhoea (3 tiers) | GREEN/YELLOW/RED |
| 11–12 | Diarrhoea modifiers (persistent, dysentery) | YELLOW |
| 13 | Diarrhoea edge (1 sign < threshold) | GREEN |
| 14–16 | Fever (simple, prolonged, stiff neck) | YELLOW/RED |
| 17 | Aggregation (worst flag wins) | RED |
| 18 | Fail-safe (empty data) | YELLOW |
| 19 | Referral note generation | format check |
| 20 | Young infant <2mo | RED |

```bash
npm test
```

## Why Rules, Not ML?

1. **Explainability** — every flag ships with a `rule_trace`; a health worker can see exactly which sign triggered it.
2. **Deterministic safety** — the referral note is templated, never hallucinated.
3. **Validated** — the engine is tested against hand-written IMNCI test cases, not trained on data.

## Setup

```bash
npm install
npm test        # Run all 20 test cases
npm run build   # Compile to dist/
```

## License

MIT
