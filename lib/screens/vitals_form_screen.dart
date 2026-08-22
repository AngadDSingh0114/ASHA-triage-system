import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../l10n/app_translations.dart';
import '../models/patient_triage_model.dart';
import '../services/asha_nlp_extractor.dart';

class VitalsFormScreen extends StatefulWidget {
  final Patient patient;
  final Vitals vitals;
  final DangerSigns dangerSigns;
  final AppLanguage currentLanguage;
  final VoidCallback onVitalsChanged;
  final VoidCallback onSubmit;

  const VitalsFormScreen({
    super.key,
    required this.patient,
    required this.vitals,
    required this.dangerSigns,
    required this.currentLanguage,
    required this.onVitalsChanged,
    required this.onSubmit,
  });

  @override
  State<VitalsFormScreen> createState() => _VitalsFormScreenState();
}

class _VitalsFormScreenState extends State<VitalsFormScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  String _transcriptionText =
      'Child is 14 months old. Has high fever 101.4°F for 2 days, severe chest indrawing, and fast breathing at 52 breaths per minute.';

  late AshaNlpResult _nlpResult;

  @override
  void initState() {
    super.initState();
    _nlpResult = AshaNlpExtractor.parseTranscript(_transcriptionText);
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) {
              setState(() {
                _isListening = false;
              });
            }
          } else if (status == 'listening') {
            if (mounted) {
              setState(() {
                _isListening = true;
              });
            }
          }
        },
        onError: (errorNotification) {
          if (mounted) {
            setState(() {
              _isListening = false;
            });
          }
        },
      );
      if (mounted) {
        setState(() {
          _speechEnabled = available;
        });
      }
    } catch (_) {
      _speechEnabled = false;
    }
  }

  void _listenLiveVoice() async {
    if (_speechEnabled && !_isListening) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔴 Listening... Speak patient symptoms now!'),
          duration: Duration(seconds: 3),
          backgroundColor: Colors.redAccent,
        ),
      );
      setState(() {
        _isListening = true;
      });
      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _processNlpTranscription(result.recognizedWords);
            });
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenFor: const Duration(seconds: 60),
          pauseFor: const Duration(seconds: 6),
          partialResults: true,
          cancelOnError: false,
          listenMode: stt.ListenMode.dictation,
          localeId: widget.currentLanguage == AppLanguage.hindi || widget.currentLanguage == AppLanguage.hinglish
              ? 'hi_IN'
              : widget.currentLanguage == AppLanguage.marathi
                  ? 'mr_IN'
                  : widget.currentLanguage == AppLanguage.urdu
                      ? 'ur_IN'
                      : widget.currentLanguage == AppLanguage.tamil
                          ? 'ta_IN'
                          : widget.currentLanguage == AppLanguage.telugu
                              ? 'te_IN'
                              : widget.currentLanguage == AppLanguage.bengali
                                  ? 'bn_IN'
                                  : widget.currentLanguage == AppLanguage.gujarati
                                      ? 'gu_IN'
                                      : widget.currentLanguage == AppLanguage.kannada
                                          ? 'kn_IN'
                                          : widget.currentLanguage == AppLanguage.malayalam
                                              ? 'ml_IN'
                                              : widget.currentLanguage == AppLanguage.punjabi
                                                  ? 'pa_IN'
                                                  : widget.currentLanguage == AppLanguage.odia
                                                      ? 'or_IN'
                                                      : 'en_IN',
        ),
      );
    } else if (_isListening) {
      await _speech.stop();
      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }
    } else {
      // Microphone unavailable on emulator or permission denied -> Auto fallback
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Microphone unavailable on Emulator. Simulating AI Voice Input...',
          ),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFF0D47A1),
        ),
      );
      _loadPresetScenario(1);
    }
  }

  void _processNlpTranscription(String text) {
    _transcriptionText = text;
    _nlpResult = AshaNlpExtractor.parseTranscript(text);

    final fields = _nlpResult.extractedFields;
    if (fields.ageMonths != null) {
      widget.patient.ageMonths = fields.ageMonths!;
    }
    if (fields.temperatureF != null) {
      widget.vitals.temperatureF = fields.temperatureF!;
    } else if (fields.symptoms.contains('fever')) {
      widget.vitals.temperatureF = 101.4;
    }
    if (fields.respiratoryRate != null) {
      widget.vitals.respiratoryRate = fields.respiratoryRate!;
    }

    widget.dangerSigns.chestIndrawing = fields.hasChestIndrawing;
    widget.dangerSigns.convulsions = fields.hasConvulsions;
    widget.dangerSigns.vomitsEverything = fields.hasVomitingEverything;
    widget.dangerSigns.lethargicOrUnconscious = fields.hasLethargy;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onVitalsChanged();
      }
    });
  }

  void _loadPresetScenario(int scenario) {
    setState(() {
      _isListening = true;
    });

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        _isListening = false;
        String text;
        if (scenario == 1) {
          // RED PNEUMONIA SCENARIO
          text = widget.currentLanguage == AppLanguage.hindi
              ? 'बच्चा 14 महीने का है। 2 दिन से तेज बुखार 101.4°F है, छाती अत्यधिक धंस रही है, और सांस की गति तेज 52 saans/min है।'
              : widget.currentLanguage == AppLanguage.marathi
                  ? 'बाळ 14 महिन्यांचे आहे. 2 दिवसांपासून ताप 101.4°F आहे, छाती आत जात आहे आणि श्वास 52 saans/min आहे.'
                  : 'Child is 14 months old. Has high fever 101.4°F for 2 days, severe chest indrawing, and fast breathing 52 breaths/min.';
        } else if (scenario == 2) {
          // YELLOW MODERATE FEVER SCENARIO
          text = widget.currentLanguage == AppLanguage.hindi
              ? 'बच्चा 14 महीने का है। हल्का बुखार 100.2°F है, 42 saans/min तेज सांस है, लेकिन छाती नहीं धंस रही।'
              : widget.currentLanguage == AppLanguage.marathi
                  ? 'बाळ 14 महिन्यांचे आहे. 100.2°F ताप आहे, 42 saans/min श्वास आहे, पण छाती ओढली जात नाही.'
                  : 'Child is 14 months old. Moderate fever 100.2°F, mild fast breathing 42 breaths/min, no chest indrawing.';
        } else {
          // GREEN LOW RISK SCENARIO
          text = widget.currentLanguage == AppLanguage.hindi
              ? 'बच्चा 14 महीने का है। सामान्य तापमान 98.6°F है, सांस की गति 24 saans/min सामान्य है, अच्छी तरह से दूध पी रहा है।'
              : widget.currentLanguage == AppLanguage.marathi
                  ? 'बाळ 14 महिन्यांचे आहे. सामान्य तापमान 98.6°F, श्वास 24 saans/min सामान्य आहे, व्यवस्थित दूध पित आहे.'
                  : 'Child is 14 months old. Normal temperature 98.6°F, normal breathing 24 breaths/min, active and feeding well.';
        }

        _processNlpTranscription(text);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final triageResult = TriageResult.evaluate(
      patient: widget.patient,
      vitals: widget.vitals,
      dangerSigns: widget.dangerSigns,
    );

    final confidencePct = (_nlpResult.extractionConfidence * 100).toInt();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Registered Patient Header Banner
          Card(
            color: const Color(0xFFE8EAF6),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  const Icon(Icons.badge, color: Color(0xFF0D47A1)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${widget.patient.name} (${widget.patient.ageDisplay}) • Onset: ${widget.patient.illnessOnset}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Main Voice Capture Title & On-Device Engine Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  AppTranslations.getText('voice_triage_title', widget.currentLanguage),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.shade700,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '100% OFF-LINE NLP',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            AppTranslations.getText('speak_prompt', widget.currentLanguage),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 18),

          // Animated AI Microphone Button
          Center(
            child: GestureDetector(
              onTap: _listenLiveVoice,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isListening ? Colors.redAccent : const Color(0xFF0D47A1),
                  boxShadow: [
                    BoxShadow(
                      color: (_isListening ? Colors.redAccent : const Color(0xFF0D47A1))
                          .withValues(alpha: 0.4),
                      blurRadius: _isListening ? 24 : 12,
                      spreadRadius: _isListening ? 6 : 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isListening ? Icons.graphic_eq : Icons.mic,
                      size: 44,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isListening ? 'LISTENING...' : 'TAP MIC',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          if (_isListening)
            Center(
              child: Text(
                AppTranslations.getText('listening_status', widget.currentLanguage),
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          const SizedBox(height: 18),

          // Demo Voice Scenario Buttons
          Text(
            AppTranslations.getText('preset_samples_title', widget.currentLanguage),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.warning, color: Colors.red, size: 16),
                label: Text(AppTranslations.getText('sample_red', widget.currentLanguage)),
                onPressed: () => _loadPresetScenario(1),
              ),
              ActionChip(
                avatar: const Icon(Icons.error_outline, color: Colors.amber, size: 16),
                label: Text(AppTranslations.getText('sample_yellow', widget.currentLanguage)),
                onPressed: () => _loadPresetScenario(2),
              ),
              ActionChip(
                avatar: const Icon(Icons.check_circle, color: Colors.green, size: 16),
                label: Text(AppTranslations.getText('sample_green', widget.currentLanguage)),
                onPressed: () => _loadPresetScenario(3),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Speech Transcription Box (Editable for Instant Emulator Voice Testing)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppTranslations.getText('transcription_box_title', widget.currentLanguage),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Editable / Voice Stream',
                style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),

          Card(
            color: Colors.white,
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.record_voice_over, color: Color(0xFF0D47A1)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          initialValue: _transcriptionText,
                          key: ValueKey(_transcriptionText),
                          maxLines: 3,
                          style: const TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: 13,
                            height: 1.4,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Type or speak symptoms naturally...',
                          ),
                          onChanged: (val) {
                            if (val.trim().isNotEmpty) {
                              _processNlpTranscription(val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // High-Impact Live AI Model Output Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14.0),
            decoration: BoxDecoration(
              color: const Color(0xFF0D47A1).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF0D47A1), width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.psychology, color: Color(0xFF0D47A1), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '⚡ LIVE AI MODEL EXTRACTION RESULT:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D47A1),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _nlpResult.extractedFields.symptoms.isEmpty
                            ? 'No acute symptoms detected.'
                            : 'Detected: ${_nlpResult.extractedFields.symptoms.join(', ').toUpperCase()} '
                                '(${_nlpResult.extractedFields.respiratoryRate ?? "N/A"} bpm, '
                                '${_nlpResult.extractedFields.temperatureF ?? "N/A"}°F)',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Native AshaNlpExtractor Entity Results & Confidence Meter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  AppTranslations.getText('nlp_entities_title', widget.currentLanguage),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: confidencePct >= 80 ? Colors.green.shade100 : Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'NLP Confidence: $confidencePct%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: confidencePct >= 80 ? Colors.green.shade900 : Colors.amber.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                children: [
                  _buildEntityRow(
                    'Extracted Age',
                    _nlpResult.extractedFields.ageMonths != null
                        ? '${_nlpResult.extractedFields.ageMonths} months'
                        : 'Not detected',
                    Colors.blue.shade900,
                  ),
                  const Divider(height: 14),
                  _buildEntityRow(
                    'Extracted Respiratory Rate',
                    _nlpResult.extractedFields.respiratoryRate != null
                        ? '${_nlpResult.extractedFields.respiratoryRate} bpm'
                        : 'Not detected',
                    (_nlpResult.extractedFields.respiratoryRate ?? 0) >= 40 ? Colors.red : Colors.green,
                  ),
                  const Divider(height: 14),
                  _buildEntityRow(
                    'Extracted Temperature',
                    _nlpResult.extractedFields.temperatureF != null
                        ? '${_nlpResult.extractedFields.temperatureF!.toStringAsFixed(1)} °F'
                        : (_nlpResult.extractedFields.symptoms.contains('fever') ? 'Fever detected' : 'Normal'),
                    _nlpResult.extractedFields.symptoms.contains('fever') ? Colors.red : Colors.green,
                  ),
                  const Divider(height: 14),
                  _buildEntityRow(
                    'Severe Chest Indrawing',
                    _nlpResult.extractedFields.hasChestIndrawing ? 'DETECTED (YES)' : 'NONE (NO)',
                    _nlpResult.extractedFields.hasChestIndrawing ? Colors.red : Colors.green,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Severity Classification Result Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: triageResult.severity == TriageSeverity.red
                  ? Colors.red.shade50
                  : triageResult.severity == TriageSeverity.yellow
                      ? Colors.amber.shade50
                      : Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: triageResult.severity == TriageSeverity.red
                    ? Colors.red
                    : triageResult.severity == TriageSeverity.yellow
                        ? Colors.amber.shade800
                        : Colors.green,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  triageResult.severity == TriageSeverity.red
                      ? Icons.warning
                      : triageResult.severity == TriageSeverity.yellow
                          ? Icons.error
                          : Icons.check_circle,
                  color: triageResult.severity == TriageSeverity.red
                      ? Colors.red
                      : triageResult.severity == TriageSeverity.yellow
                          ? Colors.amber.shade800
                          : Colors.green,
                  size: 32,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Predicted Severity: ${triageResult.severityLabel}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: triageResult.severity == TriageSeverity.red
                              ? Colors.red.shade900
                              : triageResult.severity == TriageSeverity.yellow
                                  ? Colors.amber.shade900
                                  : Colors.green.shade900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        triageResult.recommendation,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Submit & Evaluate Button
          ElevatedButton.icon(
            onPressed: widget.onSubmit,
            icon: const Icon(Icons.assessment, size: 24),
            label: Text(
              AppTranslations.getText('calc_btn', widget.currentLanguage),
            ),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              backgroundColor: const Color(0xFF0D47A1),
              foregroundColor: Colors.white,
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntityRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}
