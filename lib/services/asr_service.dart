import 'dart:convert';
import 'package:http/http.dart' as http;
import 'sync_service.dart';

class AsrResult {
  final bool success;
  final String transcript;
  final double confidence;
  final String language;
  final String? error;

  AsrResult({
    required this.success,
    required this.transcript,
    this.confidence = 1.0,
    this.language = 'hi-IN',
    this.error,
  });
}

class AsrService {
  static final AsrService instance = AsrService._init();
  AsrService._init();

  /// Send base64 audio bytes or payload to Person A's /api/asr endpoint
  Future<AsrResult> transcribeAudio({
    required String base64Audio,
    String languageCode = 'hi-IN',
  }) async {
    try {
      final baseUrl = SyncService.instance.baseUrl;
      final response = await http.post(
        Uri.parse('$baseUrl/api/asr'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'audio': base64Audio,
          'language': languageCode,
          'decoding': 'ctc',
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final resData = data['data'];
          return AsrResult(
            success: true,
            transcript: resData['transcript'] ?? '',
            confidence: (resData['confidence'] ?? 1.0).toDouble(),
            language: resData['language'] ?? languageCode,
          );
        }
      }
      return AsrResult(
        success: false,
        transcript: '',
        error: 'ASR server returned status ${response.statusCode}',
      );
    } catch (e) {
      return AsrResult(
        success: false,
        transcript: '',
        error: e.toString(),
      );
    }
  }
}
