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
      physics: const BouncingScrollPhysics(),
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
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    AppTranslations.localizeDiagnosis(triageResult.severityLabel, currentLanguage),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppTranslations.localizeDiagnosis(triageResult.title, currentLanguage),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  softWrap: true,
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 5),
                          child: Icon(
                            Icons.circle,
                            size: 8,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            AppTranslations.localizeReason(reason, currentLanguage),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            softWrap: true,
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

          // Action Recommendation Title
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
                AppTranslations.localizeUrgency(triageResult.recommendation, currentLanguage),
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                softWrap: true,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Action Buttons with Smooth Zero-Lag Navigation
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onGoToAudio,
                  icon: const Icon(Icons.graphic_eq),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      AppTranslations.getText('listen_tts_btn', currentLanguage),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    side: const BorderSide(color: Color(0xFF0D47A1), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onGoToDispatch,
                  icon: const Icon(Icons.send),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      AppTranslations.getText('dispatch_alert_btn', currentLanguage),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
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
