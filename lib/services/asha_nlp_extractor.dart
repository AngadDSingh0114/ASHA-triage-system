import 'dart:math';
import '../models/patient_triage_model.dart';

class ExtractedFields {
  final int? ageMonths;
  final int? respiratoryRate;
  final double? temperatureF;
  final int feverDays;
  final List<String> symptoms;
  final bool hasChestIndrawing;
  final bool hasConvulsions;
  final bool hasVomiting;
  final bool hasVomitingEverything;
  final bool hasLethargy;

  ExtractedFields({
    this.ageMonths,
    this.respiratoryRate,
    this.temperatureF,
    this.feverDays = 0,
    required this.symptoms,
    this.hasChestIndrawing = false,
    this.hasConvulsions = false,
    this.hasVomiting = false,
    this.hasVomitingEverything = false,
    this.hasLethargy = false,
  });
}

class AshaNlpResult {
  final String rawTranscript;
  final ExtractedFields extractedFields;
  final double extractionConfidence;

  AshaNlpResult({
    required this.rawTranscript,
    required this.extractedFields,
    required this.extractionConfidence,
  });
}

class AshaNlpExtractor {
  /// Comprehensive 13-Language Multilingual Thesaurus (Auto-synced with SYMPTOM_KEYWORDS.md)
  static const Map<String, List<String>> thesaurus = {
    'fever': [
      'bukhar', 'bukar', 'taap', 'fever', 'garam body', 'garam hai', 'high temperature',
      'jwaram', 'kaaychal', 'veppam', 'jwar', 'jora', 'jor', 'jwor', 'jwara',
      'bisilu', 'pani', 'panni', 'juar', 'taav', 'tav', 'उष्णता', 'ताप', 'बुखार',
    ],
    'chest_indrawing': [
      'chhati dhasna', 'chhati dhabna', 'chest drawing', 'chest indrawing', 'chest retraction',
      'retractions', 'chhati phoolna', 'saans lene me dikkat', 'saans lene mein dikkat', 'stridor', 'wheeze',
      'edai ullizhuthal', 'marbu ullizhuthal', 'chaati lopala', 'chaati padipovadam', 'buk dhonba', 'buk doba',
      'chhati bugne', 'chhati dhasne', 'ede olagade', 'nench ullilekk', 'nenchu ullilekku', 'chaati dobavu',
      'chhati dabna', 'chhati dhasiba', 'छाती धंसना', 'छाती आत जाणे', 'श्वास घेण्यास त्रास',
    ],
    'diarrhea': [
      'dast', 'loose motion', 'pakhana', 'diarrhea', 'watery stool', 'loose stools',
      'kozhuppokku', 'vayitruppokku', 'virechanalu', 'atisar', 'atisara', 'bhedi',
      'athisaaram', 'vayarupokku', 'jhada', 'dhava', 'जुलाब', 'दस्त',
    ],
    'vomiting': [
      'ulti', 'vomit', 'vomiting', 'puking', 'throwing up', 'qaee', 'vaanthi',
      'vaanti', 'vanti', 'venti', 'boma', 'bombi', 'chardhi', 'ol', 'baanta', 'उलटी',
    ],
    'vomiting_everything': [
      'ulti ho rahi hai sab', 'sab ulti', 'kha nahi raha', 'kuch nahi kha raha',
      'vomiting everything', 'cannot keep anything down', 'everything comes back up',
      'throwing up everything', 'har cheez ulti', 'ellam vaanthi', 'anthai vaanti',
      'sab bombi', 'badhu ol', 'kujh nahi kha sakda', 'kichhi khaiparheni', 'सर्व उलटी', 'सब उल्टी',
    ],
    'convulsions': [
      'jhatke', 'seizure', 'mirgi', 'fit', 'fits', 'spasms', 'aenthang', 'dore',
      'valippu', 'spasam', 'khichuni', 'akadi', 'daura', 'khenchan', 'baat', 'झटके', 'ताण', 'दौरे',
    ],
    'lethargy': [
      'behoosh', 'behosh', 'sota rehta hai', 'unresponsive', 'lethargic', 'lethargy',
      'not waking', 'unconscious', 'weak and dull', 'hosh nahi', 'susti', 'mayakkam',
      'chetana levu', 'behosh', 'jagena', 'bedhuda', 'bodharahithyam', 'jaagta nathi', 'সুস্ত', 'बेहोश', 'असुध',
    ],
  };

  /// Multilingual Spoken Word to Number Parser
  static int? _parseWordToNumber(String word) {
    final clean = word.trim().toLowerCase();
    final numMap = {
      'ek': 1, 'okati': 1, 'ondu': 1, 'onnu': 1, 'one': 1,
      'do': 2, 'randu': 2, 'rendu': 2, 'yeradu': 2, 'two': 2,
      'teen': 3, 'tin': 3, 'moodu': 3, 'moondru': 3, 'moonnu': 3, 'mooru': 3, 'three': 3,
      'char': 4, 'naalku': 4, 'naalu': 4, 'naalugu': 4, 'four': 4,
      'panch': 5, 'paanch': 5, 'aidu': 5, 'anchu': 5, 'anju': 5, 'five': 5,
      'cheh': 6, 'aaru': 6, 'six': 6,
      'saat': 7, 'eduru': 7, 'elu': 7, 'ezhu': 7, 'seven': 7,
      'aath': 8, 'aathh': 8, 'entu': 8, 'ettu': 8, 'eight': 8,
      'nau': 9, 'ombattu': 9, 'onbadhu': 9, 'tommidi': 9, 'nine': 9,
      'das': 10, 'hattu': 10, 'padi': 10, 'pathu': 10, 'ten': 10,
      'pandrah': 15, 'fifteen': 15,
      'bees': 20, 'beez': 20, 'twenty': 20,
      'chalis': 40, 'forty': 40,
      'pachaas': 50, 'fifty': 50,
      'saath': 60, 'sixty': 60,
    };
    return numMap[clean];
  }

  /// Parses raw ASHA audio transcripts into structured IMCI clinical entities
  static AshaNlpResult parseTranscript(String transcript) {
    if (transcript.isEmpty) {
      return AshaNlpResult(
        rawTranscript: '',
        extractedFields: ExtractedFields(symptoms: []),
        extractionConfidence: 0.0,
      );
    }

    final textLower = transcript.toLowerCase();

    // 1. AGE EXTRACTION
    int? ageMonths;
    final monthReg = RegExp(
      r'(\d+|\b(?:ek|do|teen|char|panch|cheh|saat|aath|nau|das|pandrah|bees)\b)\s*(-|\s)?\s*(mahine|mahina|month|months|m|महिने|महिना|maadam|maas|masam|tingal)\b',
      caseSensitive: false,
    );
    final monthMatch = monthReg.firstMatch(textLower);

    if (monthMatch != null) {
      final valStr = monthMatch.group(1) ?? '';
      ageMonths = int.tryParse(valStr) ?? _parseWordToNumber(valStr);
    } else {
      final yearReg = RegExp(
        r'(\d+(?:\.\d+)?|\b(?:ek|do|teen|char|panch)\b)\s*(-|\s)?\s*(saal|year|years|yr|yrs|साल|वर्ष|varsh|varsha)\b',
        caseSensitive: false,
      );
      final yearMatch = yearReg.firstMatch(textLower);
      if (yearMatch != null) {
        final valStr = yearMatch.group(1) ?? '';
        final yrs = double.tryParse(valStr) ?? (_parseWordToNumber(valStr)?.toDouble());
        if (yrs != null) {
          ageMonths = (yrs * 12).round();
        }
      }
    }

    // 2. RESPIRATORY RATE EXTRACTION
    int? respiratoryRate;
    final rrPatterns = [
      RegExp(r'(\d+|\b(?:chalis|pachaas|saath)\b)\s*(?:saans\s*rate|saans/min|saans\s*per\s*min|breaths\s*per\s*minute|breaths/min|\/min|श्वास/मि)'),
      RegExp(r'(?:rr|respiratory\s*rate|rate|saans|श्वास)\s*(?:of|is|:)?\s*(\d+)'),
      RegExp(r'(\d+)\s*(?:saans|breaths|श्वास)\b'),
    ];

    for (final pat in rrPatterns) {
      final match = pat.firstMatch(textLower);
      if (match != null) {
        final valStr = match.group(1) ?? match.group(2);
        if (valStr != null) {
          respiratoryRate = int.tryParse(valStr) ?? _parseWordToNumber(valStr);
          if (respiratoryRate != null) break;
        }
      }
    }

    // 3. TEMPERATURE EXTRACTION
    double? temperatureF;
    final tempReg = RegExp(r'(\d{2,3}(?:\.\d)?)\s*(?:°f|f|fahrenheit|degree|डिग्री)?');
    final tempMatch = tempReg.firstMatch(textLower);
    if (tempMatch != null) {
      final tVal = double.tryParse(tempMatch.group(1) ?? '');
      if (tVal != null && tVal >= 95.0 && tVal <= 108.0) {
        temperatureF = tVal;
      }
    }

    // 4. SYMPTOM MATCHING VIA THESAURUS
    final List<String> detectedSymptoms = [];

    thesaurus.forEach((symptomKey, terms) {
      for (final term in terms) {
        if (textLower.contains(term.toLowerCase())) {
          detectedSymptoms.add(symptomKey);
          break;
        }
      }
    });

    final bool hasFever = detectedSymptoms.contains('fever');
    final bool hasChestIndrawing = detectedSymptoms.contains('chest_indrawing');
    final bool hasConvulsions = detectedSymptoms.contains('convulsions');
    final bool hasVomiting =
        detectedSymptoms.contains('vomiting') || detectedSymptoms.contains('vomiting_everything');
    final bool hasVomitingEverything = detectedSymptoms.contains('vomiting_everything');
    final bool hasLethargy = detectedSymptoms.contains('lethargy');

    // 5. FEVER DURATION EXTRACTION
    int feverDays = 0;
    if (hasFever || textLower.contains('din') || textLower.contains('day') || textLower.contains('दिवस') || textLower.contains('roju') || textLower.contains('naal')) {
      final feverDayReg1 = RegExp(r'(\d+|\b(?:ek|do|teen|char|panch|cheh|saat)\b)\s*(?:din|day|days|दिवस|roju|naal)\s*(?:se)?(?:\s*(?:bukhar|fever|ताप))?');
      final feverDayReg2 = RegExp(r'(?:bukhar|fever|ताप)\s*(?:for|se)?\s*(\d+|\b(?:ek|do|teen|char|panch)\b)\s*(?:din|day|days|दिवस|roju|naal)');

      var fMatch = feverDayReg1.firstMatch(textLower);
      fMatch ??= feverDayReg2.firstMatch(textLower);

      if (fMatch != null) {
        final valStr = fMatch.group(1) ?? '';
        feverDays = int.tryParse(valStr) ?? _parseWordToNumber(valStr) ?? 0;
      }
    }

    // 6. CONFIDENCE SCORE CALCULATION
    int filledSlots = 0;
    if (ageMonths != null) filledSlots += 1;
    if (respiratoryRate != null) filledSlots += 1;
    if (feverDays > 0) filledSlots += 1;
    if (detectedSymptoms.isNotEmpty) {
      filledSlots += 2;
    } else {
      filledSlots += 1;
    }

    final double confidence = double.parse((min(1.0, filledSlots / 5.0)).toStringAsFixed(2));

    return AshaNlpResult(
      rawTranscript: transcript,
      extractedFields: ExtractedFields(
        ageMonths: ageMonths,
        respiratoryRate: respiratoryRate,
        temperatureF: temperatureF,
        feverDays: feverDays,
        symptoms: detectedSymptoms,
        hasChestIndrawing: hasChestIndrawing,
        hasConvulsions: hasConvulsions,
        hasVomiting: hasVomiting,
        hasVomitingEverything: hasVomitingEverything,
        hasLethargy: hasLethargy,
      ),
      extractionConfidence: confidence,
    );
  }

  /// Parses transcript via NLP and automatically evaluates WHO IMCI clinical triage rules
  static TriageResult parseAndEvaluate(String transcript, Patient patient) {
    final nlpResult = parseTranscript(transcript);
    final ef = nlpResult.extractedFields;

    final vitals = Vitals(
      temperatureF: ef.temperatureF ?? (ef.feverDays > 0 ? 101.8 : 98.6),
      respiratoryRate: ef.respiratoryRate ?? 24,
      feverDays: ef.feverDays,
    );

    final dangerSigns = DangerSigns(
      unableToDrinkOrFeed: ef.symptoms.contains('unable_to_drink'),
      vomitsEverything: ef.hasVomitingEverything,
      convulsions: ef.hasConvulsions,
      lethargicOrUnconscious: ef.hasLethargy,
      chestIndrawing: ef.hasChestIndrawing,
    );

    return TriageResult.evaluate(
      patient: patient,
      vitals: vitals,
      dangerSigns: dangerSigns,
    );
  }
}
