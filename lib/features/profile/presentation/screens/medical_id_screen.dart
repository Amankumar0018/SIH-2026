import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/models/user_profile.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/primary_button.dart';

/// Screen for displaying and configuring Medical ID parameters for first responders.
class MedicalIdScreen extends StatefulWidget {
  const MedicalIdScreen({super.key});

  @override
  State<MedicalIdScreen> createState() => _MedicalIdScreenState();
}

class _MedicalIdScreenState extends State<MedicalIdScreen> {
  UserProfile? _profile;
  bool _isLoading = true;
  bool _isSaving = false;

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _bloodGroupController;
  late TextEditingController _allergiesController;
  late TextEditingController _medicationsController;

  @override
  void initState() {
    super.initState();
    _bloodGroupController = TextEditingController();
    _allergiesController = TextEditingController();
    _medicationsController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _bloodGroupController.dispose();
    _allergiesController.dispose();
    _medicationsController.dispose();
    super.dispose();
  }

  void _loadProfile() async {
    final authService = ServiceLocator.instance.authService;
    final profile = await authService.getCurrentUser();
    if (profile != null) {
      setState(() {
        _profile = profile;
        _bloodGroupController.text = profile.bloodGroup ?? '';
        _allergiesController.text = profile.allergies ?? '';
        _medicationsController.text = profile.medications ?? '';
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _saveMedicalId() async {
    if (_profile == null) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final updated = _profile!.copyWith(
      bloodGroup: _bloodGroupController.text.trim().isEmpty ? null : _bloodGroupController.text.trim(),
      allergies: _allergiesController.text.trim().isEmpty ? null : _allergiesController.text.trim(),
      medications: _medicationsController.text.trim().isEmpty ? null : _medicationsController.text.trim(),
    );

    final authService = ServiceLocator.instance.authService;
    await authService.updateCurrentUser(updated);

    setState(() {
      _profile = updated;
      _isSaving = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Medical ID saved successfully.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.medicalId)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.medicalId),
      ),
      body: SafeArea(
        child: Padding(
          padding: AppDimensions.paddingMd,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Critical Health Profile',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppDimensions.space2xs),
                Text(
                  'Visible to verified medical dispatchers and paramedics to assist in emergency treatment.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppDimensions.spaceLg),
                Expanded(
                  child: ListView(
                    children: [
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _bloodGroupController,
                              decoration: const InputDecoration(
                                labelText: 'Blood Group',
                                prefixIcon: Icon(Icons.bloodtype_outlined),
                                hintText: 'e.g. O Positive (O+), A Negative (A-)',
                              ),
                            ),
                            const SizedBox(height: AppDimensions.spaceMd),
                            TextFormField(
                              controller: _allergiesController,
                              decoration: const InputDecoration(
                                labelText: 'Known Allergies',
                                prefixIcon: Icon(Icons.warning_amber_outlined),
                                hintText: 'e.g. Penicillin, Peanuts, Pollen',
                              ),
                              maxLines: 2,
                            ),
                            const SizedBox(height: AppDimensions.spaceMd),
                            TextFormField(
                              controller: _medicationsController,
                              decoration: const InputDecoration(
                                labelText: 'Active Medications / Notes',
                                prefixIcon: Icon(Icons.medical_services_outlined),
                                hintText: 'List any critical medications or notes',
                              ),
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                PrimaryButton(
                  icon: Icons.save,
                  label: 'Save Medical ID Details',
                  isLoading: _isSaving,
                  onPressed: _saveMedicalId,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
