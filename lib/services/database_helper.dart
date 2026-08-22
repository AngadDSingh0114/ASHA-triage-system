import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/patient_triage_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('asha_triage_local.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute('ALTER TABLE patients ADD COLUMN patient_phone TEXT;');
          } catch (_) {}
        }
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Patients Master Table matching local_schema.sql
    await db.execute('''
      CREATE TABLE IF NOT EXISTS patients (
        patient_id TEXT PRIMARY KEY,
        full_name TEXT NOT NULL,
        age_months INTEGER NOT NULL,
        gender TEXT CHECK(gender IN ('M', 'F', 'O')),
        guardian_name TEXT,
        village_name TEXT,
        patient_phone TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      );
    ''');

    // 2. Triage Assessments Table matching local_schema.sql
    await db.execute('''
      CREATE TABLE IF NOT EXISTS triage_assessments (
        assessment_id TEXT PRIMARY KEY,
        patient_id TEXT NOT NULL,
        asha_id TEXT NOT NULL DEFAULT 'ASHA-001',
        temperature_c REAL,
        respiratory_rate INTEGER,
        heart_rate INTEGER,
        spo2 INTEGER,
        fever_days INTEGER DEFAULT 0,
        symptoms_json TEXT NOT NULL,
        has_chest_indrawing BOOLEAN DEFAULT 0,
        has_convulsions BOOLEAN DEFAULT 0,
        has_vomiting_everything BOOLEAN DEFAULT 0,
        has_lethargy BOOLEAN DEFAULT 0,
        triage_color TEXT NOT NULL CHECK(triage_color IN ('RED', 'YELLOW', 'GREEN')),
        diagnosis TEXT NOT NULL,
        urgency TEXT NOT NULL,
        primary_danger TEXT,
        actions_json TEXT,
        referral_note TEXT NOT NULL,
        sync_status TEXT DEFAULT 'PENDING' CHECK(sync_status IN ('PENDING', 'SYNCING', 'SYNCED', 'FAILED')),
        doctor_acknowledged BOOLEAN DEFAULT 0,
        assessed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        synced_at DATETIME,
        FOREIGN KEY (patient_id) REFERENCES patients(patient_id)
      );
    ''');

    // 3. Follow-ups Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS followups (
        followup_id TEXT PRIMARY KEY,
        patient_id TEXT NOT NULL,
        assessment_id TEXT NOT NULL,
        doctor_id TEXT NOT NULL DEFAULT 'DOC-PUNE-01',
        follow_up_date TEXT NOT NULL,
        follow_up_notes TEXT DEFAULT '',
        status TEXT DEFAULT 'SCHEDULED' CHECK(status IN ('SCHEDULED', 'COMPLETED', 'OVERDUE', 'CANCELLED')),
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        completed_at TEXT,
        FOREIGN KEY (patient_id) REFERENCES patients(patient_id)
      );
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_sync_status ON triage_assessments(sync_status);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_triage_color ON triage_assessments(triage_color);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_patient_lookup ON triage_assessments(patient_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_followup_status ON followups(status);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_followup_patient ON followups(patient_id);');
  }

  // --- Patients CRUD Operations ---
  Future<void> savePatient(Patient patient) async {
    final db = await instance.database;
    final genderCode = patient.gender.toUpperCase().startsWith('F')
        ? 'F'
        : (patient.gender.toUpperCase().startsWith('M') ? 'M' : 'O');

    final phoneVal = patient.patientPhone.isNotEmpty ? patient.patientPhone : patient.phone;
    final patientData = <String, dynamic>{
      'patient_id': patient.id,
      'full_name': patient.name,
      'age_months': patient.ageMonths,
      'gender': genderCode,
      'guardian_name': patient.guardianName,
      'village_name': patient.village,
      'patient_phone': phoneVal,
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      await db.insert(
        'patients',
        patientData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      if (e.toString().contains('patient_phone')) {
        try {
          await db.execute('ALTER TABLE patients ADD COLUMN patient_phone TEXT;');
          await db.insert(
            'patients',
            patientData,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        } catch (_) {
          patientData.remove('patient_phone');
          await db.insert(
            'patients',
            patientData,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    }
  }

  // --- Triage Assessments CRUD Operations ---
  Future<String> saveTriageAssessment({
    required Patient patient,
    required Vitals vitals,
    required DangerSigns dangerSigns,
    required TriageResult result,
    String? customAssessmentId,
    List<String>? detectedSymptoms,
  }) async {
    final db = await instance.database;
    await savePatient(patient);

    final assessmentId = customAssessmentId ?? 'TRG-${patient.id}';
    final tempC = (vitals.temperatureF - 32.0) * (5.0 / 9.0);

    final String triageColor;
    switch (result.severity) {
      case TriageSeverity.red:
        triageColor = 'RED';
        break;
      case TriageSeverity.yellow:
        triageColor = 'YELLOW';
        break;
      case TriageSeverity.green:
        triageColor = 'GREEN';
        break;
    }

    final symptomsList = detectedSymptoms ??
        [
          if (dangerSigns.chestIndrawing) 'chest_indrawing',
          if (vitals.temperatureF >= 100.4) 'fever',
          if (vitals.respiratoryRate >= 40) 'fast_breathing',
        ];

    await db.insert(
      'triage_assessments',
      {
        'assessment_id': assessmentId,
        'patient_id': patient.id,
        'asha_id': 'ASHA-001',
        'temperature_c': double.parse(tempC.toStringAsFixed(1)),
        'respiratory_rate': vitals.respiratoryRate,
        'heart_rate': vitals.heartRate,
        'spo2': vitals.spo2,
        'fever_days': vitals.feverDays,
        'symptoms_json': jsonEncode(symptomsList),
        'has_chest_indrawing': dangerSigns.chestIndrawing ? 1 : 0,
        'has_convulsions': dangerSigns.convulsions ? 1 : 0,
        'has_vomiting_everything': dangerSigns.vomitsEverything ? 1 : 0,
        'has_lethargy': dangerSigns.lethargicOrUnconscious ? 1 : 0,
        'triage_color': triageColor,
        'diagnosis': result.title,
        'urgency': result.severityLabel,
        'primary_danger': result.rationale,
        'actions_json': jsonEncode(result.actionSteps),
        'referral_note': result.doctorAudioScript,
        'sync_status': 'PENDING',
        'doctor_acknowledged': 0,
        'assessed_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return assessmentId;
  }

  // --- Query Pending Sync Queue ---
  Future<List<Map<String, dynamic>>> getPendingAssessments() async {
    final db = await instance.database;
    return await db.query(
      'triage_assessments',
      where: 'sync_status = ?',
      whereArgs: ['PENDING'],
      orderBy: 'assessed_at DESC',
    );
  }

  /// Fetch all stored local assessments (both PENDING and SYNCED)
  Future<List<Map<String, dynamic>>> getAllTriageAssessments() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT 
        a.*,
        p.full_name, p.age_months, p.gender, p.guardian_name, p.village_name, p.patient_phone
      FROM triage_assessments a
      LEFT JOIN patients p ON a.patient_id = p.patient_id
      ORDER BY a.assessed_at DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getPendingAssessmentsWithPatientData() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT 
        a.*,
        p.full_name, p.age_months, p.gender, p.guardian_name, p.village_name, p.patient_phone
      FROM triage_assessments a
      JOIN patients p ON a.patient_id = p.patient_id
      WHERE a.sync_status = 'PENDING'
      ORDER BY a.assessed_at DESC
    ''');
  }

  Future<int> getPendingSyncCount() async {
    final db = await instance.database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM triage_assessments WHERE sync_status = 'PENDING'",
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getTotalPatientCount() async {
    final db = await instance.database;
    final result = await db.rawQuery("SELECT COUNT(*) as count FROM patients");
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> markAsSynced(String assessmentId) async {
    final db = await instance.database;
    await db.update(
      'triage_assessments',
      {
        'sync_status': 'SYNCED',
        'synced_at': DateTime.now().toIso8601String(),
      },
      where: 'assessment_id = ?',
      whereArgs: [assessmentId],
    );
  }

  /// Delete all stored local triage assessments and patient records
  Future<void> clearAllAssessmentData() async {
    final db = await instance.database;
    await db.delete('triage_assessments');
    await db.delete('patients');
  }

  // --- Follow-ups CRUD Operations ---
  Future<void> createFollowup(Map<String, dynamic> followupData) async {
    final db = await instance.database;
    await db.insert(
      'followups',
      {
        'followup_id': followupData['followup_id'],
        'patient_id': followupData['patient_id'],
        'assessment_id': followupData['assessment_id'],
        'doctor_id': followupData['doctor_id'] ?? 'DOC-PUNE-01',
        'follow_up_date': followupData['follow_up_date'],
        'follow_up_notes': followupData['follow_up_notes'] ?? '',
        'status': followupData['status'] ?? 'SCHEDULED',
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getFollowupsForPatient(String patientId) async {
    final db = await instance.database;
    return await db.query(
      'followups',
      where: 'patient_id = ?',
      whereArgs: [patientId],
      orderBy: 'follow_up_date DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getAllFollowups() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT f.*, p.full_name, p.patient_phone, p.age_months
      FROM followups f
      JOIN patients p ON f.patient_id = p.patient_id
      ORDER BY f.follow_up_date DESC
    ''');
  }

  Future<void> updateFollowupStatus(String followupId, String status) async {
    final db = await instance.database;
    final completedAt = status == 'COMPLETED' ? DateTime.now().toIso8601String() : null;
    await db.update(
      'followups',
      {
        'status': status,
        'completed_at': completedAt,
      },
      where: 'followup_id = ?',
      whereArgs: [followupId],
    );
  }
}
