import 'package:flutter/material.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/emergency/presentation/screens/emergency_intent_screen.dart';
import '../../features/emergency/presentation/screens/emergency_sos_screen.dart';
import '../../features/emergency/presentation/screens/emergency_tracking_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/onboarding/presentation/screens/splash_screen.dart';
import '../../features/profile/presentation/screens/emergency_contacts_screen.dart';
import '../../features/profile/presentation/screens/medical_id_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/responder/presentation/screens/responder_dashboard_screen.dart';
import '../../shared/widgets/error_state.dart';
import '../models/emergency_incident.dart';
import 'app_routes.dart';

/// Centralized route generator for Pukaar application.
class AppRouter {
  AppRouter._();

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );

      case AppRoutes.onboarding:
        return MaterialPageRoute(
          builder: (_) => const OnboardingScreen(),
          settings: settings,
        );

      case AppRoutes.login:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );

      case AppRoutes.register:
        return MaterialPageRoute(
          builder: (_) => const RegisterScreen(),
          settings: settings,
        );

      case AppRoutes.home:
        return MaterialPageRoute(
          builder: (_) => const HomeScreen(),
          settings: settings,
        );

      case AppRoutes.emergencySos:
        return MaterialPageRoute(
          builder: (_) => const EmergencySosScreen(),
          settings: settings,
        );

      case AppRoutes.profile:
        return MaterialPageRoute(
          builder: (_) => const ProfileScreen(),
          settings: settings,
        );

      case AppRoutes.emergencyContacts:
        return MaterialPageRoute(
          builder: (_) => const EmergencyContactsScreen(),
          settings: settings,
        );

      case AppRoutes.medicalId:
        return MaterialPageRoute(
          builder: (_) => const MedicalIdScreen(),
          settings: settings,
        );

      case AppRoutes.emergencyIntent:
        final category = settings.arguments as String? ?? 'Emergency';
        return MaterialPageRoute(
          builder: (_) => EmergencyIntentScreen(category: category),
          settings: settings,
        );

      case AppRoutes.emergencyTracking:
        final incident = settings.arguments as EmergencyIncident;
        return MaterialPageRoute(
          builder: (_) => EmergencyTrackingScreen(incident: incident),
          settings: settings,
        );

      case AppRoutes.responderDashboard:
        return MaterialPageRoute(
          builder: (_) => const ResponderDashboardScreen(),
          settings: settings,
        );

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Route Error')),
            body: ErrorState(
              title: 'Page Not Found',
              message: 'No route defined for "${settings.name}".',
            ),
          ),
          settings: settings,
        );
    }
  }
}
