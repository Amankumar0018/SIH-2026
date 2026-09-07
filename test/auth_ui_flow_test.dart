import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pukaar/core/services/location_service.dart';
import 'package:pukaar/core/services/service_locator.dart';
import 'package:pukaar/features/auth/presentation/screens/login_screen.dart';

void main() {
  setUp(() {
    ServiceLocator.instance.init(
      customLocationService: MockLocationService(),
      useBackendApi: true, // Test password / Sign Up mode
    );
  });

  Widget createAuthScreen() {
    return const MaterialApp(
      home: LoginScreen(),
    );
  }

  testWidgets('LoginScreen displays Sign In and Sign Up tabs', (WidgetTester tester) async {
    await tester.pumpWidget(createAuthScreen());
    await tester.pumpAndSettle();

    expect(find.text('Sign In'), findsWidgets);
    expect(find.text('Sign Up'), findsWidgets);
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Mobile Number'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });

  testWidgets('LoginScreen switches to Sign Up tab and exposes role choices', (WidgetTester tester) async {
    await tester.pumpWidget(createAuthScreen());
    await tester.pumpAndSettle();

    // Tap on Sign Up tab
    await tester.tap(find.text('Sign Up').first);
    await tester.pumpAndSettle();

    expect(find.text('Create Pukaar Profile'), findsOneWidget);
    expect(find.text('Citizen'), findsOneWidget);
    expect(find.text('Responder'), findsOneWidget);
    expect(find.text('Dual (Both)'), findsOneWidget);
    expect(find.text('Create Account & Sign In'), findsOneWidget);
  });

  testWidgets('Sign Up validation prevents submission of empty fields', (WidgetTester tester) async {
    await tester.pumpWidget(createAuthScreen());
    await tester.pumpAndSettle();

    // Switch to Sign Up tab
    await tester.tap(find.text('Sign Up').first);
    await tester.pumpAndSettle();

    // Ensure button is visible before tapping
    final submitButton = find.text('Create Account & Sign In');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(find.text('Full name is required'), findsOneWidget);
    expect(find.text('Valid 10-digit mobile number required'), findsOneWidget);
  });
}
