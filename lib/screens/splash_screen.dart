import 'package:flutter/material.dart';
import '../l10n/app_translations.dart';
import '../widgets/language_selector_dialog.dart';

class SplashScreen extends StatelessWidget {
  final LanguageController languageController;
  final AppLanguage currentLanguage;
  final VoidCallback onStartScreening;

  const SplashScreen({
    super.key,
    required this.languageController,
    required this.currentLanguage,
    required this.onStartScreening,
  });

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return LanguageSelectorDialog(
          currentLanguage: currentLanguage,
          onLanguageSelected: (newLang) {
            languageController.setLanguage(newLang);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String langBadge;
    switch (currentLanguage) {
      case AppLanguage.english:
        langBadge = 'EN';
        break;
      case AppLanguage.hindi:
        langBadge = 'HI';
        break;
      case AppLanguage.hinglish:
        langBadge = 'HN';
        break;
      case AppLanguage.marathi:
        langBadge = 'MR';
        break;
      case AppLanguage.urdu:
        langBadge = 'UR';
        break;
      case AppLanguage.tamil:
        langBadge = 'TA';
        break;
      case AppLanguage.telugu:
        langBadge = 'TE';
        break;
      case AppLanguage.bengali:
        langBadge = 'BN';
        break;
      case AppLanguage.gujarati:
        langBadge = 'GU';
        break;
      case AppLanguage.kannada:
        langBadge = 'KN';
        break;
      case AppLanguage.malayalam:
        langBadge = 'ML';
        break;
      case AppLanguage.punjabi:
        langBadge = 'PA';
        break;
      case AppLanguage.odia:
        langBadge = 'OR';
        break;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D47A1), // Healthcare Deep Blue
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Top Bar with Language Selector & Offline Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Offline Ready Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade800,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.wifi_off, size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          '100% OFFLINE CAPABLE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Language Switcher
                  TextButton.icon(
                    onPressed: () => _showLanguageDialog(context),
                    icon: const Icon(Icons.language, color: Colors.white, size: 20),
                    label: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        langBadge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),

              // App Icon / Logo Emblem
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.health_and_safety,
                  size: 64,
                  color: Color(0xFF0D47A1),
                ),
              ),
              const SizedBox(height: 28),

              // Title & Subtitle
              Text(
                AppTranslations.getText('splash_title', currentLanguage),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                AppTranslations.getText('splash_tagline', currentLanguage),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),

              // Feature Highlights Card
              Card(
                color: Colors.white.withValues(alpha: 0.12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildFeatureItem(Icons.mic, 'Voice STT AI'),
                      _buildFeatureItem(Icons.verified, 'WHO IMCI'),
                      _buildFeatureItem(Icons.record_voice_over, '10s Audio'),
                      _buildFeatureItem(Icons.send, 'WhatsApp Alert'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Start Screening Button
              ElevatedButton.icon(
                onPressed: onStartScreening,
                icon: const Icon(Icons.arrow_forward, size: 24),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Text(
                    AppTranslations.getText('start_triage_btn', currentLanguage),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0D47A1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 22),
        const SizedBox(height: 4),
        Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
