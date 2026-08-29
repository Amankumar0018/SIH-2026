import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/secondary_button.dart';

/// SOS Emergency Screen placeholder for active alert triggers and countdown.
class EmergencySosScreen extends StatelessWidget {
  const EmergencySosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Trigger'),
      ),
      body: SafeArea(
        child: Padding(
          padding: AppDimensions.paddingLg,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: AppDimensions.sosButtonSize,
                  height: AppDimensions.sosButtonSize,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 24,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 48, color: AppColors.white),
                        SizedBox(height: AppDimensions.spaceXs),
                        Text(
                          'SOS',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.spaceXl),
              Text(
                'Pressing SOS will broadcast your current GPS coordinates to nearest response dispatchers and trusted contacts.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              AppCard(
                backgroundColor: AppColors.medicalEmergency.withValues(alpha: 0.08),
                borderColor: AppColors.medicalEmergency.withValues(alpha: 0.2),
                child: const Row(
                  children: [
                    Icon(Icons.location_on, color: AppColors.primary),
                    SizedBox(width: AppDimensions.spaceSm),
                    Expanded(
                      child: Text(
                        'Location ready: GPS status active',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.spaceMd),
              SecondaryButton(
                label: AppStrings.cancelSos,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
