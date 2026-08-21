import 'package:flutter/material.dart';
import '../l10n/app_translations.dart';
import '../models/patient_triage_model.dart';

class AudioPlayerScreen extends StatefulWidget {
  final TriageResult triageResult;
  final AppLanguage currentLanguage;
  final VoidCallback onGoToDispatch;

  const AudioPlayerScreen({
    super.key,
    required this.triageResult,
    required this.currentLanguage,
    required this.onGoToDispatch,
  });

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  bool _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppTranslations.getText('audio_screen_title', widget.currentLanguage),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            AppTranslations.getText('audio_screen_subtitle', widget.currentLanguage),
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 20),

          // Audio Player Card
          Card(
            elevation: 4,
            color: const Color(0xFF0D47A1),
            child: Padding(
              padding: const EdgeInsets.all(22.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.audiotrack, color: Colors.white, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          AppTranslations.getText('audio_card_title', widget.currentLanguage),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Waveform Visualizer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(18, (index) {
                      double height =
                          _isPlaying ? (index % 4 + 1) * 10.0 : 8.0;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: 4,
                        height: height,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),

                  // Play / Pause Button
                  IconButton.filled(
                    iconSize: 52,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0D47A1),
                    ),
                    icon: Icon(
                      _isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_fill,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPlaying = !_isPlaying;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isPlaying
                        ? AppTranslations.getText('playing_audio', widget.currentLanguage)
                        : AppTranslations.getText('tap_play', widget.currentLanguage),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          Text(
            AppTranslations.getText('script_title', widget.currentLanguage),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                '"${widget.triageResult.ttsScript}"',
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          ElevatedButton.icon(
            onPressed: widget.onGoToDispatch,
            icon: const Icon(Icons.send),
            label: Text(
              AppTranslations.getText('tab_dispatch', widget.currentLanguage),
            ),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
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
}
