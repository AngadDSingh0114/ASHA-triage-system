import 'package:flutter/material.dart';
import '../l10n/app_translations.dart';
import '../models/patient_triage_model.dart';

class TriageResultScreen extends StatelessWidget {
  final TriageResult triageResult;
  final AppLanguage currentLanguage;
  final VoidCallback onGoToAudio;
  final VoidCallback onGoToDispatch;

  const TriageResultScreen({
    super.key,
    required this.triageResult,
    required this.currentLanguage,
    required this.onGoToAudio,
    required this.onGoToDispatch,
  });

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    IconData badgeIcon;

    switch (triageResult.severity) {
      case TriageSeverity.red:
        badgeColor = const Color(0xFFD32F2F);
        badgeIcon = Icons.warning_rounded;
        break;
      case TriageSeverity.yellow:
        badgeColor = const Color(0xFFF57C00);
        badgeIcon = Icons.error_outline;
        break;
      case TriageSeverity.green:
        badgeColor = const Color(0xFF388E3C);
        badgeIcon = Icons.check_circle_outline;
        break;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // High-Impact Severity Badge Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22.0),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: badgeColor.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(badgeIcon, size: 60, color: Colors.white),
                const SizedBox(height: 12),
                Text(
                  triageResult.severityLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  triageResult.title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Clinical Rationale Title
          Text(
            AppTranslations.getText('rationale_title', currentLanguage),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          // Reasons List
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: triageResult.reasons.map((reason) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.circle,
                          size: 10,
                          color: Color(0xFF0D47A1),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            reason,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Action Recommendation
          Text(
            AppTranslations.getText('recommendation_title', currentLanguage),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          Card(
            color: Colors.white,
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Text(
                triageResult.recommendation,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Forward Action Buttons (Large Rural Ergonomics)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onGoToAudio,
                  icon: const Icon(Icons.graphic_eq),
                  label: Text(
                    AppTranslations.getText('listen_tts_btn', currentLanguage),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onGoToDispatch,
                  icon: const Icon(Icons.send),
                  label: Text(
                    AppTranslations.getText('dispatch_alert_btn', currentLanguage),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: const Color(0xFF0D47A1),
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
