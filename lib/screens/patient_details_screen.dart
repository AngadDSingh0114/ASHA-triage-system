import 'package:flutter/material.dart';
import '../l10n/app_translations.dart';
import '../models/patient_triage_model.dart';
import '../services/database_helper.dart';

class PatientDetailsScreen extends StatefulWidget {
  final Patient patient;
  final AppLanguage currentLanguage;
  final VoidCallback onProceedToVoice;

  const PatientDetailsScreen({
    super.key,
    required this.patient,
    required this.currentLanguage,
    required this.onProceedToVoice,
  });

  @override
  State<PatientDetailsScreen> createState() => _PatientDetailsScreenState();
}

class _PatientDetailsScreenState extends State<PatientDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _villageController;
  late TextEditingController _ageController;
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.patient.name);
    _villageController = TextEditingController(text: widget.patient.village);
    _ageController = TextEditingController(text: widget.patient.ageMonths > 0 ? widget.patient.ageMonths.toString() : '');
    _phoneController = TextEditingController(text: widget.patient.patientPhone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _villageController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _selectBirthdate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 420)), // ~14 months
      firstDate: DateTime.now().subtract(const Duration(days: 3650)), // ~10 years
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        widget.patient.birthdate = picked;
        final now = DateTime.now();
        int months = (now.year - picked.year) * 12 + (now.month - picked.month);
        if (months < 0) months = 0;
        widget.patient.ageMonths = months;
        _ageController.text = months.toString();
      });
    }
  }

  void _confirmAndProceed() async {
    FocusScope.of(context).unfocus(); // Close soft keyboard

    if (_nameController.text.trim().isNotEmpty) {
      widget.patient.name = _nameController.text.trim();
    }
    if (_villageController.text.trim().isNotEmpty) {
      widget.patient.village = _villageController.text.trim();
    }
    if (_phoneController.text.trim().isNotEmpty) {
      widget.patient.patientPhone = _phoneController.text.trim();
    }

    // Save Patient to local SQLite database
    await DatabaseHelper.instance.savePatient(widget.patient);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Registered Patient: ${widget.patient.name} (${widget.patient.ageDisplay})'),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF0D47A1),
        ),
      );
      widget.onProceedToVoice();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(left: 18.0, right: 18.0, top: 18.0, bottom: 80.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Header
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                AppTranslations.getText('patient_details_title', widget.currentLanguage),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Enter patient demographics & illness onset before voice triage screening.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              softWrap: true,
            ),
            const SizedBox(height: 20),

            // 1. Patient Name Input
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppTranslations.getText('patient_name_label', widget.currentLanguage),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      softWrap: true,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Aarav Kumar',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      onChanged: (val) {
                        setState(() {
                          widget.patient.name = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 1b. Patient Contact Phone Input
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Patient / Guardian Mobile Number (WhatsApp / SMS):',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      softWrap: true,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        hintText: '+91 98230 11223',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone_android),
                      ),
                      onChanged: (val) {
                        setState(() {
                          widget.patient.patientPhone = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 2. Birthdate & Age Picker Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppTranslations.getText('dob_label', widget.currentLanguage),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      softWrap: true,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _selectBirthdate(context),
                            icon: const Icon(Icons.calendar_month),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                widget.patient.birthdate == null
                                    ? 'Select Birthdate'
                                    : '${widget.patient.birthdate!.day}/${widget.patient.birthdate!.month}/${widget.patient.birthdate!.year}',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D47A1).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Age: ${widget.patient.ageDisplay}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0D47A1),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 3. Gender & Village Location Row
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppTranslations.getText('gender_label', widget.currentLanguage),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      softWrap: true,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ChoiceChip(
                          label: Text(AppTranslations.getText('gender_male', widget.currentLanguage)),
                          selected: widget.patient.gender == 'Male',
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                widget.patient.gender = 'Male';
                              });
                            }
                          },
                        ),
                        const SizedBox(width: 10),
                        ChoiceChip(
                          label: Text(AppTranslations.getText('gender_female', widget.currentLanguage)),
                          selected: widget.patient.gender == 'Female',
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                widget.patient.gender = 'Female';
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      AppTranslations.getText('village_label', widget.currentLanguage),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      softWrap: true,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _villageController,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Rampur Sub-Center',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      onChanged: (val) {
                        setState(() {
                          widget.patient.village = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 4. Illness Onset Selection Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppTranslations.getText('onset_label', widget.currentLanguage),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      softWrap: true,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: Text(AppTranslations.getText('onset_today', widget.currentLanguage)),
                          selected: widget.patient.illnessOnset == 'Today (Sudden onset)',
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                widget.patient.illnessOnset = 'Today (Sudden onset)';
                              });
                            }
                          },
                        ),
                        ChoiceChip(
                          label: Text(AppTranslations.getText('onset_2days', widget.currentLanguage)),
                          selected: widget.patient.illnessOnset == '1 - 2 Days ago',
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                widget.patient.illnessOnset = '1 - 2 Days ago';
                              });
                            }
                          },
                        ),
                        ChoiceChip(
                          label: Text(AppTranslations.getText('onset_week', widget.currentLanguage)),
                          selected: widget.patient.illnessOnset == 'More than a week ago',
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                widget.patient.illnessOnset = 'More than a week ago';
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Patient Confirmation Summary Card
            Container(
              padding: const EdgeInsets.all(14.0),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade700, width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_user, color: Colors.green.shade800, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CONFIRM PATIENT DETAILS:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                          ),
                          softWrap: true,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.patient.name} (${widget.patient.gender}, ${widget.patient.ageDisplay}) • Village: ${widget.patient.village}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          softWrap: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Confirm & Proceed Button
            ElevatedButton.icon(
              onPressed: _confirmAndProceed,
              icon: const Icon(Icons.arrow_forward, size: 24),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  AppTranslations.getText('proceed_voice_btn', widget.currentLanguage),
                ),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
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
      ),
    );
  }
}
