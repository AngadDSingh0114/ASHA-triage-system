import 'dart:convert';
import 'package:http/http.dart' as http;
import 'database_helper.dart';

class SyncResult {
  final bool success;
  final int syncedCount;
  final String message;

  SyncResult({
    required this.success,
    required this.syncedCount,
    required this.message,
  });
}

class SyncService {
  static final SyncService instance = SyncService._init();
  SyncService._init();

  String _activeServerUrl = 'http://172.16.29.169:8000';

  /// Determine the Person D central server base URL
  String get baseUrl => _activeServerUrl;

  /// Check if network connection to backend server or general internet is active
  Future<bool> checkOnlineStatus() async {
    // 1. Try laptop Wi-Fi server endpoint first (for physical phone)
    try {
      final response = await http
          .get(Uri.parse('http://172.16.29.169:8000/api/records'))
          .timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        _activeServerUrl = 'http://172.16.29.169:8000';
        return true;
      }
    } catch (_) {}

    // 2. Try Android emulator loopback endpoint
    try {
      final response = await http
          .get(Uri.parse('http://10.0.2.2:8000/api/records'))
          .timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        _activeServerUrl = 'http://10.0.2.2:8000';
        return true;
      }
    } catch (_) {}

    // 3. Try Localhost endpoint
    try {
      final response = await http
          .get(Uri.parse('http://localhost:8000/api/records'))
          .timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        _activeServerUrl = 'http://localhost:8000';
        return true;
      }
    } catch (_) {}

    // 4. Fallback check for general internet connection on physical phones (Wi-Fi / 4G / 5G)
    try {
      final response = await http
          .get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Sync all local PENDING records to Person D's server.py backend
  Future<SyncResult> syncPendingRecords({String? customBaseUrl}) async {
    try {
      final dbHelper = DatabaseHelper.instance;
      final pendingRows = await dbHelper.getPendingAssessmentsWithPatientData();

      if (pendingRows.isEmpty) {
        return SyncResult(
          success: true,
          syncedCount: 0,
          message: 'No pending offline records to sync.',
        );
      }

      final List<Map<String, dynamic>> recordsPayload = [];

      for (var row in pendingRows) {
        List<String> symptoms = [];
        try {
          if (row['symptoms_json'] != null) {
            symptoms = List<String>.from(jsonDecode(row['symptoms_json']));
          }
        } catch (_) {}

        List<String> actions = [];
        try {
          if (row['actions_json'] != null) {
            actions = List<String>.from(jsonDecode(row['actions_json']));
          }
        } catch (_) {}

        recordsPayload.add({
          "patient": {
            "patient_id": row['patient_id'],
            "full_name": row['full_name'] ?? 'Unknown Child',
            "age_months": row['age_months'] ?? 12,
            "gender": row['gender'] ?? 'M',
            "guardian_name": row['guardian_name'] ?? '',
            "village_name": row['village_name'] ?? 'Sector 4',
          },
          "assessment": {
            "assessment_id": row['assessment_id'],
            "asha_id": row['asha_id'] ?? 'ASHA-MH-PUNE-012',
            "temperature_c": row['temperature_c'] ?? 37.0,
            "respiratory_rate": row['respiratory_rate'] ?? 24,
            "heart_rate": row['heart_rate'] ?? 80,
            "spo2": row['spo2'] ?? 98,
            "fever_days": row['fever_days'] ?? 0,
            "symptoms": symptoms,
            "has_chest_indrawing": (row['has_chest_indrawing'] == 1),
            "has_convulsions": (row['has_convulsions'] == 1),
            "has_vomiting_everything": (row['has_vomiting_everything'] == 1),
            "has_lethargy": (row['has_lethargy'] == 1),
            "triage_color": row['triage_color'] ?? 'GREEN',
            "diagnosis": row['diagnosis'] ?? 'Routine Care',
            "urgency": row['urgency'] ?? 'Home Care',
            "primary_danger": row['primary_danger'] ?? 'None',
            "actions": actions,
            "referral_note": row['referral_note'] ?? 'No referral note',
            "assessed_at": row['assessed_at'] ?? DateTime.now().toIso8601String(),
          }
        });
      }

      final body = jsonEncode({
        "asha_id": "ASHA-MH-PUNE-012",
        "records": recordsPayload,
      });

      final targetUrl = '${customBaseUrl ?? baseUrl}/api/sync/batch';
      final response = await http
          .post(
            Uri.parse(targetUrl),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final syncedIds = List<String>.from(data['synced_ids'] ?? []);

        int successCount = 0;
        for (String id in syncedIds) {
          await dbHelper.markAsSynced(id);
          successCount++;
        }

        return SyncResult(
          success: true,
          syncedCount: successCount,
          message: 'Successfully synced $successCount records to PHC Central Server!',
        );
      } else {
        return SyncResult(
          success: false,
          syncedCount: 0,
          message: 'Server returned HTTP ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      return SyncResult(
        success: false,
        syncedCount: 0,
        message: 'Sync connection failed: $e. Make sure server.py is running on port 8000!',
      );
    }
  }
}
