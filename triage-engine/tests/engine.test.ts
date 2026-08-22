/**
 * Triage Engine — Test Suite
 *
 * 20 test cases covering all IMNCI clinical scenarios:
 *   Tests 1–7:  Pneumonia classification (including boundary & danger-sign short-circuit)
 *   Tests 8–13: Diarrhoea classification (dehydration tiers, modifiers, edge cases)
 *   Tests 14–16: Fever classification (simple, prolonged, stiff neck)
 *   Test 17:    Aggregation (worst-flag-wins across conditions)
 *   Test 18:    Fail-safe (empty symptoms → YELLOW)
 *   Test 19:    Referral note generation
 *   Test 20:    Young infant (<2mo) short-circuit
 *
 * Source: WHO IMCI / NHM IMNCI Chart Booklet (MoHFW India)
 */

import {
  classify,
  classifyPneumonia,
  classifyDiarrhoea,
  classifyFever,
  checkGeneralDangerSigns,
  generateReferralNote,
  TriageInput,
} from "../src/index";

// ─── Helper: build a default TriageInput with overrides ──────

function makeInput(overrides: {
  age_months?: number;
  resp_rate_bpm?: number;
  temp_c?: number;
  pulse_bpm?: number;
  symptoms?: Partial<TriageInput["symptoms"]>;
}): TriageInput {
  return {
    patient: { age_months: overrides.age_months ?? 24 },
    vitals: {
      resp_rate_bpm: overrides.resp_rate_bpm,
      temp_c: overrides.temp_c,
      pulse_bpm: overrides.pulse_bpm,
    },
    symptoms: {
      cough_or_difficulty_breathing: false,
      chest_indrawing: false,
      stridor_calm_child: false,
      diarrhoea: false,
      diarrhoea_days: 0,
      blood_in_stool: false,
      restless_irritable: false,
      sunken_eyes: false,
      skin_pinch: "immediate",
      drinking: "normal",
      fever_days: 0,
      stiff_neck: false,
      not_able_to_drink_or_breastfeed: false,
      vomits_everything: false,
      convulsions: false,
      lethargic_or_unconscious: false,
      ...overrides.symptoms,
    },
  };
}

// ═══════════════════════════════════════════════════════════════
// GENERAL DANGER SIGNS
// ═══════════════════════════════════════════════════════════════

describe("General Danger Signs", () => {
  test("no danger signs returns empty array", () => {
    const input = makeInput({});
    expect(checkGeneralDangerSigns(input)).toHaveLength(0);
  });

  test("convulsions detected as danger sign", () => {
    const input = makeInput({ symptoms: { convulsions: true } });
    const signs = checkGeneralDangerSigns(input);
    expect(signs).toContain("convulsions");
  });

  test("all four danger signs detected", () => {
    const input = makeInput({
      symptoms: {
        not_able_to_drink_or_breastfeed: true,
        vomits_everything: true,
        convulsions: true,
        lethargic_or_unconscious: true,
      },
    });
    const signs = checkGeneralDangerSigns(input);
    expect(signs).toHaveLength(4);
  });
});

// ═══════════════════════════════════════════════════════════════
// PNEUMONIA CLASSIFICATION
// ═══════════════════════════════════════════════════════════════

describe("Pneumonia Classification", () => {
  // Test 1: 8mo, RR 58, cough, no indrawing → YELLOW, PNEUMONIA
  test("#1 — 8mo RR 58, cough → PNEUMONIA (yellow)", () => {
    const input = makeInput({
      age_months: 8,
      resp_rate_bpm: 58,
      symptoms: { cough_or_difficulty_breathing: true },
    });
    const result = classifyPneumonia(input);
    expect(result).not.toBeNull();
    expect(result!.flag).toBe("yellow");
    expect(result!.classification).toBe("PNEUMONIA");
  });

  // Test 2: 8mo, RR 45, cough → GREEN, NO_PNEUMONIA
  test("#2 — 8mo RR 45, cough → NO_PNEUMONIA (green)", () => {
    const input = makeInput({
      age_months: 8,
      resp_rate_bpm: 45,
      symptoms: { cough_or_difficulty_breathing: true },
    });
    const result = classifyPneumonia(input);
    expect(result).not.toBeNull();
    expect(result!.flag).toBe("green");
    expect(result!.classification).toBe("NO_PNEUMONIA");
  });

  // Test 3: 36mo, RR 44, chest indrawing → RED, SEVERE_PNEUMONIA
  test("#3 — 36mo chest indrawing → SEVERE_PNEUMONIA (red)", () => {
    const input = makeInput({
      age_months: 36,
      resp_rate_bpm: 44,
      symptoms: {
        cough_or_difficulty_breathing: true,
        chest_indrawing: true,
      },
    });
    const result = classifyPneumonia(input);
    expect(result).not.toBeNull();
    expect(result!.flag).toBe("red");
    expect(result!.classification).toBe("SEVERE_PNEUMONIA");
  });

  // Test 4: 36mo, RR 38, no signs → GREEN, NO_PNEUMONIA
  test("#4 — 36mo RR 38, cough only → NO_PNEUMONIA (green)", () => {
    const input = makeInput({
      age_months: 36,
      resp_rate_bpm: 38,
      symptoms: { cough_or_difficulty_breathing: true },
    });
    const result = classifyPneumonia(input);
    expect(result).not.toBeNull();
    expect(result!.flag).toBe("green");
    expect(result!.classification).toBe("NO_PNEUMONIA");
  });

  // Test 5 (edge): 5mo, RR exactly 50 → YELLOW, PNEUMONIA (boundary inclusive)
  test("#5 — 5mo RR exactly 50 → PNEUMONIA (boundary inclusive)", () => {
    const input = makeInput({
      age_months: 5,
      resp_rate_bpm: 50,
      symptoms: { cough_or_difficulty_breathing: true },
    });
    const result = classifyPneumonia(input);
    expect(result).not.toBeNull();
    expect(result!.flag).toBe("yellow");
    expect(result!.classification).toBe("PNEUMONIA");
  });

  // Test 6 (edge): 1mo, RR 58, cough — below 60 cutoff but <2mo scope → RED
  test("#6 — 1mo RR 58, cough → RED per young-infant scope", () => {
    const input = makeInput({
      age_months: 1,
      resp_rate_bpm: 58,
      symptoms: { cough_or_difficulty_breathing: true },
    });
    // 1mo is <2mo. RR 58 < 60 cutoff, so fastBreathing is false.
    // But the <2mo scope decision routes any positive cough to RED
    // because classifyPneumonia is only called when cough=true,
    // and for <2mo we check (fastBreathing || chest_indrawing || stridor).
    // fastBreathing is false (58 < 60), but the function is entered
    // because cough_or_difficulty_breathing=true.
    // Per §3.2 scope: "route every <2-month-old with any positive symptom straight to RED"
    // Since cough itself is a positive symptom, the classify() aggregator
    // should produce RED via the young-infant path or danger signs.
    // In classifyPneumonia, the <2mo guard checks fastBreathing||indrawing||stridor.
    // 58 < 60, no indrawing, no stridor → none of those are true.
    // So classifyPneumonia returns NO_PNEUMONIA (green) for this case.
    // The §3.2 young-infant catch-all must be in classify(), not classifyPneumonia().
    // Let's verify via the full classify() instead:
    const fullResult = classify(input);
    expect(fullResult.flag).toBe("red");
  });

  // Test 7: any age, convulsions=true + cough → RED overall (short-circuit)
  test("#7 — convulsions + cough → RED (danger sign short-circuit)", () => {
    const input = makeInput({
      age_months: 24,
      resp_rate_bpm: 30,
      symptoms: {
        cough_or_difficulty_breathing: true,
        convulsions: true,
      },
    });
    const result = classify(input);
    expect(result.flag).toBe("red");
    expect(result.rule_trace[0]).toContain("convulsions");
  });

  // No cough → classifyPneumonia returns null
  test("no cough → returns null", () => {
    const input = makeInput({
      age_months: 8,
      resp_rate_bpm: 60,
      symptoms: { cough_or_difficulty_breathing: false },
    });
    expect(classifyPneumonia(input)).toBeNull();
  });
});

// ═══════════════════════════════════════════════════════════════
// DIARRHOEA CLASSIFICATION
// ═══════════════════════════════════════════════════════════════

describe("Diarrhoea Classification", () => {
  // Test 8: 4mo, 5 days, restless + sunken eyes, skin_pinch=slow → YELLOW, SOME_DEHYDRATION
  test("#8 — restless + sunken eyes + slow pinch → SOME_DEHYDRATION (yellow)", () => {
    const input = makeInput({
      age_months: 4,
      symptoms: {
        diarrhoea: true,
        diarrhoea_days: 5,
        restless_irritable: true,
        sunken_eyes: true,
        skin_pinch: "slow",
      },
    });
    const result = classifyDiarrhoea(input);
    expect(result).not.toBeNull();
    expect(result!.flag).toBe("yellow");
    expect(result!.classification).toBe("SOME_DEHYDRATION");
  });

  // Test 9: 15mo, lethargic + sunken eyes + poor drinking + very slow pinch → RED
  test("#9 — 4 severe signs → SEVERE_DEHYDRATION (red)", () => {
    const input = makeInput({
      age_months: 15,
      symptoms: {
        diarrhoea: true,
        diarrhoea_days: 5,
        lethargic_or_unconscious: true,
        sunken_eyes: true,
        drinking: "poor_or_unable",
        skin_pinch: "very_slow",
      },
    });
    const result = classifyDiarrhoea(input);
    expect(result).not.toBeNull();
    expect(result!.flag).toBe("red");
    expect(result!.classification).toBe("SEVERE_DEHYDRATION");
  });

  // Test 10: 24mo, 3 days, no signs → GREEN, NO_DEHYDRATION
  test("#10 — no dehydration signs → NO_DEHYDRATION (green)", () => {
    const input = makeInput({
      age_months: 24,
      symptoms: {
        diarrhoea: true,
        diarrhoea_days: 3,
      },
    });
    const result = classifyDiarrhoea(input);
    expect(result).not.toBeNull();
    expect(result!.flag).toBe("green");
    expect(result!.classification).toBe("NO_DEHYDRATION");
  });

  // Test 11: 6mo, 20 days, no dehydration → YELLOW, includes PERSISTENT
  test("#11 — 20 days diarrhoea → PERSISTENT modifier (yellow)", () => {
    const input = makeInput({
      age_months: 6,
      symptoms: {
        diarrhoea: true,
        diarrhoea_days: 20,
      },
    });
    const result = classifyDiarrhoea(input);
    expect(result).not.toBeNull();
    expect(result!.flag).toBe("yellow");
    expect(result!.classification).toContain("PERSISTENT");
  });

  // Test 12: 36mo, blood in stool, no dehydration → YELLOW, includes DYSENTERY
  test("#12 — blood in stool → DYSENTERY modifier (yellow)", () => {
    const input = makeInput({
      age_months: 36,
      symptoms: {
        diarrhoea: true,
        diarrhoea_days: 2,
        blood_in_stool: true,
      },
    });
    const result = classifyDiarrhoea(input);
    expect(result).not.toBeNull();
    expect(result!.flag).toBe("yellow");
    expect(result!.classification).toContain("DYSENTERY");
  });

  // Test 13 (edge): 4mo, restless only (1 sign) → GREEN (needs ≥2)
  test("#13 — 1 some-sign only → NO_DEHYDRATION (green, needs ≥2)", () => {
    const input = makeInput({
      age_months: 4,
      symptoms: {
        diarrhoea: true,
        diarrhoea_days: 3,
        restless_irritable: true,
      },
    });
    const result = classifyDiarrhoea(input);
    expect(result).not.toBeNull();
    expect(result!.flag).toBe("green");
    expect(result!.classification).toBe("NO_DEHYDRATION");
  });

  // No diarrhoea → null
  test("no diarrhoea → returns null", () => {
    const input = makeInput({
      symptoms: { diarrhoea: false },
    });
    expect(classifyDiarrhoea(input)).toBeNull();
  });
});

// ═══════════════════════════════════════════════════════════════
// FEVER CLASSIFICATION
// ═══════════════════════════════════════════════════════════════

describe("Fever Classification", () => {
  // Test 14: 24mo, 2 days fever, temp 38.5 → YELLOW, FEVER
  test("#14 — 2 days fever, 38.5°C → FEVER (yellow)", () => {
    const input = makeInput({
      age_months: 24,
      temp_c: 38.5,
      symptoms: { fever_days: 2 },
    });
    const result = classifyFever(input);
    expect(result).not.toBeNull();
    expect(result!.flag).toBe("yellow");
    expect(result!.classification).toBe("FEVER");
  });

  // Test 15: 24mo, 8 days fever → YELLOW, FEVER_PROLONGED
  test("#15 — 8 days fever → FEVER_PROLONGED (yellow)", () => {
    const input = makeInput({
      age_months: 24,
      symptoms: { fever_days: 8 },
    });
    const result = classifyFever(input);
    expect(result).not.toBeNull();
    expect(result!.flag).toBe("yellow");
    expect(result!.classification).toBe("FEVER_PROLONGED");
  });

  // Test 16: 18mo, 1 day, stiff neck → RED, VERY_SEVERE_FEBRILE_DISEASE
  test("#16 — stiff neck → VERY_SEVERE_FEBRILE_DISEASE (red)", () => {
    const input = makeInput({
      age_months: 18,
      symptoms: {
        fever_days: 1,
        stiff_neck: true,
      },
    });
    const result = classifyFever(input);
    expect(result).not.toBeNull();
    expect(result!.flag).toBe("red");
    expect(result!.classification).toBe("VERY_SEVERE_FEBRILE_DISEASE");
  });

  // No fever → null
  test("no fever → returns null", () => {
    const input = makeInput({
      temp_c: 36.5,
      symptoms: { fever_days: 0 },
    });
    expect(classifyFever(input)).toBeNull();
  });
});

// ═══════════════════════════════════════════════════════════════
// EAR PROBLEM CLASSIFICATION
// ═══════════════════════════════════════════════════════════════

describe("Ear Problem Classification", () => {
  // Test 21: mastoid swelling → RED
  test("#21 — mastoid swelling → MASTOIDITIS (red)", () => {
    const input = makeInput({
      symptoms: { mastoid_swelling: true },
    });
    const result = classify(input);
    expect(result.flag).toBe("red");
    const earCondition = result.conditions.find((c) => c.name === "ear problem");
    expect(earCondition).toBeDefined();
    expect(earCondition!.classification).toBe("MASTOIDITIS");
  });

  // Test 22: ear pain or discharge → YELLOW
  test("#22 — ear pain/discharge → ACUTE_EAR_INFECTION (yellow)", () => {
    const input = makeInput({
      symptoms: { ear_pain_or_discharge: true },
    });
    const result = classify(input);
    expect(result.flag).toBe("yellow");
    const earCondition = result.conditions.find((c) => c.name === "ear problem");
    expect(earCondition).toBeDefined();
    expect(earCondition!.classification).toBe("ACUTE_EAR_INFECTION");
  });

  test("no ear problem → returns null", () => {
    const input = makeInput({});
    const result = classify(input);
    const earCondition = result.conditions.find((c) => c.name === "ear problem");
    expect(earCondition).toBeUndefined();
  });
});

// ═══════════════════════════════════════════════════════════════
// AGGREGATION — WORST FLAG WINS
// ═══════════════════════════════════════════════════════════════

describe("Aggregation", () => {
  // Test 17: 8mo, RR 55 (yellow pneumonia) + severe dehydration (red) → RED overall
  test("#17 — pneumonia(yellow) + severe dehydration(red) → RED overall", () => {
    const input = makeInput({
      age_months: 8,
      resp_rate_bpm: 55,
      symptoms: {
        cough_or_difficulty_breathing: true,
        diarrhoea: true,
        diarrhoea_days: 5,
        lethargic_or_unconscious: true,
        sunken_eyes: true,
        drinking: "poor_or_unable",
        skin_pinch: "very_slow",
      },
    });
    const result = classify(input);
    expect(result.flag).toBe("red");
    // Both conditions should appear in the results
    const conditionNames = result.conditions.map((c) => c.name);
    expect(conditionNames).toContain("pneumonia");
    expect(conditionNames).toContain("diarrhoea");
    // Rule trace should mention both
    expect(result.rule_trace.length).toBeGreaterThanOrEqual(2);
  });

  test("multiple YELLOW conditions stay YELLOW", () => {
    const input = makeInput({
      age_months: 8,
      resp_rate_bpm: 55,
      temp_c: 38.5,
      symptoms: {
        cough_or_difficulty_breathing: true,
        fever_days: 2,
      },
    });
    const result = classify(input);
    expect(result.flag).toBe("yellow");
  });
});

// ═══════════════════════════════════════════════════════════════
// FAIL-SAFE — MISSING DATA → YELLOW, NEVER GREEN
// ═══════════════════════════════════════════════════════════════

describe("Fail-safe", () => {
  // Test 18: Empty symptoms → RED
  test("#18 — empty symptoms → RED (insufficient data)", () => {
    const input: TriageInput = {
      patient: { age_months: 12 },
      vitals: {},
      symptoms: {},
    };
    const result = classify(input);
    expect(result.flag).toBe("red");
    expect(
      result.rule_trace.some((t) => t.includes("insufficient data"))
    ).toBe(true);
  });

  test("all symptoms explicitly false → GREEN", () => {
    const input = makeInput({
      age_months: 12,
      symptoms: {
        cough_or_difficulty_breathing: false,
        diarrhoea: false,
        fever_days: 0,
        convulsions: false,
        lethargic_or_unconscious: false,
        vomits_everything: false,
        not_able_to_drink_or_breastfeed: false,
      },
    });
    const result = classify(input);
    expect(result.flag).toBe("green");
    expect(
      result.rule_trace.some((t) => t.includes("insufficient data"))
    ).toBe(false);
  });
});

// ═══════════════════════════════════════════════════════════════
// REFERRAL NOTE GENERATION
// ═══════════════════════════════════════════════════════════════

describe("Referral Notes", () => {
  // Test 19: Referral note matches expected format
  test("#19 — generates correct referral note for pneumonia", () => {
    const input = makeInput({
      age_months: 8,
      resp_rate_bpm: 58,
      symptoms: { cough_or_difficulty_breathing: true },
    });
    const result = classify(input);
    const note = generateReferralNote(input, result);
    expect(note).toContain("8-month-old");
    expect(note).toContain("58/min");
    expect(note).toContain("within 24h");
    expect(note).toContain("no danger signs");
  });

  test("RED case → URGENTLY in referral note", () => {
    const input = makeInput({
      age_months: 36,
      resp_rate_bpm: 44,
      symptoms: {
        cough_or_difficulty_breathing: true,
        chest_indrawing: true,
      },
    });
    const result = classify(input);
    const note = generateReferralNote(input, result);
    expect(note).toContain("URGENTLY");
    expect(note).toContain("3-year-old");
  });

  test("age >= 12mo → year-old label", () => {
    const input = makeInput({
      age_months: 24,
      temp_c: 38.5,
      symptoms: { fever_days: 2 },
    });
    const result = classify(input);
    const note = generateReferralNote(input, result);
    expect(note).toContain("2-year-old");
  });
});

// ═══════════════════════════════════════════════════════════════
// YOUNG INFANT (<2 MONTHS) SHORT-CIRCUIT
// ═══════════════════════════════════════════════════════════════

describe("Young Infant (<2mo)", () => {
  // Test 20: <2mo with any positive symptom → RED
  test("#20 — 1mo with cough + RR 62 → RED (young infant)", () => {
    const input = makeInput({
      age_months: 1,
      resp_rate_bpm: 62,
      symptoms: { cough_or_difficulty_breathing: true },
    });
    const result = classify(input);
    expect(result.flag).toBe("red");
    const pneumonia = result.conditions.find((c) => c.name === "pneumonia");
    expect(pneumonia).toBeDefined();
    expect(pneumonia!.classification).toBe(
      "POSSIBLE_SERIOUS_BACTERIAL_INFECTION"
    );
  });

  test("0mo with chest indrawing + cough → RED", () => {
    const input = makeInput({
      age_months: 0,
      symptoms: {
        cough_or_difficulty_breathing: true,
        chest_indrawing: true,
      },
    });
    const result = classify(input);
    expect(result.flag).toBe("red");
  });
});
