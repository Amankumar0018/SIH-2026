import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/models/emergency_enums.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/primary_button.dart';

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
    if (_selectedOption == null) return;

    final emergencyCategory = EmergencyCategory.fromString(widget.category);

    // Dispatch incident through the Emergency Engine Foundation service
    final result = await ServiceLocator.instance.emergencyService.createIncident(
      category: emergencyCategory,
      intent: _selectedOption!,
      priority: EmergencyPriority.high,
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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getCategoryColor();
    final options = _getOptions();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category),
        backgroundColor: theme.appBarTheme.backgroundColor,
      ),
      body: SafeArea(
        child: Padding(
          padding: AppDimensions.paddingMd,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppDimensions.spaceSm),
              Text(
                'Specify Emergency Intent',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spaceSm),
              Text(
                'Select the closest option to help dispatch the correct response team.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spaceLg),
              Expanded(
                child: ListView.separated(
                  itemCount: options.length,
                  separatorBuilder: (context, index) => const SizedBox(height: AppDimensions.spaceSm),
                  itemBuilder: (context, index) {
                    final option = options[index];
                    final isSelected = _selectedOption == option;

                    return AppCard(
                      borderColor: isSelected ? color : null,
                      backgroundColor: isSelected ? color.withValues(alpha: 0.08) : null,
                      onTap: () {
                        setState(() {
                          _selectedOption = option;
                        });
                      },
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: isSelected ? color : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: AppDimensions.spaceMd),
                          Text(
                            option,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? color : theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              PrimaryButton(
                backgroundColor: color,
                label: 'Confirm Emergency Request',
                onPressed: _selectedOption == null ? null : _confirmEmergencyRequest,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

