import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/localization/app_language.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../shared/widgets/primary_button.dart';

/// Interactive language selection screen for initial onboarding and settings.
class LanguageSelectionScreen extends StatefulWidget {
  final bool isSettings;

  const LanguageSelectionScreen({
    super.key,
    this.isSettings = false,
  });

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  late AppLanguage _selectedLanguage;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = ServiceLocator.instance.localizationService.currentLanguage;
  }

  void _onLanguageSelected(AppLanguage lang) {
    setState(() {
      _selectedLanguage = lang;
    });
  }

  Future<void> _applyAndProceed() async {
    final localizationService = ServiceLocator.instance.localizationService;
    await localizationService.setLanguage(_selectedLanguage);

    if (!mounted) return;

    if (widget.isSettings) {
      Navigator.pop(context, _selectedLanguage);
      return;
    }

    // Determine the next screen after initial startup language selection
    final authService = ServiceLocator.instance.authService;
    final onboardingCompleted = await authService.isOnboardingCompleted();
    final loggedIn = await authService.isLoggedIn();

    if (!mounted) return;

    if (!onboardingCompleted) {
      Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
    } else if (!loggedIn) {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = ServiceLocator.instance.localizationService.l10n;

    return Scaffold(
      appBar: widget.isSettings
          ? AppBar(
              title: Text(l10n.changeLanguage),
            )
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppDimensions.paddingLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.isSettings) const SizedBox(height: AppDimensions.spaceMd),

              // Multilingual Header
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.translate_rounded,
                    size: 32,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.spaceMd),

              Text(
                'Choose your language\nभाषा चुनें • भाषा निवडा',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: AppDimensions.spaceSm),
              Text(
                'Select your preferred emergency response language',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: AppDimensions.spaceLg),

              // Language Option Cards
              _buildLanguageCard(
                language: AppLanguage.english,
                nativeLabel: 'English',
                englishSubtitle: 'Primary English',
                scriptBadge: 'EN',
              ),
              const SizedBox(height: AppDimensions.spaceMd),

              _buildLanguageCard(
                language: AppLanguage.hindi,
                nativeLabel: 'हिंदी',
                englishSubtitle: 'Hindi',
                scriptBadge: 'हिं',
              ),
              const SizedBox(height: AppDimensions.spaceMd),

              _buildLanguageCard(
                language: AppLanguage.marathi,
                nativeLabel: 'मराठी',
                englishSubtitle: 'Marathi',
                scriptBadge: 'म',
              ),

              const SizedBox(height: AppDimensions.spaceXl),

              // Confirm / Continue Button
              PrimaryButton(
                label: _getContinueButtonLabel(),
                onPressed: _applyAndProceed,
              ),
              const SizedBox(height: AppDimensions.spaceMd),
            ],
          ),
        ),
      ),
    );
  }

  String _getContinueButtonLabel() {
    switch (_selectedLanguage) {
      case AppLanguage.hindi:
        return 'आगे बढ़ें (Continue)';
      case AppLanguage.marathi:
        return 'पुढे जा (Continue)';
      case AppLanguage.english:
        return 'Continue';
    }
  }

  Widget _buildLanguageCard({
    required AppLanguage language,
    required String nativeLabel,
    required String englishSubtitle,
    required String scriptBadge,
  }) {
    final isSelected = _selectedLanguage == language;

    return InkWell(
      onTap: () => _onLanguageSelected(language),
      borderRadius: AppDimensions.borderRadiusMd,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : Theme.of(context).cardColor,
          borderRadius: AppDimensions.borderRadiusMd,
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.withValues(alpha: 0.25),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : Colors.grey.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                scriptBadge,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: AppDimensions.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nativeLabel,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppColors.primary : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    englishSubtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected ? AppColors.primary : Colors.grey.shade400,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
