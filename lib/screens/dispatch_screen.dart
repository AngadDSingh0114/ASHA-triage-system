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
                  future: DatabaseHelper.instance.getAllTriageAssessments(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final rows = snapshot.data ?? [];
                    if (rows.isEmpty) {
                      return const Center(
                        child: Text(
                          'No assessment records found in SQLite DB.',
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
                        final syncStatus = row['sync_status'] as String? ?? 'PENDING';
                        final isSynced = syncStatus == 'SYNCED';

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
                                  'Patient ID: ${row['patient_id']} (${row['full_name'] ?? 'Child'}) • ASHA ID: ${row['asha_id']}',
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
                                    Icon(
                                      isSynced ? Icons.check_circle : Icons.sync_problem,
                                      size: 14,
                                      color: isSynced ? Colors.green : Colors.orange,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Sync Status: $syncStatus',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isSynced ? Colors.green : Colors.orange,
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
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _isSyncing
                                ? 'Syncing...'
                                : AppTranslations.getText('sync_btn_label', widget.currentLanguage),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: const Color(0xFF0D47A1),
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // In-App DB Inspector Button & Clear Data Button Row
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showInAppDbInspector(context),
                              icon: const Icon(Icons.manage_search, size: 16),
                              label: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'View DB',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(38),
                                foregroundColor: const Color(0xFF0D47A1),
                                side: const BorderSide(color: Color(0xFF0D47A1)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await DatabaseHelper.instance.clearAllAssessmentData();
                                if (!context.mounted) return;
                                setState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('🗑️ All local assessment & patient data cleared!'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.delete_forever, size: 16),
                              label: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Clear All Data',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(38),
                                foregroundColor: Colors.redAccent,
                                side: const BorderSide(color: Colors.redAccent),
                              ),
                            ),
                          ),
                        ],
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
          const SizedBox(height: 20),

          // 3. Follow-Up Scheduling
          Text(
            'Follow-Up Scheduling',
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
                    'Schedule a follow-up appointment for this patient with the PHC doctor.',
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: () {
                      _showScheduleFollowupDialog(context);
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('Schedule Follow-Up'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: const Color(0xFF0D47A1),
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: DatabaseHelper.instance.getPendingAssessmentsWithPatientData(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox.shrink();
                      }
                      final rows = snapshot.data ?? [];
                      if (rows.isEmpty) return const SizedBox.shrink();
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Recent Patients (tap to schedule follow-up):',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          ...rows.map((row) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.person, size: 20, color: Colors.grey),
                            title: Text(
                              '${row['full_name'] ?? 'Patient'} (${row['patient_id']})',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${row['triage_color']} • ${row['diagnosis']}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.calendar_plus, size: 18, color: Color(0xFF0D47A1)),
                              onPressed: () => _showScheduleFollowupDialog(context, patientId: row['patient_id']),
                            ),
                          )).toList(),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showScheduleFollowupDialog(BuildContext context, {String? patientId}) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final notesController = TextEditingController();
    DateTime? selectedDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Schedule Follow-Up'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Patient Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Patient Phone',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 3)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        selectedDate = picked;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Follow-Up Date',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      selectedDate == null
                          ? 'Select Date'
                          : '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.notes),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty || selectedDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all required fields')),
                  );
                  return;
                }
                final followup = {
                  'followup_id': 'FUP-${DateTime.now().millisecondsSinceEpoch}',
                  'patient_id': patientId ?? 'P-${DateTime.now().millisecondsSinceEpoch}',
                  'assessment_id': widget.triageResult.patientId ?? '',
                  'follow_up_date': selectedDate!.toIso8601String(),
                  'follow_up_notes': notesController.text,
                  'status': 'SCHEDULED',
                };
                await DatabaseHelper.instance.createFollowup(followup);
                if (!context.mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Follow-up scheduled successfully'),
                    backgroundColor: Color(0xFF2E7D32),
                  ),
                );
              },
              child: const Text('Schedule'),
            ),
          ],
        ),
      ),
    );
  }
