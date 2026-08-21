import 'package:flutter/material.dart';
import '../l10n/app_translations.dart';

class LanguageSelectorDialog extends StatelessWidget {
  final AppLanguage currentLanguage;
  final ValueChanged<AppLanguage> onLanguageSelected;

  const LanguageSelectorDialog({
    super.key,
    required this.currentLanguage,
    required this.onLanguageSelected,
  });

  @override
  Widget build(BuildContext context) {
    final languages = [
      {'lang': AppLanguage.english, 'title': 'English', 'subtitle': 'English (Default)', 'badge': 'EN'},
      {'lang': AppLanguage.hindi, 'title': 'हिंदी', 'subtitle': 'Hindi', 'badge': 'HI'},
      {'lang': AppLanguage.hinglish, 'title': 'Hinglish', 'subtitle': 'Hindi + English', 'badge': 'HN'},
      {'lang': AppLanguage.marathi, 'title': 'मराठी', 'subtitle': 'Marathi', 'badge': 'MR'},
      {'lang': AppLanguage.urdu, 'title': 'اردو', 'subtitle': 'Urdu', 'badge': 'UR'},
      {'lang': AppLanguage.tamil, 'title': 'தமிழ்', 'subtitle': 'Tamil', 'badge': 'TA'},
      {'lang': AppLanguage.telugu, 'title': 'తెలుగు', 'subtitle': 'Telugu', 'badge': 'TE'},
      {'lang': AppLanguage.bengali, 'title': 'বাংলা', 'subtitle': 'Bengali', 'badge': 'BN'},
      {'lang': AppLanguage.gujarati, 'title': 'ગુજરાતી', 'subtitle': 'Gujarati', 'badge': 'GU'},
      {'lang': AppLanguage.kannada, 'title': 'ಕನ್ನಡ', 'subtitle': 'Kannada', 'badge': 'KN'},
      {'lang': AppLanguage.malayalam, 'title': 'മലയാളം', 'subtitle': 'Malayalam', 'badge': 'ML'},
      {'lang': AppLanguage.punjabi, 'title': 'ਪੰਜਾਬੀ', 'subtitle': 'Punjabi', 'badge': 'PA'},
      {'lang': AppLanguage.odia, 'title': 'ଓଡ଼ିଆ', 'subtitle': 'Odia', 'badge': 'OR'},
    ];

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.translate, color: Color(0xFF0D47A1)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppTranslations.getText('change_language', currentLanguage),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 420,
        child: ListView.separated(
          itemCount: languages.length,
          separatorBuilder: (context, index) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            final item = languages[index];
            final lang = item['lang'] as AppLanguage;
            final title = item['title'] as String;
            final subtitle = item['subtitle'] as String;
            final badge = item['badge'] as String;

            return _buildLanguageItem(
              context,
              lang: lang,
              title: title,
              subtitle: subtitle,
              badge: badge,
            );
          },
        ),
      ),
    );
  }

  Widget _buildLanguageItem(
    BuildContext context, {
    required AppLanguage lang,
    required String title,
    required String subtitle,
    required String badge,
  }) {
    final bool isSelected = currentLanguage == lang;

    return InkWell(
      onTap: () {
        onLanguageSelected(lang);
        Navigator.of(context).pop();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0D47A1).withValues(alpha: 0.1)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF0D47A1) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: isSelected
                  ? const Color(0xFF0D47A1)
                  : Colors.grey.shade400,
              child: Text(
                badge,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isSelected
                          ? const Color(0xFF0D47A1)
                          : Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF0D47A1),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
