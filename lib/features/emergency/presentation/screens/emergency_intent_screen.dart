import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/localization/app_language.dart';
import '../../../../core/models/emergency_enums.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../widgets/voice_emergency_input_card.dart';

/// Screen representing the specific emergency subcategory selection (Triage).
class EmergencyIntentScreen extends StatefulWidget {
  final String category;

  const EmergencyIntentScreen({
    super.key,
    required this.category,
  });

  @override
  State<EmergencyIntentScreen> createState() => _EmergencyIntentScreenState();
}

class _EmergencyIntentScreenState extends State<EmergencyIntentScreen> {
  String? _selectedOption;
  final TextEditingController _descriptionController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  List<String> _getOptions() {
    switch (widget.category.toLowerCase()) {
      case 'medical emergency':
      case 'medical':
        return ['Ambulance', 'Injury', 'Unconscious Person', 'Other'];
      case 'women\'s safety':
      case 'women safety':
      case 'safety':
        return ['Unsafe Situation', 'Harassment', 'Threat', 'Need Immediate Assistance', 'Other'];
      case 'disaster management':
      case 'disaster':
        return ['Fire', 'Flood', 'Earthquake', 'Building Emergency', 'Other'];
      case 'campus emergency':
      case 'campus':
        return ['Medical Incident', 'Campus Security', 'Active Fire', 'Harassment/Threat', 'Other'];
      default:
        return ['General Request', 'Other'];
    }
  }

  Color _getCategoryColor() {
    switch (widget.category.toLowerCase()) {
      case 'medical emergency':
      case 'medical':
        return AppColors.medicalEmergency;
      case 'women\'s safety':
      case 'women safety':
      case 'safety':
        return AppColors.womenSafety;
      case 'disaster management':
      case 'disaster':
        return AppColors.disasterManagement;
      case 'campus emergency':
      case 'campus':
        return AppColors.campusEmergency;
      default:
        return AppColors.primary;
    }
  }

  void _confirmEmergencyRequest() async {
    if (_isSubmitting) return;

    final notes = _descriptionController.text.trim();
    if (_selectedOption == null && notes.isEmpty) return;

    final emergencyCategory = EmergencyCategory.fromString(widget.category);
    final intent = _selectedOption ?? (notes.isNotEmpty ? 'Emergency Voice Report' : 'General Emergency');

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Dispatch incident through the Emergency Engine Foundation service
      final result = await ServiceLocator.instance.emergencyService.createIncident(
        category: emergencyCategory,
        intent: intent,
        priority: EmergencyPriority.high,
        notes: notes.isNotEmpty ? notes : null,
      );

      if (result.isSuccess && result.data != null && mounted) {
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.emergencyTracking,
          arguments: result.data!,
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Failed to broadcast emergency.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to broadcast emergency: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getCategoryColor();
    final options = _getOptions();
    final hasNotes = _descriptionController.text.trim().isNotEmpty;
    final canSubmit = (_selectedOption != null || hasNotes) && !_isSubmitting;
    final l10n = ServiceLocator.instance.localizationService.localizations;
    final categoryEnum = EmergencyCategory.fromString(widget.category);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.localizedEmergencyCategory(categoryEnum)),
        backgroundColor: theme.appBarTheme.backgroundColor,
      ),
      body: SafeArea(
        child: Padding(
          padding: AppDimensions.paddingMd,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppDimensions.spaceXs),
                      Text(
                        l10n.describeEmergencyTitle,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppDimensions.spaceXs),
                      Text(
                        l10n.describeEmergencySubtitle,
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppDimensions.spaceMd),

                      // Voice Input Card (Speech-to-Text & Editable notes)
                      VoiceEmergencyInputCard(
                        controller: _descriptionController,
                        onChanged: (text) {
                          setState(() {
                            // Smart suggestion: if an option keyword appears in speech, auto-suggest option if none selected
                            if (_selectedOption == null) {
                              final lower = text.toLowerCase();
                              for (final opt in options) {
                                if (lower.contains(opt.toLowerCase())) {
                                  _selectedOption = opt;
                                  break;
                                }
                              }
                            }
                          });
                        },
                      ),
                      const SizedBox(height: AppDimensions.spaceMd),

                      Text(
                        l10n.language == AppLanguage.hindi
                            ? 'श्रेणी चुनें (वैकल्पिक / फॉलबैक)'
                            : (l10n.language == AppLanguage.marathi
                                ? 'श्रेणी निवडा (पर्यायी / फॉलबॅक)'
                                : 'Select Category Intent (Fallback / Optional)'),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spaceSm),

                      // Options List
                      ...options.map((option) {
                        final isSelected = _selectedOption == option;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppDimensions.spaceSm),
                          child: AppCard(
                            borderColor: isSelected ? color : null,
                            backgroundColor: isSelected ? color.withValues(alpha: 0.08) : null,
                            onTap: _isSubmitting
                                ? null
                                : () {
                                    setState(() {
                                      _selectedOption = option;
                                    });
                                  },
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                  color: isSelected
                                      ? color
                                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                                const SizedBox(width: AppDimensions.spaceMd),
                                Text(
                                  option,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? color : theme.colorScheme.onSurface,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.spaceSm),
              PrimaryButton(
                backgroundColor: color,
                isLoading: _isSubmitting,
                label: l10n.language == AppLanguage.hindi
                    ? 'आपातकालीन अनुरोध भेजें'
                    : (l10n.language == AppLanguage.marathi
                        ? 'आणीबाणी विनंती पाठवा'
                        : 'Confirm Emergency Request'),
                onPressed: canSubmit ? _confirmEmergencyRequest : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

