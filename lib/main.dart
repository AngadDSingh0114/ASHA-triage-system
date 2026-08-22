import 'dart:async';
import 'package:flutter/material.dart';
import 'l10n/app_translations.dart';
import 'models/patient_triage_model.dart';
import 'screens/audio_player_screen.dart';
import 'screens/dispatch_screen.dart';
import 'screens/patient_details_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/triage_result_screen.dart';
import 'screens/vitals_form_screen.dart';
import 'services/database_helper.dart';
import 'services/sync_service.dart';
import 'widgets/language_selector_dialog.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AshaTriageApp());
}

class AshaTriageApp extends StatefulWidget {
  const AshaTriageApp({super.key});

  @override
  State<AshaTriageApp> createState() => _AshaTriageAppState();
}

class _AshaTriageAppState extends State<AshaTriageApp> {
  final LanguageController _languageController = LanguageController();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ASHA Tele-Triage Companion',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D47A1), // Healthcare Deep Blue
          primary: const Color(0xFF0D47A1),
          secondary: const Color(0xFF00897B),
          surface: const Color(0xFFF5F7FA),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 68,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D47A1),
              );
            }
            return const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            );
          }),
        ),
      ),
      home: AshaHomeScreen(languageController: _languageController),
    );
  }
}

class AshaHomeScreen extends StatefulWidget {
  final LanguageController languageController;

  const AshaHomeScreen({super.key, required this.languageController});

  @override
  State<AshaHomeScreen> createState() => _AshaHomeScreenState();
}

class _AshaHomeScreenState extends State<AshaHomeScreen> {
  bool _showSplash = true;
  int _currentScreenIndex =
      0; // 0: Patient Details, 1: Voice STT, 2: Result, 3: Audio, 4: Dispatch

  // Active Demo Patient Schema
  final Patient _patient = Patient(
    id: 'ASHA-2026-8942',
    name: 'Aarav Kumar',
    ageMonths: 14,
    gender: 'Male',
    village: 'Rampur Sub-Center',
    guardianName: 'Sunita Kumar',
    illnessOnset: '1 - 2 Days ago',
  );

  // Active Vitals State
  final Vitals _vitals = Vitals(
    temperatureF: 101.4,
    respiratoryRate: 52, // Fast breathing for 14-month old (>50)
    heartRate: 110,
    spo2: 93, // Mild hypoxia
  );

  // Active Danger Signs State
  final DangerSigns _dangerSigns = DangerSigns(
    chestIndrawing: true, // Triggers RED emergency
    unableToDrinkOrFeed: false,
    convulsions: false,
  );

  // Evaluated Triage Result
  late TriageResult _triageResult;
  bool _isOnline = false;
  Timer? _networkTimer;

  @override
  void initState() {
    super.initState();
    widget.languageController.addListener(_onLanguageChanged);
    _reEvaluateTriage();
    _startNetworkMonitoring();
  }

  void _onLanguageChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.languageController.removeListener(_onLanguageChanged);
    _networkTimer?.cancel();
    super.dispose();
  }

  void _startNetworkMonitoring() {
    _checkNetworkConnectivity();
    _networkTimer?.cancel();
    _networkTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _checkNetworkConnectivity();
    });
  }

  void _checkNetworkConnectivity() async {
    final status = await SyncService.instance.checkOnlineStatus();
    if (mounted && status != _isOnline) {
      setState(() {
        _isOnline = status;
      });
    }
  }

  void _reEvaluateTriage() {
    setState(() {
      _triageResult = TriageResult.evaluate(
        patient: _patient,
        vitals: _vitals,
        dangerSigns: _dangerSigns,
      );
    });

    // Save locally to SQLite database matching local_schema.sql
    DatabaseHelper.instance.saveTriageAssessment(
      patient: _patient,
      vitals: _vitals,
      dangerSigns: _dangerSigns,
      result: _triageResult,
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return LanguageSelectorDialog(
          currentLanguage: widget.languageController.value,
          onLanguageSelected: (newLang) {
            setState(() {
              widget.languageController.setLanguage(newLang);
            });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLanguage = widget.languageController.value;

    // Show Splash Screen first
    if (_showSplash) {
      return SplashScreen(
        languageController: widget.languageController,
        currentLanguage: currentLanguage,
        onStartScreening: () {
          setState(() {
            _showSplash = false;
            _currentScreenIndex = 0; // Go to Patient Details Screen
          });
        },
      );
    }

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
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.home),
          tooltip: 'Splash Screen',
          onPressed: () {
            setState(() {
              _showSplash = true;
            });
          },
        ),
        titleSpacing: 4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                AppTranslations.getText('app_title', currentLanguage),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            Text(
              AppTranslations.getText('app_subtitle', currentLanguage),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          // Language Switcher Button (EN / HI / MR)
          InkWell(
            onTap: _showLanguageDialog,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.language, color: Colors.white, size: 16),
                  const SizedBox(width: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      langBadge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Dynamic Network Connectivity Status Badge (ONLINE MODE vs OFFLINE MODE)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(right: 8, left: 2),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: _isOnline ? Colors.green.shade600 : Colors.amber.shade800,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: (_isOnline ? Colors.green : Colors.amber).withValues(alpha: 0.4),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isOnline ? Icons.wifi : Icons.wifi_off,
                  size: 11,
                  color: Colors.white,
                ),
                const SizedBox(width: 3),
                Text(
                  _isOnline
                      ? 'ONLINE'
                      : AppTranslations.getText('offline_mode', currentLanguage),
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentScreenIndex,
        children: [
          PatientDetailsScreen(
            patient: _patient,
            currentLanguage: currentLanguage,
            onProceedToVoice: () {
              setState(() {
                _currentScreenIndex = 1; // Go to Voice STT Triage
              });
            },
          ),
          VitalsFormScreen(
            patient: _patient,
            vitals: _vitals,
            dangerSigns: _dangerSigns,
            currentLanguage: currentLanguage,
            onVitalsChanged: _reEvaluateTriage,
            onSubmit: () {
              setState(() {
                _currentScreenIndex = 2; // Go to Result Screen
              });
            },
          ),
          TriageResultScreen(
            triageResult: _triageResult,
            currentLanguage: currentLanguage,
            onGoToAudio: () {
              setState(() {
                _currentScreenIndex = 3; // Go to Audio Note Screen
              });
            },
            onGoToDispatch: () {
              setState(() {
                _currentScreenIndex = 4; // Go to Dispatch Screen
              });
            },
          ),
          AudioPlayerScreen(
            triageResult: _triageResult,
            currentLanguage: currentLanguage,
            onGoToDispatch: () {
              setState(() {
                _currentScreenIndex = 4; // Go to Dispatch Screen
              });
            },
          ),
          DispatchScreen(
            triageResult: _triageResult,
            currentLanguage: currentLanguage,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentScreenIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentScreenIndex = index;
          });
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.person_add),
            selectedIcon: const Icon(
              Icons.person_add,
              color: Color(0xFF0D47A1),
            ),
            label: AppTranslations.getText('tab_patient', currentLanguage),
          ),
          NavigationDestination(
            icon: const Icon(Icons.mic),
            selectedIcon: const Icon(Icons.mic, color: Color(0xFF0D47A1)),
            label: AppTranslations.getText('tab_vitals', currentLanguage),
          ),
          NavigationDestination(
            icon: const Icon(Icons.assignment_turned_in),
            selectedIcon: const Icon(
              Icons.assignment_turned_in,
              color: Color(0xFF0D47A1),
            ),
            label: AppTranslations.getText('tab_result', currentLanguage),
          ),
          NavigationDestination(
            icon: const Icon(Icons.graphic_eq),
            selectedIcon: const Icon(
              Icons.graphic_eq,
              color: Color(0xFF0D47A1),
            ),
            label: AppTranslations.getText('tab_audio', currentLanguage),
          ),
          NavigationDestination(
            icon: const Icon(Icons.send),
            selectedIcon: const Icon(Icons.send, color: Color(0xFF0D47A1)),
            label: AppTranslations.getText('tab_dispatch', currentLanguage),
          ),
        ],
      ),
    );
  }
}
