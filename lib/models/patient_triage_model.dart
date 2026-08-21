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
    if (unableToDrinkOrFeed) list.add('Unable to drink or feed');
    if (vomitsEverything) list.add('Vomiting Everything');
    if (convulsions) list.add('Convulsions');
    if (lethargicOrUnconscious) list.add('Lethargy/Unresponsiveness');
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

  String get rationale => reasons.isNotEmpty ? reasons.join('; ') : 'Vitals within normal limits for age';
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

  String get whatsappUrl {
    final encodedText = Uri.encodeComponent(
      '*EMERGENCY TELE-TRIAGE REFERRAL*\n\n'
      '*Severity:* $severityLabel\n'
      '*Diagnosis:* $title\n'
      '*Urgency:* $recommendation\n'
      '*Primary Findings:* $rationale\n'
      '*Action Plan:* ${actionSteps.join(", ")}'
    );
    return 'https://api.whatsapp.com/send?text=$encodedText';
  }

  /// Evaluate Person B's WHO IMCI Rule-Based Decision Model
  static TriageResult evaluate({
    required Patient patient,
    required Vitals vitals,
    required DangerSigns dangerSigns,
  }) {
    List<String> reasons = [];
    TriageSeverity severity = TriageSeverity.green;

    // 1. General Danger Signs (WHO IMCI Red Criteria - Person B Model)
    if (dangerSigns.hasAnyDangerSign) {
      severity = TriageSeverity.red;
      reasons.addAll(dangerSigns.activeDangerSignLabels);
    }

    // 2. Fast Breathing Assessment (Person B Age-Adjusted Thresholds)
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

    // 3. Oxygen Saturation check
    if (vitals.spo2 < 90) {
      severity = TriageSeverity.red;
      reasons.add('Severe Hypoxia (SpO2: ${vitals.spo2}%)');
    } else if (vitals.spo2 < 94) {
      reasons.add('Mild Hypoxia (SpO2: ${vitals.spo2}%)');
      if (severity != TriageSeverity.red) {
        severity = TriageSeverity.yellow;
      }
    }

    // 4. High Fever check
    if (vitals.temperatureF >= 102.5 || vitals.feverDays > 7) {
      reasons.add('High/Prolonged Fever (${vitals.temperatureF.toStringAsFixed(1)}°F, ${vitals.feverDays}d)');
      if (severity != TriageSeverity.red) {
        severity = TriageSeverity.yellow;
      }
    }

    // Person B Clinical Diagnosis & Action Decision Trees
    String title;
    String recommendation;

    if (severity == TriageSeverity.red) {
      title = 'SEVERE PNEUMONIA / VERY SEVERE DISEASE';
      recommendation =
          'URGENT HOSPITAL REFERRAL: Give first dose of appropriate oral antibiotic before transfer. Keep child warm during transport. Refer IMMEDIATELY to nearest hospital / First Referral Unit (FRU).';
    } else if (severity == TriageSeverity.yellow) {
      if (vitals.feverDays > 7) {
        title = 'FEVER - POSSIBLE MALARIA / TYPHOID';
        recommendation =
            'REFER TO PHC FOR BLOOD TEST: Perform RDT test for Malaria if available. Give Paracetamol for high fever (≥38.5°C). Refer to PHC for evaluation.';
      } else {
        title = 'PNEUMONIA (Fast Breathing)';
        recommendation =
            'REFER TO PHC WITHIN 24 HOURS: Give oral Amoxicillin for 5 days. Soothe throat and relieve cough with safe remedy. Advise mother when to return immediately if signs worsen.';
      }
    } else {
      title = 'NO PNEUMONIA / MILD ILLNESS';
      recommendation =
          'HOME CARE: Give extra fluid (ORS solution & Zinc supplement if diarrhea present). Continue feeding child. Soothe throat with home remedy. Advise mother when to return if signs worsen.';
      if (reasons.isEmpty) {
        reasons.add('Vitals within normal limits for age');
      }
    }

    String allFindings = reasons.isNotEmpty ? reasons.join('. ') : 'Vitals within normal limits for age';

    // 10-Second Doctor Audio Summary Script (Person B Canonical Format)
    String ttsScript =
        '${severity.name.toUpperCase()} Alert for patient ${patient.id} (${patient.name}, ${patient.ageDisplay}). '
        'Diagnosis: $title. Findings: $allFindings. '
        'Vitals: Temp ${vitals.temperatureF.toStringAsFixed(1)}F, RR ${vitals.respiratoryRate}, SpO2 ${vitals.spo2} percent. '
        'Action: $recommendation';

    // 140-character emergency SMS snippet (Person B Snippet Format)
    String smsSnippet =
        '[${severity.name.toUpperCase()}] ${patient.id} | Age:${patient.ageDisplay} | $allFindings | RR:${vitals.respiratoryRate} | Action:$recommendation';
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
