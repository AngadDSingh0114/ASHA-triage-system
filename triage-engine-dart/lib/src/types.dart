/// Triage Engine — Type Definitions (Dart Port)
///
/// WHO IMCI / India's IMNCI deterministic triage types.
/// Identical logic to the TypeScript version.
library;

// ─── Core Enums ──────────────────────────────────────────────

/// Triage urgency flag. RED > YELLOW > GREEN.
enum Flag { red, yellow, green }

/// Skin-pinch recoil speed — IMNCI dehydration assessment.
enum SkinPinch { immediate, slow, verySlow }

/// Ability to drink — IMNCI dehydration assessment.
enum Drinking { normal, eagerThirsty, poorOrUnable }

/// Sync status for offline-first architecture.
enum SyncStatus { pending, synced, failed }

// ─── Input Classes ───────────────────────────────────────────

class Patient {
  final int ageMonths;
  const Patient({required this.ageMonths});
}

class Vitals {
  final int? respRateBpm;
  final double? tempC;
  final int? pulseBpm;
  const Vitals({this.respRateBpm, this.tempC, this.pulseBpm});
}

class Symptoms {
  // Pneumonia
  final bool? coughOrDifficultyBreathing;
  final bool? chestIndrawing;
  final bool? stridorCalmChild;

  // Diarrhoea
  final bool? diarrhoea;
  final int? diarrhoeaDays;
  final bool? bloodInStool;
  final bool? restlessIrritable;
  final bool? sunkenEyes;
  final SkinPinch? skinPinch;
  final Drinking? drinking;

  // Fever
  final int? feverDays;
  final bool? stiffNeck;

  // General danger signs
  final bool? notAbleToDrinkOrBreastfeed;
  final bool? vomitsEverything;
  final bool? convulsions;
  final bool? lethargicOrUnconscious;

  const Symptoms({
    this.coughOrDifficultyBreathing,
    this.chestIndrawing,
    this.stridorCalmChild,
    this.diarrhoea,
    this.diarrhoeaDays,
    this.bloodInStool,
    this.restlessIrritable,
    this.sunkenEyes,
    this.skinPinch,
    this.drinking,
    this.feverDays,
    this.stiffNeck,
    this.notAbleToDrinkOrBreastfeed,
    this.vomitsEverything,
    this.convulsions,
    this.lethargicOrUnconscious,
  });

  /// Check if no symptom fields were entered (all are null).
  bool get isEmpty {
    final allFields = [
      coughOrDifficultyBreathing,
      chestIndrawing,
      stridorCalmChild,
      diarrhoea,
      diarrhoeaDays,
      bloodInStool,
      restlessIrritable,
      sunkenEyes,
      skinPinch,
      drinking,
      feverDays,
      stiffNeck,
      notAbleToDrinkOrBreastfeed,
      vomitsEverything,
      convulsions,
      lethargicOrUnconscious,
    ];
    return allFields.every((v) => v == null);
  }
}

class TriageInput {
  final Patient patient;
  final Vitals vitals;
  final Symptoms symptoms;
  const TriageInput({
    required this.patient,
    required this.vitals,
    required this.symptoms,
  });
}

// ─── Output Classes ──────────────────────────────────────────

class ConditionResult {
  final String name;
  String classification;
  Flag flag;
  final List<String> reasonTrace;

  ConditionResult({
    required this.name,
    required this.classification,
    required this.flag,
    required this.reasonTrace,
  });
}

class TriageResult {
  final Flag flag;
  final List<ConditionResult> conditions;
  final List<String> ruleTrace;
  final String? overrideReason;

  const TriageResult({
    required this.flag,
    required this.conditions,
    required this.ruleTrace,
    this.overrideReason,
  });
}
