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
      version: 1,
      onCreate: _createDB,
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

    await db.execute('CREATE INDEX IF NOT EXISTS idx_sync_status ON triage_assessments(sync_status);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_triage_color ON triage_assessments(triage_color);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_patient_lookup ON triage_assessments(patient_id);');
  }

  // --- Patients CRUD Operations ---
  Future<void> savePatient(Patient patient) async {
    final db = await instance.database;
    final genderCode = patient.gender.toUpperCase().startsWith('F')
        ? 'F'
        : (patient.gender.toUpperCase().startsWith('M') ? 'M' : 'O');

    await db.insert(
      'patients',
      {
        'patient_id': patient.id,
        'full_name': patient.name,
        'age_months': patient.ageMonths,
        'gender': genderCode,
        'guardian_name': patient.guardianName,
        'village_name': patient.village,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- Triage Assessments CRUD Operations ---
  Future<String> saveTriageAssessment({
    required Patient patient,
    required Vitals vitals,
    required DangerSigns dangerSigns,
    required TriageResult result,
    List<String>? detectedSymptoms,
  }) async {
    final db = await instance.database;
    await savePatient(patient);

    final assessmentId = 'TRG-${DateTime.now().millisecondsSinceEpoch ~/ 1000}';
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

  Future<List<Map<String, dynamic>>> getPendingAssessmentsWithPatientData() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT 
        a.*,
        p.full_name, p.age_months, p.gender, p.guardian_name, p.village_name
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
}
