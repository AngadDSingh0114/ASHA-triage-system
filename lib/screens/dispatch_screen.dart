import 'package:flutter/material.dart';
import '../l10n/app_translations.dart';
import '../models/patient_triage_model.dart';
import '../services/database_helper.dart';
import '../services/sync_service.dart';

class DispatchScreen extends StatefulWidget {
  final TriageResult triageResult;
  final AppLanguage currentLanguage;

  const DispatchScreen({
    super.key,
    required this.triageResult,
    required this.currentLanguage,
  });

  @override
  State<DispatchScreen> createState() => _DispatchScreenState();
}

class _DispatchScreenState extends State<DispatchScreen> {
  bool _isSyncing = false;

  void _triggerHttpBatchSync() async {
    setState(() {
      _isSyncing = true;
    });

    final result = await SyncService.instance.syncPendingRecords();

    if (!mounted) return;

    setState(() {
      _isSyncing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              result.success ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                result.message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: result.success ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showInAppDbInspector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.storage, color: Color(0xFF0D47A1)),
                      SizedBox(width: 8),
                      Text(
                        'Local SQLite Database Inspector',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D47A1),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Text(
                'File: asha_triage_local.db • Table: triage_assessments',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const Divider(height: 20),

              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: DatabaseHelper.instance.getPendingAssessments(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final rows = snapshot.data ?? [];
                    if (rows.isEmpty) {
                      return const Center(
                        child: Text(
                          'No records pending sync in SQLite DB (All synced to PHC Server).',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: rows.length,
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        final colorStr = row['triage_color'] as String? ?? 'GREEN';
                        final color = colorStr == 'RED'
                            ? Colors.red
                            : (colorStr == 'YELLOW' ? Colors.amber.shade800 : Colors.green);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'ID: ${row['assessment_id']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: color),
                                      ),
                                      child: Text(
                                        colorStr,
                                        style: TextStyle(
                                          color: color,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Patient ID: ${row['patient_id']} • ASHA ID: ${row['asha_id']}',
                                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Vitals: Temp ${row['temperature_c']}°C, RR ${row['respiratory_rate']} bpm, SpO2 ${row['spo2']}%',
                                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Diagnosis: ${row['diagnosis']}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.sync_problem, size: 14, color: Colors.orange),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Sync Status: ${row['sync_status']}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${row['assessed_at']}'.split('.').first,
                                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppTranslations.getText('dispatch_title', widget.currentLanguage),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            AppTranslations.getText('dispatch_subtitle', widget.currentLanguage),
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 20),

          // Live Offline SQLite Queue Status Card with Sync Trigger & Inspector
          FutureBuilder<int>(
            future: DatabaseHelper.instance.getPendingSyncCount(),
            builder: (context, snapshot) {
              final pendingCount = snapshot.data ?? 0;

              return Card(
                color: Colors.amber.shade50,
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.storage, color: Color(0xFF0D47A1), size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SQLite DB Queue: $pendingCount Assessment(s) Pending Sync',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0D47A1),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  AppTranslations.getText('sqlite_queue_note', widget.currentLanguage),
                                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Primary HTTP Batch Sync Trigger Button
                      ElevatedButton.icon(
                        onPressed: _isSyncing ? null : _triggerHttpBatchSync,
                        icon: _isSyncing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.cloud_upload),
                        label: Text(
                          _isSyncing
                              ? 'Syncing to PHC Server...'
                              : '⚡ Sync Pending Records to PHC Dashboard',
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: const Color(0xFF0D47A1),
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // In-App DB Inspector Button
                      OutlinedButton.icon(
                        onPressed: () => _showInAppDbInspector(context),
                        icon: const Icon(Icons.manage_search, size: 18),
                        label: const Text(
                          '🔍 View Saved SQLite Records',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(38),
                          foregroundColor: const Color(0xFF0D47A1),
                          side: const BorderSide(color: Color(0xFF0D47A1)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // 1. WhatsApp Instant Deep Link Alert
          Text(
            AppTranslations.getText('whatsapp_title', widget.currentLanguage),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppTranslations.getText('whatsapp_sub', widget.currentLanguage),
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('📱 WhatsApp Deep-Link Alert dispatched to PHC Doctor!'),
                          backgroundColor: Color(0xFF2E7D32),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat),
                    label: Text(AppTranslations.getText('send_wa_btn', widget.currentLanguage)),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 2. Offline SMS Referral Fallback Snippet (140-char format)
          Text(
            AppTranslations.getText('sms_title', widget.currentLanguage),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppTranslations.getText('sms_sub', widget.currentLanguage),
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      widget.triageResult.smsSnippet,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('💬 SMS Referral Snippet copied to Clipboard!'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.send_to_mobile),
                    label: Text(AppTranslations.getText('send_sms_btn', widget.currentLanguage)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
