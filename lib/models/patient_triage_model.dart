enum TriageSeverity { red, yellow, green }

enum SyncStatus { offlineQueued, syncing, synced }

class Patient {
  final String id;
  String name;
  DateTime? birthdate;
  int ageMonths;
  String gender;
  String village;
  String guardianName;
  String patientPhone;
  String illnessOnset;

  Patient({
    required this.id,
    this.name = '',
    this.birthdate,
    this.ageMonths = 0,
    this.gender = 'Male',
    this.village = '',
    this.guardianName = '',
    this.patientPhone = '',
    this.illnessOnset = '',
  });

  String get ageDisplay {
    if (birthdate != null) {
      final now = DateTime.now();
      int months = (now.year - birthdate!.year) * 12 + (now.month - birthdate!.month);
      if (months < 0) months = 0;
      if (months < 24) {
        return '$months mos';
      } else {
        return '${(months / 12).floor()} yrs';
      }
    }
    if (ageMonths < 24) {
      return '$ageMonths mos';
    } else {
      return '${(ageMonths / 12).floor()} yrs';
    }
  }
}

class Vitals {
  double temperatureF;
  int respiratoryRate;
  int heartRate;
  int spo2;
  int feverDays;
  int? systolicBp;
  int? diastolicBp;

  Vitals({
    this.temperatureF = 98.6,
    this.respiratoryRate = 24,
    this.heartRate = 80,
    this.spo2 = 98,
    this.feverDays = 2,
    this.systolicBp,
    this.diastolicBp,
  });
}

class DangerSigns {
  bool unableToDrinkOrFeed;
  bool vomitsEverything;
  bool convulsions;
  bool lethargicOrUnconscious;
  bool chestIndrawing;
  bool stridorInCalmChild;
  bool severePallor;
  bool stiffNeck;
  bool mastoidSwelling;
  bool earPainOrDischarge;

  DangerSigns({
    this.unableToDrinkOrFeed = false,
    this.vomitsEverything = false,
    this.convulsions = false,
    this.lethargicOrUnconscious = false,
    this.chestIndrawing = false,
    this.stridorInCalmChild = false,
    this.severePallor = false,
    this.stiffNeck = false,
    this.mastoidSwelling = false,
    this.earPainOrDischarge = false,
  });

  bool get hasAnyDangerSign =>
      unableToDrinkOrFeed ||
      vomitsEverything ||
      convulsions ||
      lethargicOrUnconscious ||
      chestIndrawing ||
      stridorInCalmChild ||
      severePallor ||
      stiffNeck ||
      mastoidSwelling ||
      earPainOrDischarge;

  List<String> get activeDangerSignLabels {
    List<String> list = [];
    if (unableToDrinkOrFeed) list.add('Unable to drink/feed');
    if (vomitsEverything) list.add('Vomits everything');
    if (convulsions) list.add('Convulsions during illness');
    if (lethargicOrUnconscious) list.add('Lethargic or unconscious');
    if (chestIndrawing) list.add('Severe chest indrawing');
    if (stridorInCalmChild) list.add('Stridor in calm child');
    if (severePallor) list.add('Severe palmar pallor');
    if (stiffNeck) list.add('Stiff neck');
    if (mastoidSwelling) list.add('Mastoid swelling');
    if (earPainOrDischarge) list.add('Ear pain or discharge');
    return list;
  }
}

class ConditionResult {
  final String name;
  final String classification;
  final TriageSeverity severity;
  final List<String> reasonTrace;

  ConditionResult({
    required this.name,
    required this.classification,
    required this.severity,
    required this.reasonTrace,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'classification': classification,
        'flag': severity.name.toUpperCase(),
        'reasonTrace': reasonTrace,
      };
}

class TriageResult {
  final TriageSeverity severity;
  final String title;
  final String recommendation;
  final List<String> reasons;
  final String ttsScript;
  final String smsSnippet;
  final DateTime timestamp;
  final SyncStatus syncStatus;
  final List<ConditionResult> conditions;
  final List<String> ruleTrace;

  TriageResult({
    required this.severity,
    required this.title,
    required this.recommendation,
    required this.reasons,
    required this.ttsScript,
    required this.smsSnippet,
    required this.timestamp,
    this.syncStatus = SyncStatus.offlineQueued,
    this.conditions = const [],
    this.ruleTrace = const [],
  });

  String get rationale => reasons.isNotEmpty ? reasons.join('; ') : 'Vitals within normal limits';
  List<String> get actionSteps => [recommendation, ...reasons];
  String get doctorAudioScript => ttsScript;

  String get severityLabel {
    switch (severity) {
      case TriageSeverity.red:
        return 'RED - EMERGENCY REFERRAL';
      case TriageSeverity.yellow:
        return 'YELLOW - URGENT PHC VISIT';
      case TriageSeverity.green:
        return 'GREEN - ROUTINE HOME CARE';
    }
  }

  Map<String, dynamic> toMap() => {
        'severity': severity.name.toUpperCase(),
        'title': title,
        'recommendation': recommendation,
        'reasons': reasons,
        'ttsScript': ttsScript,
        'smsSnippet': smsSnippet,
        'timestamp': timestamp.toIso8601String(),
        'conditions': conditions.map((c) => c.toMap()).toList(),
        'ruleTrace': ruleTrace,
      };

  TriageResult copyWith({
    TriageSeverity? severity,
    String? title,
    String? recommendation,
    List<String>? reasons,
    String? ttsScript,
    String? smsSnippet,
    DateTime? timestamp,
    SyncStatus? syncStatus,
    List<ConditionResult>? conditions,
    List<String>? ruleTrace,
  }) {
    return TriageResult(
      severity: severity ?? this.severity,
      title: title ?? this.title,
      recommendation: recommendation ?? this.recommendation,
      reasons: reasons ?? this.reasons,
      ttsScript: ttsScript ?? this.ttsScript,
      smsSnippet: smsSnippet ?? this.smsSnippet,
      timestamp: timestamp ?? this.timestamp,
      syncStatus: syncStatus ?? this.syncStatus,
      conditions: conditions ?? this.conditions,
      ruleTrace: ruleTrace ?? this.ruleTrace,
    );
  }

  /// Evaluate WHO IMCI deterministic rules for pediatric/community triage
  /// Ported from the external TypeScript Triage_Engine (engine.ts)
  static TriageResult evaluate({
    required Patient patient,
    required Vitals vitals,
    required DangerSigns dangerSigns,
    int diarrhoeaDays = 0,
    bool hasDiarrhoeaSymptom = false,
    bool hasBloodInStoolSymptom = false,
  }) {
    // Build TriageInput-shaped structures
    Map<String, dynamic> symptoms = {};
    if (dangerSigns.unableToDrinkOrFeed) symptoms['not_able_to_drink_or_breastfeed'] = true;
    if (dangerSigns.vomitsEverything) symptoms['vomits_everything'] = true;
    if (dangerSigns.convulsions) symptoms['convulsions'] = true;
    if (dangerSigns.lethargicOrUnconscious) symptoms['lethargic_or_unconscious'] = true;
    if (dangerSigns.chestIndrawing) symptoms['chest_indrawing'] = true;
    if (dangerSigns.stridorInCalmChild) symptoms['stridor_calm_child'] = true;
    if (dangerSigns.stiffNeck) symptoms['stiff_neck'] = true;
    if (dangerSigns.mastoidSwelling) symptoms['mastoid_swelling'] = true;
    if (dangerSigns.earPainOrDischarge) symptoms['ear_pain_or_discharge'] = true;
    if (hasDiarrhoeaSymptom) symptoms['diarrhoea'] = true;
    if (hasBloodInStoolSymptom) symptoms['blood_in_stool'] = true;
    symptoms['diarrhoea_days'] = diarrhoeaDays;

    // Run classifiers
    List<ConditionResult> conditions = [];
    List<String> trace = [];

    // General danger signs
    List<String> dangerSignsList = [];
    if (dangerSigns.unableToDrinkOrFeed) dangerSignsList.add('not able to drink/breastfeed');
    if (dangerSigns.vomitsEverything) dangerSignsList.add('vomits everything');
    if (dangerSigns.convulsions) dangerSignsList.add('convulsions');
    if (dangerSigns.lethargicOrUnconscious) dangerSignsList.add('lethargic or unconscious');

    String flag;
    if (dangerSignsList.isNotEmpty) {
      flag = 'red';
    } else {
      flag = 'green';
    }

    trace.add(dangerSignsList.isNotEmpty ? 'general danger signs: ${dangerSignsList.join(", ")}' : 'general danger signs: none present');

    // Pneumonia
    bool hasCough = symptoms['cough_or_difficulty_breathing'] == true || symptoms['chest_indrawing'] == true;
    if (hasCough) {
      int rr = vitals.respiratoryRate;
      int ageM = patient.ageMonths;
      int rrCutoff = ageM < 2 ? 60 : (ageM < 12 ? 50 : 40);
      bool fastBreathing = rr >= rrCutoff;

      if (ageM < 2 && (fastBreathing || symptoms['chest_indrawing'] == true || symptoms['stridor_calm_child'] == true)) {
        conditions.add(ConditionResult(
          name: 'pneumonia',
          classification: 'POSSIBLE_SERIOUS_BACTERIAL_INFECTION',
          severity: TriageSeverity.red,
          reasonTrace: ['age ${ageM}mo (<2mo) with positive sign -> refer per young-infant scope decision'],
        ));
        flag = 'red';
      } else if (symptoms['chest_indrawing'] == true || symptoms['stridor_calm_child'] == true) {
        conditions.add(ConditionResult(
          name: 'pneumonia',
          classification: 'SEVERE_PNEUMONIA',
          severity: TriageSeverity.red,
          reasonTrace: ['chest_indrawing=${symptoms['chest_indrawing']}, stridor=${symptoms['stridor_calm_child']}'],
        ));
        if (flag != 'red') flag = 'red';
      } else if (fastBreathing) {
        conditions.add(ConditionResult(
          name: 'pneumonia',
          classification: 'PNEUMONIA',
          severity: TriageSeverity.yellow,
          reasonTrace: ['RR $rr >= cutoff $rrCutoff for age ${ageM}mo'],
        ));
        if (flag != 'red') flag = 'yellow';
      } else {
        conditions.add(ConditionResult(
          name: 'pneumonia',
          classification: 'NO_PNEUMONIA',
          severity: TriageSeverity.green,
          reasonTrace: ['below RR cutoff, no indrawing/stridor'],
        ));
      }
      trace.add('pneumonia: RR $rr, cutoff $rrCutoff -> ${conditions.last.classification} (${conditions.last.severity.name})');
    }

    // Ear problem
    if (symptoms['ear_pain_or_discharge'] == true || symptoms['mastoid_swelling'] == true) {
      if (symptoms['mastoid_swelling'] == true) {
        conditions.add(ConditionResult(
          name: 'ear problem',
          classification: 'MASTOIDITIS',
          severity: TriageSeverity.red,
          reasonTrace: ['mastoid swelling present'],
        ));
        if (flag != 'red') flag = 'red';
      } else {
        conditions.add(ConditionResult(
          name: 'ear problem',
          classification: 'ACUTE_EAR_INFECTION',
          severity: TriageSeverity.yellow,
          reasonTrace: ['ear pain or discharge present, no mastoid swelling'],
        ));
        if (flag != 'red') flag = 'yellow';
      }
      trace.add('ear problem: ${conditions.last.classification} (${conditions.last.severity.name})');
    }

    // Fever
    double tempC = (vitals.temperatureF - 32.0) * (5.0 / 9.0);
    int feverDays = vitals.feverDays;
    bool hasFever = tempC >= 37.5 || feverDays > 0;
    if (hasFever) {
      if (symptoms['stiff_neck'] == true) {
        conditions.add(ConditionResult(
          name: 'fever',
          classification: 'VERY_SEVERE_FEBRILE_DISEASE',
          severity: TriageSeverity.red,
          reasonTrace: ['stiff neck present'],
        ));
        if (flag != 'red') flag = 'red';
      } else if (feverDays >= 7) {
        conditions.add(ConditionResult(
          name: 'fever',
          classification: 'FEVER_PROLONGED',
          severity: TriageSeverity.yellow,
          reasonTrace: ['fever_days=$feverDays >= 7 -> refer for assessment'],
        ));
        if (flag != 'red') flag = 'yellow';
      } else {
        conditions.add(ConditionResult(
          name: 'fever',
          classification: 'FEVER_LOW_RISK',
          severity: TriageSeverity.green,
          reasonTrace: ['fever <7 days, no stiff neck, no general danger sign'],
        ));
      }
      trace.add('fever: temp ${tempC.toStringAsFixed(1)}C, $feverDays days -> ${conditions.last.classification} (${conditions.last.severity.name})');
    }

    // Diarrhoea
    bool hasDiarrhoea = symptoms['diarrhoea'] == true;
    if (hasDiarrhoea) {
      int severeCount = 0;
      if (symptoms['lethargic_or_unconscious'] == true) severeCount++;
      if (symptoms['sunken_eyes'] == true) severeCount++;
      if (symptoms['drinking'] == 'poor_or_unable') severeCount++;
      if (symptoms['skin_pinch'] == 'very_slow') severeCount++;

      int someCount = 0;
      if (symptoms['restless_irritable'] == true) someCount++;
      if (symptoms['sunken_eyes'] == true) someCount++;
      if (symptoms['drinking'] == 'eager_thirsty') someCount++;
      if (symptoms['skin_pinch'] == 'slow') someCount++;

      String classification;
      TriageSeverity severity;
      if (severeCount >= 2) {
        classification = 'SEVERE_DEHYDRATION';
        severity = TriageSeverity.red;
      } else if (someCount >= 2) {
        classification = 'SOME_DEHYDRATION';
        severity = TriageSeverity.yellow;
      } else {
        classification = 'NO_DEHYDRATION';
        severity = TriageSeverity.green;
      }

      if (symptoms['blood_in_stool'] == true) {
        classification += '+DYSENTERY';
        if (severity == TriageSeverity.green) severity = TriageSeverity.yellow;
      }
      int diaDays = symptoms['diarrhoea_days'] ?? 0;
      if (diaDays >= 14) {
        classification += '+PERSISTENT';
        if (severity == TriageSeverity.green) severity = TriageSeverity.yellow;
      }

      conditions.add(ConditionResult(
        name: 'diarrhoea',
        classification: classification,
        severity: severity,
        reasonTrace: ['$severeCount severe signs, $someCount some signs'],
      ));
      if (flagRank[severity.name.toLowerCase()]! > flagRank[flag]!) {
        flag = severity.name.toLowerCase();
      }
      trace.add('diarrhoea: $classification (${severity.name})');
    }

    // Young infant catch-all (<2 months)
    int ageM = patient.ageMonths;
    if (ageM < 2 && dangerSignsList.isEmpty) {
      bool hasAnyPositive = symptoms.values.any((v) {
        if (v is bool) return v == true;
        if (v is int) return v > 0;
        if (v is String) return v != 'immediate' && v != 'normal';
        return false;
      });
      if (hasAnyPositive) {
        dangerSignsList.add('young infant (<2mo) with positive symptom');
        trace.add('young infant (<2mo) with positive symptom -> RED');
        if (flag != 'red') flag = 'red';
      }
    }

    // Determine worst flag from all evaluated conditions (Worst Flag Wins)
    for (var c in conditions) {
      if (flagRank[c.severity.name.toLowerCase()]! > flagRank[flag]!) {
        flag = c.severity.name.toLowerCase();
      }
    }

    // Determine final severity
    TriageSeverity finalSeverity;
    if (flag == 'red') {
      finalSeverity = TriageSeverity.red;
    } else if (flag == 'yellow') {
      finalSeverity = TriageSeverity.yellow;
    } else {
      finalSeverity = TriageSeverity.green;
    }

    // Build title/recommendation from worst condition
    String title;
    String recommendation;
    if (finalSeverity == TriageSeverity.red) {
      title = 'URGENT MEDICAL REFERRAL REQUIRED';
      recommendation = 'Immediately transport patient to nearest CHC/District Hospital. Administer first dose of pre-referral treatment if trained.';
    } else if (finalSeverity == TriageSeverity.yellow) {
      title = 'PHC CONSULTATION ADVISED';
      recommendation = 'Refer to Primary Health Centre (PHC) within 24 hours. Advise caregiver on home care and watch for danger signs.';
    } else {
      title = 'ROUTINE HOME MANAGEMENT';
      recommendation = 'Continue home care, fluid intake, and nutritional support. Re-assess in 2 days or if symptoms worsen.';
    }

    // Build reasons
    List<String> reasons = [];
    for (var c in conditions) {
      reasons.addAll(c.reasonTrace);
    }
    if (reasons.isEmpty) {
      reasons.add('Vitals within normal limits for age');
    }

    // TTS script
    String ageStr = '${patient.ageMonths}-month-old';
    String ttsScript = '${finalSeverity.name.toUpperCase()} alert for patient ${patient.name}, age $ageStr. '
        'Diagnosis and classified findings: ${reasons.join('. ')}. '
        'Vitals: Temperature ${vitals.temperatureF.toStringAsFixed(1)} degrees Fahrenheit, Respiratory rate ${vitals.respiratoryRate} breaths per minute, Oxygen saturation ${vitals.spo2} percent. '
        'Recommended Action: $recommendation';

    // SMS snippet
    String smsSnippet = 'ALERT[${finalSeverity.name.toUpperCase()}]: Ptn ${patient.id} (${patient.name}, ${patient.ageDisplay}). '
        'Danger: ${reasons.join('. ')}. RR:${vitals.respiratoryRate}, SpO2:${vitals.spo2}%. Action: $recommendation';
    if (smsSnippet.length > 140) {
      smsSnippet = '${smsSnippet.substring(0, 137)}...';
    }

    return TriageResult(
      severity: finalSeverity,
      title: title,
      recommendation: recommendation,
      reasons: reasons,
      ttsScript: ttsScript,
      smsSnippet: smsSnippet,
      timestamp: DateTime.now(),
      conditions: conditions,
      ruleTrace: trace,
    );
  }
}

  Map<String, int> flagRank = {
  'green': 0,
  'yellow': 1,
  'red': 2,
};
