/**
 * Triage Decision Engine — Core Classification Logic
 *
 * Deterministic, rule-based WHO IMCI / India's IMNCI engine.
 * NO machine learning. NO free-text generation.
 *
 * Clinical rules source:
 *   NHM IMNCI Chart Booklet (MoHFW India)
 *   https://nhm.gov.in/images/pdf/programmes/child-health/guidelines/imnci_chart_booklet.pdf
 *
 * Safety invariants:
 *   1. General danger signs short-circuit to RED immediately.
 *   2. Young infants (<2 months) with ANY positive symptom → RED.
 *   3. Worst flag wins across conditions (RED > YELLOW > GREEN).
 *   4. Missing / incomplete data → YELLOW ("insufficient data"), NEVER GREEN.
 */

import {
  Flag,
  TriageInput,
  ConditionResult,
  TriageResult,
} from "./types";

// ─── Flag Ranking (used for worst-flag-wins aggregation) ─────

export const FLAG_RANK: Record<Flag, number> = {
  green: 0,
  yellow: 1,
  red: 2,
};

// ─── Step 1: General Danger Signs ────────────────────────────
// IMNCI §3.1 — Child 2 months – 5 years
// Any ONE of these → automatic RED, skip everything else.

export function checkGeneralDangerSigns(i: TriageInput): string[] {
  const s = i.symptoms;
  const present: string[] = [];

  if (s.not_able_to_drink_or_breastfeed)
    present.push("not able to drink/breastfeed");
  if (s.vomits_everything) present.push("vomits everything");
  if (s.convulsions) present.push("convulsions");
  if (s.lethargic_or_unconscious) present.push("lethargic or unconscious");

  return present;
}

// ─── Step 2a: Pneumonia Classification ───────────────────────
// IMNCI §3.3 — Cough or Difficulty Breathing
//
// Fast-breathing cutoffs:
//   < 2 months:         RR ≥ 60/min
//   2 months – < 12 mo: RR ≥ 50/min
//   12 months – 5 yr:   RR ≥ 40/min  (12mo exactly uses 40)
//
// Scope decision for <2mo: route any positive sign → RED
// (young-infant chart has almost no yellow middle ground).

export function classifyPneumonia(
  i: TriageInput
): ConditionResult | null {
  const s = i.symptoms;
  const v = i.vitals;
  const ageM = i.patient.age_months;

  // Guard: only classify if cough/difficulty breathing is reported
  if (!s.cough_or_difficulty_breathing) return null;

  // Determine RR cutoff by age band
  const rrCutoff = ageM < 2 ? 60 : ageM < 12 ? 50 : 40;
  const fastBreathing = (v.resp_rate_bpm ?? 0) >= rrCutoff;

  // §3.2 — Young infant (<2 months) with any positive respiratory sign
  // → RED / POSSIBLE_SERIOUS_BACTERIAL_INFECTION
  if (
    ageM < 2 &&
    (fastBreathing || s.chest_indrawing || s.stridor_calm_child)
  ) {
    return {
      name: "pneumonia",
      classification: "POSSIBLE_SERIOUS_BACTERIAL_INFECTION",
      flag: "red",
      reasonTrace: [
        `age ${ageM}mo (<2mo) with positive sign -> refer per young-infant scope decision`,
      ],
    };
  }

  // Severe pneumonia: chest indrawing OR stridor in a calm child
  if (s.chest_indrawing || s.stridor_calm_child) {
    return {
      name: "pneumonia",
      classification: "SEVERE_PNEUMONIA",
      flag: "red",
      reasonTrace: [
        `chest_indrawing=${!!s.chest_indrawing}, stridor=${!!s.stridor_calm_child}`,
      ],
    };
  }

  // Pneumonia: fast breathing only
  if (fastBreathing) {
    return {
      name: "pneumonia",
      classification: "PNEUMONIA",
      flag: "yellow",
      reasonTrace: [
        `RR ${v.resp_rate_bpm} >= cutoff ${rrCutoff} for age ${ageM}mo`,
      ],
    };
  }

  // No pneumonia
  return {
    name: "pneumonia",
    classification: "NO_PNEUMONIA",
    flag: "green",
    reasonTrace: ["below RR cutoff, no indrawing/stridor"],
  };
}

// ─── Step 2b: Diarrhoea Classification ──────────────────────
// IMNCI §3.4 — Diarrhoea → Dehydration
//
// Severe dehydration (≥2 of): lethargic/unconscious, sunken eyes,
//   not able to drink / drinking poorly, skin pinch very slow.
// Some dehydration (≥2 of): restless/irritable, sunken eyes,
//   drinking eagerly/thirsty, skin pinch slow.
//
// Modifiers (never downgrade, only raise):
//   blood_in_stool → +DYSENTERY
//   diarrhoea_days ≥ 14 → +PERSISTENT

export function classifyDiarrhoea(
  i: TriageInput
): ConditionResult | null {
  const s = i.symptoms;

  // Guard: only classify if diarrhoea is reported
  if (!s.diarrhoea) return null;

  // Count severe-row signs
  const severeCount = [
    s.lethargic_or_unconscious,
    s.sunken_eyes,
    s.drinking === "poor_or_unable",
    s.skin_pinch === "very_slow",
  ].filter(Boolean).length;

  // Count some-row signs
  const someCount = [
    s.restless_irritable,
    s.sunken_eyes,
    s.drinking === "eager_thirsty",
    s.skin_pinch === "slow",
  ].filter(Boolean).length;

  // Determine base classification
  const result: ConditionResult =
    severeCount >= 2
      ? {
          name: "diarrhoea",
          classification: "SEVERE_DEHYDRATION",
          flag: "red",
          reasonTrace: [`${severeCount} severe-row signs`],
        }
      : someCount >= 2
      ? {
          name: "diarrhoea",
          classification: "SOME_DEHYDRATION",
          flag: "yellow",
          reasonTrace: [`${someCount} some-row signs`],
        }
      : {
          name: "diarrhoea",
          classification: "NO_DEHYDRATION",
          flag: "green",
          reasonTrace: ["<2 signs in either row"],
        };

  // Modifier: Dysentery (blood in stool)
  if (s.blood_in_stool) {
    result.classification += "+DYSENTERY";
    result.reasonTrace.push("blood in stool -> dysentery");
    if (result.flag === "green") result.flag = "yellow";
  }

  // Modifier: Persistent diarrhoea (≥14 days)
  if ((s.diarrhoea_days ?? 0) >= 14) {
    result.classification += "+PERSISTENT";
    result.reasonTrace.push(
      `diarrhoea_days=${s.diarrhoea_days} >= 14 -> persistent, refer for assessment`
    );
    if (result.flag === "green") result.flag = "yellow";
  }

  return result;
}

// ─── Step 2c: Fever Classification ──────────────────────────
// IMNCI §3.5 — Simplified for 16-hour demo (no malaria-risk branch)
//
// Fever present if temp_c ≥ 37.5 OR fever_days > 0
// Stiff neck → RED (VERY_SEVERE_FEBRILE_DISEASE)
// fever_days ≥ 7 → YELLOW (FEVER_PROLONGED, refer)
// Otherwise → YELLOW (FEVER, home-care advice)
//
// Note: general danger signs + fever are caught by
// checkGeneralDangerSigns(), not duplicated here.

export function classifyFever(
  i: TriageInput
): ConditionResult | null {
  const s = i.symptoms;
  const hasFever =
    (i.vitals.temp_c ?? 0) >= 37.5 || (s.fever_days ?? 0) > 0;

  // Guard: only classify if fever is present
  if (!hasFever) return null;

  // Stiff neck → Very Severe Febrile Disease
  if (s.stiff_neck) {
    return {
      name: "fever",
      classification: "VERY_SEVERE_FEBRILE_DISEASE",
      flag: "red",
      reasonTrace: ["stiff neck present"],
    };
  }

  // Prolonged fever (≥7 days) → refer for assessment
  if ((s.fever_days ?? 0) >= 7) {
    return {
      name: "fever",
      classification: "FEVER_PROLONGED",
      flag: "yellow",
      reasonTrace: [
        `fever_days=${s.fever_days} >= 7 -> refer for assessment`,
      ],
    };
  }

  // Fever, no danger sign, no stiff neck, <7 days
  return {
    name: "fever",
    classification: "FEVER",
    flag: "yellow",
    reasonTrace: ["fever, no danger sign, no stiff neck, <7 days"],
  };
}

// ─── Step 3: Aggregation — Worst Flag Wins ──────────────────
// §3.6 — Combine all conditions.
// Fail-safe: missing data → YELLOW, NEVER GREEN.

export function classify(i: TriageInput): TriageResult {
  // 1. Check general danger signs first (short-circuit to RED)
  const dangerSigns = checkGeneralDangerSigns(i);

  // 2. Young infant (<2 months) catch-all — §3.2
  // "Route every <2-month-old with any positive symptom straight to RED"
  // This catches cases the per-condition classifiers might miss
  // (e.g., 1mo with RR 58 — below the 60 cutoff but still needs referral).
  if (i.patient.age_months < 2 && dangerSigns.length === 0) {
    const hasAnyPositive = Object.values(i.symptoms).some((v) => {
      if (typeof v === "boolean") return v === true;
      if (typeof v === "number") return v > 0;
      if (typeof v === "string") return v !== "immediate" && v !== "normal";
      return false;
    });
    if (hasAnyPositive) {
      dangerSigns.push("young infant (<2mo) with positive symptom");
    }
  }

  // 3. Run per-condition classifiers
  const conditions = [
    classifyPneumonia(i),
    classifyDiarrhoea(i),
    classifyFever(i),
  ].filter((c): c is ConditionResult => c !== null);

  // 4. Determine worst flag
  let flag: Flag = dangerSigns.length > 0 ? "red" : "green";

  // Build rule trace
  const trace: string[] = [
    dangerSigns.length > 0
      ? `general danger signs: ${dangerSigns.join(", ")}`
      : "general danger signs: none present",
  ];

  for (const c of conditions) {
    if (FLAG_RANK[c.flag] > FLAG_RANK[flag]) {
      flag = c.flag;
    }
    trace.push(
      `${c.name}: ${c.reasonTrace.join("; ")} -> ${c.classification} (${c.flag})`
    );
  }

  // 5. Fail-safe: if nothing fired and no data was entered → YELLOW
  if (conditions.length === 0 && dangerSigns.length === 0) {
    // Check if symptoms object has any meaningful data
    const hasAnySymptom = Object.values(i.symptoms).some((v) => {
      if (typeof v === "boolean") return v === true;
      if (typeof v === "number") return v > 0;
      if (typeof v === "string") return v !== "immediate" && v !== "normal";
      return false;
    });

    if (!hasAnySymptom) {
      flag = "yellow";
      trace.push(
        "insufficient data entered -> defaulting to YELLOW, complete assessment manually"
      );
    }
  }

  return {
    flag,
    conditions,
    rule_trace: trace,
    override_reason: null,
  };
}
