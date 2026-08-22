import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
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
  final FlutterTts _flutterTts = FlutterTts();
  bool _isPlaying = false;
  int _secondsPlayed = 0;
  Timer? _playbackTimer;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  void _initTts() {
    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        _stopPlayback();
      }
    });
    _flutterTts.setErrorHandler((msg) {
      if (mounted) {
        _stopPlayback();
      }
    });
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  String get _languageLocale {
    switch (widget.currentLanguage) {
      case AppLanguage.hindi:
      case AppLanguage.hinglish:
        return 'hi-IN';
      case AppLanguage.marathi:
        return 'mr-IN';
      case AppLanguage.tamil:
        return 'ta-IN';
      case AppLanguage.telugu:
        return 'te-IN';
      case AppLanguage.bengali:
        return 'bn-IN';
      case AppLanguage.gujarati:
        return 'gu-IN';
      case AppLanguage.kannada:
        return 'kn-IN';
      case AppLanguage.malayalam:
        return 'ml-IN';
      case AppLanguage.punjabi:
        return 'pa-IN';
      case AppLanguage.odia:
        return 'or-IN';
      case AppLanguage.urdu:
        return 'ur-IN';
      case AppLanguage.english:
        return 'en-IN';
    }
  }

  void _togglePlayback() {
    if (_isPlaying) {
      _stopPlayback();
    } else {
      _startPlayback();
    }
  }

  int get _totalDurationSeconds {
    int words = widget.triageResult.ttsScript.split(' ').length;
    int seconds = (words / 2.5).ceil();
    return seconds < 10 ? 10 : seconds;
  }

  void _startPlayback() async {
    setState(() {
      _isPlaying = true;
      if (_secondsPlayed >= _totalDurationSeconds) {
        _secondsPlayed = 0;
      }
    });

    try {
      await _flutterTts.setLanguage(_languageLocale);
      await _flutterTts.setSpeechRate(0.45);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.speak(widget.triageResult.ttsScript);
    } catch (_) {}

    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsPlayed < _totalDurationSeconds) {
          _secondsPlayed++;
        } else {
          _stopPlayback();
        }
      });
    });
  }

  void _stopPlayback() async {
    _playbackTimer?.cancel();
    try {
      await _flutterTts.stop();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isPlaying = false;
      });
    }
  }

  String _formatDuration(int seconds) {
    int mins = seconds ~/ 60;
    int secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final double progress = _secondsPlayed / _totalDurationSeconds;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppTranslations.getText('listen_tts_btn', widget.currentLanguage),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            AppTranslations.getText('audio_page_subtitle', widget.currentLanguage),
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 20),

          // 10-Second Audio Player Card
          Card(
            elevation: 6,
            color: const Color(0xFF0D47A1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(22.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.record_voice_over, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppTranslations.getText('audio_card_title', widget.currentLanguage),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppTranslations.getText('audio_target_subtitle', widget.currentLanguage),
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_formatDuration(_secondsPlayed)} / ${_formatDuration(_totalDurationSeconds)}',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Animated Waveform Visualizer
                  SizedBox(
                    height: 40,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(24, (index) {
                        double height = _isPlaying ? ((index * 7 + _secondsPlayed * 5) % 28 + 8).toDouble() : 8.0;
                        bool isActive = (index / 24.0) <= progress;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.symmetric(horizontal: 2.5),
                          width: 4,
                          height: height,
                          decoration: BoxDecoration(
                            color: isActive ? Colors.lightBlueAccent : Colors.white54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Progress Bar Indicator
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.lightBlueAccent),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Play / Pause Button
                  IconButton.filled(
                    iconSize: 56,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0D47A1),
                      elevation: 4,
                    ),
                    icon: Icon(
                      _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                    ),
                    onPressed: _togglePlayback,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isPlaying
                        ? '🔊 Playing...'
                        : (_secondsPlayed >= _totalDurationSeconds
                            ? '✓ Audio Brief Complete'
                            : AppTranslations.getText('audio_play_hint', widget.currentLanguage)),
                    style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Classified Symptoms & TTS Script Section
          Text(
            AppTranslations.getText('audio_script_title', widget.currentLanguage),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.psychology, size: 20, color: Color(0xFF0D47A1)),
                      const SizedBox(width: 8),
                      Text(
                        AppTranslations.getText('audio_digest_title', widget.currentLanguage),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D47A1)),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Text(
                    '"${widget.triageResult.ttsScript}"',
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Forward Action Button
          ElevatedButton.icon(
            onPressed: widget.onGoToDispatch,
            icon: const Icon(Icons.send),
            label: const Text('Proceed to Dispatch & Referral'),
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
