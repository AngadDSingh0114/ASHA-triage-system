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
  String illnessOnset; // e.g. "Started 2 days ago", "Today", "1 week ago"

  Patient({
    required this.id,
    required this.name,
    this.birthdate,
    required this.ageMonths,
    required this.gender,
    required this.village,
    required this.guardianName,
    this.illnessOnset = 'Started 2 days ago',
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
  int respiratoryRate; // breaths per minute
  int heartRate; // bpm
  int spo2; // percentage
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

  DangerSigns({
    this.unableToDrinkOrFeed = false,
    this.vomitsEverything = false,
    this.convulsions = false,
    this.lethargicOrUnconscious = false,
    this.chestIndrawing = false,
    this.stridorInCalmChild = false,
    this.severePallor = false,
  });

  bool get hasAnyDangerSign =>
      unableToDrinkOrFeed ||
      vomitsEverything ||
      convulsions ||
      lethargicOrUnconscious ||
      chestIndrawing ||
      stridorInCalmChild ||
      severePallor;

  List<String> get activeDangerSignLabels {
    List<String> list = [];
    if (unableToDrinkOrFeed) list.add('Unable to drink/feed');
    if (vomitsEverything) list.add('Vomits everything');
    if (convulsions) list.add('Convulsions during illness');
    if (lethargicOrUnconscious) list.add('Lethargic or unconscious');
    if (chestIndrawing) list.add('Severe chest indrawing');
    if (stridorInCalmChild) list.add('Stridor in calm child');
    if (severePallor) list.add('Severe palmar pallor');
    return list;
  }
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

  TriageResult({
    required this.severity,
    required this.title,
    required this.recommendation,
    required this.reasons,
    required this.ttsScript,
    required this.smsSnippet,
    required this.timestamp,
    this.syncStatus = SyncStatus.offlineQueued,
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

  /// Evaluate WHO IMCI deterministic rules for pediatric/community triage
  static TriageResult evaluate({
    required Patient patient,
    required Vitals vitals,
    required DangerSigns dangerSigns,
  }) {
    List<String> reasons = [];
    TriageSeverity severity = TriageSeverity.green;

    // Check General Danger Signs (WHO IMCI Red Criteria)
    if (dangerSigns.hasAnyDangerSign) {
      severity = TriageSeverity.red;
      reasons.addAll(dangerSigns.activeDangerSignLabels);
    }

    // Check Respiratory Rate (Fast breathing cutoffs based on WHO IMCI age bands)
    bool isFastBreathing = false;
    if (patient.ageMonths < 2) {
      if (vitals.respiratoryRate >= 60) isFastBreathing = true;
    } else if (patient.ageMonths < 12) {
      if (vitals.respiratoryRate >= 50) isFastBreathing = true;
    } else if (patient.ageMonths <= 60) {
      if (vitals.respiratoryRate >= 40) isFastBreathing = true;
    } else {
      if (vitals.respiratoryRate >= 30) isFastBreathing = true;
    }

    if (isFastBreathing) {
      reasons.add('Fast Breathing (RR: ${vitals.respiratoryRate} bpm)');
      if (severity != TriageSeverity.red) {
        severity = TriageSeverity.yellow;
      }
    }

    // Oxygen Saturation check
    if (vitals.spo2 < 90) {
      severity = TriageSeverity.red;
      reasons.add('Severe Hypoxia (SpO2: ${vitals.spo2}%)');
    } else if (vitals.spo2 < 94) {
      reasons.add('Mild Hypoxia (SpO2: ${vitals.spo2}%)');
      if (severity != TriageSeverity.red) {
        severity = TriageSeverity.yellow;
      }
    }

    // High Fever check
    if (vitals.temperatureF >= 102.5) {
      reasons.add('High Fever (${vitals.temperatureF.toStringAsFixed(1)}°F)');
      if (severity != TriageSeverity.red) {
        severity = TriageSeverity.yellow;
      }
    }

    // Categorization text & TTS/SMS formats
    String title;
    String recommendation;

    if (severity == TriageSeverity.red) {
      title = 'URGENT MEDICAL REFERRAL REQUIRED';
      recommendation =
          'Immediately transport patient to nearest CHC/District Hospital. Administer first dose of pre-referral treatment if trained.';
    } else if (severity == TriageSeverity.yellow) {
      title = 'PHC CONSULTATION ADVISED';
      recommendation =
          'Refer to Primary Health Centre (PHC) within 24 hours. Advise caregiver on home care and watch for danger signs.';
    } else {
      title = 'ROUTINE HOME MANAGEMENT';
      recommendation =
          'Continue home care, fluid intake, and nutritional support. Re-assess in 2 days or if symptoms worsen.';
      if (reasons.isEmpty) {
        reasons.add('Vitals within normal limits for age');
      }
    }

    String allFindings = reasons.isNotEmpty ? reasons.join('. ') : 'Vitals within normal limits for age';

    // 10-Second Doctor Audio Summary Script (TTS format - Full Classified Symptoms)
    String ttsScript =
        '${severity.name.toUpperCase()} alert for patient ${patient.name}, age ${patient.ageDisplay}. '
        'Diagnosis and classified findings: $allFindings. '
        'Vitals: Temperature ${vitals.temperatureF.toStringAsFixed(1)} degrees Fahrenheit, Respiratory rate ${vitals.respiratoryRate} breaths per minute, Oxygen saturation ${vitals.spo2} percent. '
        'Recommended Action: $recommendation';

    // 140-character emergency SMS snippet
    String smsSnippet =
        'ALERT[${severity.name.toUpperCase()}]: Ptn ${patient.id} (${patient.name}, ${patient.ageDisplay}). '
        'Danger: $allFindings. RR:${vitals.respiratoryRate}, SpO2:${vitals.spo2}%. Action: $recommendation';
    if (smsSnippet.length > 140) {
      smsSnippet = '${smsSnippet.substring(0, 137)}...';
    }

    return TriageResult(
      severity: severity,
      title: title,
      recommendation: recommendation,
      reasons: reasons,
      ttsScript: ttsScript,
      smsSnippet: smsSnippet,
      timestamp: DateTime.now(),
    );
  }
}
