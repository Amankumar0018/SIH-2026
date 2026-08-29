import 'package:flutter_test/flutter_test.dart';
import 'package:pukaar/core/models/user_profile.dart';
import 'package:pukaar/core/services/location_service.dart';
import 'package:pukaar/core/services/service_locator.dart';
import 'package:pukaar/main.dart';

void main() {
  testWidgets('Pukaar App first launch goes to Onboarding', (WidgetTester tester) async {
    ServiceLocator.instance.init(
      customLocationService: MockLocationService(),
    );

    await tester.pumpWidget(const PukaarApp());
    // Initial frame on Splash
    expect(find.text('PUKAAR'), findsOneWidget);

    // Let the splash timer complete and navigate to Onboarding
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Onboarding screen is reached
    expect(find.text('Welcome to Pukaar'), findsOneWidget);
    expect(find.text('One platform for emergency help.'), findsOneWidget);
  });

  testWidgets('Pukaar App already logged in goes to Home directly',
    (WidgetTester tester) async {
  ServiceLocator.instance.init(
    customLocationService: MockLocationService(),
  );

  final authService = ServiceLocator.instance.authService;

  await authService.setOnboardingCompleted(true);

  const testProfile = UserProfile(
    name: 'Pukaar Citizen User',
    mobileNumber: '9876543210',
    emergencyContactName: 'Father',
    emergencyContactPhone: '9811122334',
  );

  final registerFuture = authService.registerUser(testProfile);
  await tester.pump(const Duration(milliseconds: 600));
  await registerFuture;

  await tester.pumpWidget(const PukaarApp());

  await tester.pumpAndSettle();

  expect(find.text('Pukaar'), findsOneWidget);
});
}
