/// Triage Decision Engine — Core Classification Logic (Dart Port)
///
/// Deterministic, rule-based WHO IMCI / India's IMNCI engine.
/// NO machine learning. NO free-text generation.
///
/// Clinical rules source:
///   NHM IMNCI Chart Booklet (MoHFW India)
///   https://nhm.gov.in/images/pdf/programmes/child-health/guidelines/imnci_chart_booklet.pdf
///
/// Safety invariants:
///   1. General danger signs short-circuit to RED immediately.
///   2. Young infants (<2 months) with ANY positive symptom → RED.
///   3. Worst flag wins across conditions (RED > YELLOW > GREEN).
///   4. Missing / incomplete data → YELLOW ("insufficient data"), NEVER GREEN.
library;

import 'types.dart';

// ─── Flag Ranking ────────────────────────────────────────────

const Map<Flag, int> flagRank = {
  Flag.green: 0,
  Flag.yellow: 1,
  Flag.red: 2,
};

// ─── Step 1: General Danger Signs ────────────────────────────

List<String> checkGeneralDangerSigns(TriageInput i) {
  final s = i.symptoms;
  final present = <String>[];

  if (s.notAbleToDrinkOrBreastfeed == true) {
    present.add('not able to drink/breastfeed');
  }
  if (s.vomitsEverything == true) {
    present.add('vomits everything');
  }
  if (s.convulsions == true) {
    present.add('convulsions');
  }
  if (s.lethargicOrUnconscious == true) {
    present.add('lethargic or unconscious');
  }

  return present;
}

// ─── Step 2a: Pneumonia Classification ───────────────────────

ConditionResult? classifyPneumonia(TriageInput i) {
  final s = i.symptoms;
  final v = i.vitals;
  final ageM = i.patient.ageMonths;

  if (s.coughOrDifficultyBreathing != true) return null;

  final rrCutoff = ageM < 2 ? 60 : (ageM < 12 ? 50 : 40);
  final fastBreathing = (v.respRateBpm ?? 0) >= rrCutoff;

  // Young infant (<2mo) with any positive respiratory sign → RED
  if (ageM < 2 &&
      (fastBreathing ||
          s.chestIndrawing == true ||
          s.stridorCalmChild == true)) {
    return ConditionResult(
      name: 'pneumonia',
      classification: 'POSSIBLE_SERIOUS_BACTERIAL_INFECTION',
      flag: Flag.red,
      reasonTrace: [
        'age ${ageM}mo (<2mo) with positive sign -> refer per young-infant scope decision',
      ],
    );
  }

  // Severe pneumonia
  if (s.chestIndrawing == true || s.stridorCalmChild == true) {
    return ConditionResult(
      name: 'pneumonia',
      classification: 'SEVERE_PNEUMONIA',
      flag: Flag.red,
      reasonTrace: [
        'chest_indrawing=${s.chestIndrawing == true}, stridor=${s.stridorCalmChild == true}',
      ],
    );
  }

  // Pneumonia: fast breathing only
  if (fastBreathing) {
    return ConditionResult(
      name: 'pneumonia',
      classification: 'PNEUMONIA',
      flag: Flag.yellow,
      reasonTrace: [
        'RR ${v.respRateBpm} >= cutoff $rrCutoff for age ${ageM}mo',
      ],
    );
  }

  // No pneumonia
  return ConditionResult(
    name: 'pneumonia',
    classification: 'NO_PNEUMONIA',
    flag: Flag.green,
    reasonTrace: ['below RR cutoff, no indrawing/stridor'],
  );
}

// ─── Step 2b: Diarrhoea Classification ──────────────────────

ConditionResult? classifyDiarrhoea(TriageInput i) {
  final s = i.symptoms;

  if (s.diarrhoea != true) return null;

  // Count severe-row signs
  final severeCount = [
    s.lethargicOrUnconscious == true,
    s.sunkenEyes == true,
    s.drinking == Drinking.poorOrUnable,
    s.skinPinch == SkinPinch.verySlow,
  ].where((v) => v).length;

  // Count some-row signs
  final someCount = [
    s.restlessIrritable == true,
    s.sunkenEyes == true,
    s.drinking == Drinking.eagerThirsty,
    s.skinPinch == SkinPinch.slow,
  ].where((v) => v).length;

  // Determine base classification
  final ConditionResult result;
  if (severeCount >= 2) {
    result = ConditionResult(
      name: 'diarrhoea',
      classification: 'SEVERE_DEHYDRATION',
      flag: Flag.red,
      reasonTrace: ['$severeCount severe-row signs'],
    );
  } else if (someCount >= 2) {
    result = ConditionResult(
      name: 'diarrhoea',
      classification: 'SOME_DEHYDRATION',
      flag: Flag.yellow,
      reasonTrace: ['$someCount some-row signs'],
    );
  } else {
    result = ConditionResult(
      name: 'diarrhoea',
      classification: 'NO_DEHYDRATION',
      flag: Flag.green,
      reasonTrace: ['<2 signs in either row'],
    );
  }

  // Modifier: Dysentery
  if (s.bloodInStool == true) {
    result.classification += '+DYSENTERY';
    result.reasonTrace.add('blood in stool -> dysentery');
    if (result.flag == Flag.green) result.flag = Flag.yellow;
  }

  // Modifier: Persistent diarrhoea (≥14 days)
  if ((s.diarrhoeaDays ?? 0) >= 14) {
    result.classification += '+PERSISTENT';
    result.reasonTrace
        .add('diarrhoea_days=${s.diarrhoeaDays} >= 14 -> persistent, refer for assessment');
    if (result.flag == Flag.green) result.flag = Flag.yellow;
  }

  return result;
}

// ─── Step 2c: Fever Classification ──────────────────────────

ConditionResult? classifyFever(TriageInput i) {
  final s = i.symptoms;
  final hasFever = (i.vitals.tempC ?? 0) >= 37.5 || (s.feverDays ?? 0) > 0;

  if (!hasFever) return null;

  if (s.stiffNeck == true) {
    return ConditionResult(
      name: 'fever',
      classification: 'VERY_SEVERE_FEBRILE_DISEASE',
      flag: Flag.red,
      reasonTrace: ['stiff neck present'],
    );
  }

  if ((s.feverDays ?? 0) >= 7) {
    return ConditionResult(
      name: 'fever',
      classification: 'FEVER_PROLONGED',
      flag: Flag.yellow,
      reasonTrace: ['fever_days=${s.feverDays} >= 7 -> refer for assessment'],
    );
  }

  return ConditionResult(
    name: 'fever',
    classification: 'FEVER',
    flag: Flag.yellow,
    reasonTrace: ['fever, no danger sign, no stiff neck, <7 days'],
  );
}

// ─── Step 3: Aggregation — Worst Flag Wins ──────────────────

TriageResult classify(TriageInput i) {
  // 1. Check general danger signs
  final dangerSigns = checkGeneralDangerSigns(i);

  // 2. Young infant (<2mo) catch-all — §3.2
  if (i.patient.ageMonths < 2 && dangerSigns.isEmpty) {
    if (!i.symptoms.isEmpty) {
      dangerSigns.add('young infant (<2mo) with positive symptom');
    }
  }

  // 3. Run per-condition classifiers
  final conditions = <ConditionResult?>[
    classifyPneumonia(i),
    classifyDiarrhoea(i),
    classifyFever(i),
  ].whereType<ConditionResult>().toList();

  // 4. Determine worst flag
  var flag = dangerSigns.isNotEmpty ? Flag.red : Flag.green;

  final trace = <String>[
    dangerSigns.isNotEmpty
        ? 'general danger signs: ${dangerSigns.join(", ")}'
        : 'general danger signs: none present',
  ];

  for (final c in conditions) {
    if (flagRank[c.flag]! > flagRank[flag]!) {
      flag = c.flag;
    }
    trace.add(
      '${c.name}: ${c.reasonTrace.join("; ")} -> ${c.classification} (${c.flag.name})',
    );
  }

  // 5. Fail-safe
  if (conditions.isEmpty && dangerSigns.isEmpty && i.symptoms.isEmpty) {
    flag = Flag.red;
    trace.add(
      'insufficient data entered -> defaulting to RED, complete assessment manually',
    );
  }

  return TriageResult(
    flag: flag,
    conditions: conditions,
    ruleTrace: trace,
    overrideReason: null,
  );
}
