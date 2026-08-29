import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/models/user_profile.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/primary_button.dart';

/// Screen managing user's primary emergency contact list.
class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  UserProfile? _profile;
  bool _isLoading = true;
  bool _isSaving = false;

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _contactNameController;
  late TextEditingController _contactPhoneController;

  @override
  void initState() {
    super.initState();
    _contactNameController = TextEditingController();
    _contactPhoneController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    super.dispose();
  }

  void _loadProfile() async {
    final authService = ServiceLocator.instance.authService;
    final profile = await authService.getCurrentUser();
    if (profile != null) {
      setState(() {
        _profile = profile;
        _contactNameController.text = profile.emergencyContactName;
        _contactPhoneController.text = profile.emergencyContactPhone;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _saveContact() async {
    if (_profile == null) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final updated = _profile!.copyWith(
      emergencyContactName: _contactNameController.text.trim(),
      emergencyContactPhone: _contactPhoneController.text.trim(),
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
          content: Text('Emergency contact saved successfully.'),
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
        appBar: AppBar(title: const Text(AppStrings.emergencyContacts)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.emergencyContacts),
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
                  'Trusted Contacts',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppDimensions.space2xs),
                Text(
                  'These details are broadcasted during a crisis to alert your family/guardians.',
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
                            Text(
                              'Primary Guardian Details',
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: AppDimensions.spaceMd),
                            TextFormField(
                              controller: _contactNameController,
                              decoration: const InputDecoration(
                                labelText: 'Contact Name *',
                                prefixIcon: Icon(Icons.person_outline),
                                hintText: 'e.g. Spouse, Parent, Sister',
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Contact Name cannot be empty';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppDimensions.spaceMd),
                            TextFormField(
                              controller: _contactPhoneController,
                              decoration: const InputDecoration(
                                labelText: 'Contact Mobile Number *',
                                prefixIcon: Icon(Icons.phone_outlined),
                              ),
                              keyboardType: TextInputType.phone,
                              validator: (value) {
                                if (value == null || value.trim().length < 10) {
                                  return 'Please enter a valid 10-digit mobile number';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                PrimaryButton(
                  icon: Icons.save,
                  label: 'Save Emergency Contact',
                  isLoading: _isSaving,
                  onPressed: _saveContact,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
