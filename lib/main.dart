import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants/app_strings.dart';
import 'core/routing/app_router.dart';
import 'core/routing/app_routes.dart';
import 'core/services/secure_storage_service.dart';
import 'core/services/service_locator.dart';
import 'core/services/storage_service.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize persistent storage
  final prefs = await SharedPreferences.getInstance();

  // Initialize service locator foundation
  ServiceLocator.instance.init(
    customStorageService: SharedPreferencesStorageService(prefs),
    customSecureStorageService: FlutterSecureStorageService(),
    useBackendApi: true,
  );

  runApp(const PukaarApp());
}

/// Root widget for the Pukaar Emergency Platform.
class PukaarApp extends StatelessWidget {
  const PukaarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}
