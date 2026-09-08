import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/routing/app_routes.dart';

import '../../../../core/services/service_locator.dart';

/// Splash screen displaying Pukaar branding and routing to onboarding or home.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  void _navigateToNext() async {
    final authService = ServiceLocator.instance.authService;

    // Fetch session details asynchronously
    final onboardingCompleted = await authService.isOnboardingCompleted();
    bool loggedIn = await authService.isLoggedIn();

    if (loggedIn) {
      final validationResult = await authService.validateSession();
      if (!validationResult.isSuccess) {
        // If token is invalid (401), authService.logout() was executed, so isLoggedIn() is false.
        // If network is offline, session is preserved, so isLoggedIn() remains true.
        loggedIn = await authService.isLoggedIn();
      }
    }

    _timer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        if (!onboardingCompleted) {
          Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
        } else if (!loggedIn) {
          Navigator.pushReplacementNamed(context, AppRoutes.login);
        } else {
          Navigator.pushReplacementNamed(context, AppRoutes.home);
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Padding(
          padding: AppDimensions.paddingLg,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.overlayDark,
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  size: 54,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppDimensions.spaceLg),
              Text(
                AppStrings.appName.toUpperCase(),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  color: AppColors.white,
                ),
              ),
              const SizedBox(height: AppDimensions.spaceSm),
              const Text(
                AppStrings.appTagline,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: AppDimensions.space2xl),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                strokeWidth: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
