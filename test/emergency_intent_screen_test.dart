import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pukaar/core/models/emergency_enums.dart';
import 'package:pukaar/core/models/emergency_incident.dart';
import 'package:pukaar/core/routing/app_routes.dart';
import 'package:pukaar/core/services/emergency_service.dart';
import 'package:pukaar/core/services/localization_service.dart';
import 'package:pukaar/core/services/secure_storage_service.dart';
import 'package:pukaar/core/services/service_locator.dart';
import 'package:pukaar/core/services/speech_service.dart';
import 'package:pukaar/core/services/storage_service.dart';
import 'package:pukaar/core/utils/app_result.dart';
import 'package:pukaar/features/emergency/presentation/screens/emergency_intent_screen.dart';
import 'package:pukaar/shared/widgets/primary_button.dart';

class MockIntentEmergencyService implements EmergencyService {
  final StreamController<EmergencyIncident> _controller =
      StreamController<EmergencyIncident>.broadcast();
  int createIncidentCallCount = 0;
  Completer<AppResult<EmergencyIncident>>? pendingCreateCompleter;
  AppResult<EmergencyIncident>? fixedResult;
  bool shouldThrowException = false;

  @override
  Stream<EmergencyIncident> get incidentStream => _controller.stream;

  @override
  EmergencyIncident? get activeIncident => null;

  @override
  Future<AppResult<EmergencyIncident>> createIncident({
    required EmergencyCategory category,
    required String intent,
    EmergencyPriority priority = EmergencyPriority.high,
    double? latitude,
    double? longitude,
    double? accuracy,
    String? userId,
    String? notes,
  }) async {
    createIncidentCallCount++;
    if (shouldThrowException) {
      throw Exception('Network socket crash');
    }
    if (pendingCreateCompleter != null) {
      return pendingCreateCompleter!.future;
    }
    if (fixedResult != null) {
      return fixedResult!;
    }
    final incident = EmergencyIncident(
      id: 'INC_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId ?? 'guest_user',
      category: category,
      intent: intent,
      priority: priority,
      timestamp: DateTime.now(),
      notes: notes,
    );
    return AppResult.success(incident);
  }

  @override
  Future<AppResult<EmergencyIncident>> getIncidentById(String incidentId) async =>
      AppResult.failure('Not implemented');

  @override
  Future<AppResult<List<EmergencyIncident>>> getActiveIncidents() async =>
      AppResult.success([]);

  @override
  Future<AppResult<List<EmergencyIncident>>> getAllIncidents() async =>
      AppResult.success([]);

  @override
  Future<AppResult<EmergencyIncident>> updateIncidentStatus(
    String incidentId,
    EmergencyStatus newStatus, {
    String? responderId,
    String? responderName,
    String? responderPhone,
    String? responderType,
    double? responderLat,
    double? responderLng,
    int? etaMinutes,
  }) async =>
      AppResult.failure('Not implemented');

  @override
  Future<AppResult<EmergencyIncident>> cancelIncident(String incidentId, {String? reason}) async =>
      AppResult.failure('Not implemented');

  @override
  void dispose() {
    _controller.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockIntentEmergencyService mockEmergencyService;
  late StorageService storageService;
  late LocalizationService localizationService;
  late MockSpeechService mockSpeechService;

  setUp(() {
    storageService = InMemoryStorageService();
    localizationService = LocalizationService(storageService);
    mockEmergencyService = MockIntentEmergencyService();
    mockSpeechService = MockSpeechService();

    ServiceLocator.instance.init(
      customStorageService: storageService,
      customSecureStorageService: InMemorySecureStorageService(),
      customEmergencyService: mockEmergencyService,
      customLocalizationService: localizationService,
      customSpeechService: mockSpeechService,
      useBackendApi: false,
    );
  });

  tearDown(() {
    mockEmergencyService.dispose();
    mockSpeechService.dispose();
  });

  Widget buildTestWidget({String category = 'Medical Emergency'}) {
    return MaterialApp(
      routes: {
        AppRoutes.emergencyTracking: (context) {
          final incident = ModalRoute.of(context)!.settings.arguments as EmergencyIncident?;
          return Scaffold(
            body: Center(
              child: Text('Tracking Screen: ${incident?.id ?? 'none'}'),
            ),
          );
        },
      },
      home: EmergencyIntentScreen(category: category),
    );
  }

  group('EmergencyIntentScreen Duplicate Submission & Lock Tests', () {
    testWidgets('a. Button becomes disabled and shows CircularProgressIndicator during submission', (tester) async {
      final completer = Completer<AppResult<EmergencyIncident>>();
      mockEmergencyService.pendingCreateCompleter = completer;

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Select an option to enable the submit button
      await tester.tap(find.text('Ambulance'));
      await tester.pumpAndSettle();

      // Verify button is enabled initially
      final primaryButtonFinder = find.byType(PrimaryButton);
      expect(primaryButtonFinder, findsOneWidget);

      final buttonWidgetBefore = tester.widget<PrimaryButton>(primaryButtonFinder);
      expect(buttonWidgetBefore.onPressed, isNotNull);
      expect(buttonWidgetBefore.isLoading, isFalse);

      // Tap the submit button to initiate async submission
      await tester.tap(primaryButtonFinder);
      await tester.pump(); // Render the _isSubmitting = true state

      // Verify button is now in loading state with progress indicator
      final buttonWidgetDuring = tester.widget<PrimaryButton>(primaryButtonFinder);
      expect(buttonWidgetDuring.isLoading, isTrue);
      expect(buttonWidgetDuring.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete async request
      completer.complete(AppResult.success(EmergencyIncident(
        id: 'INC_TEST_001',
        userId: 'test_user',
        category: EmergencyCategory.medical,
        intent: 'Ambulance',
        timestamp: DateTime.now(),
      )));
      await tester.pumpAndSettle();

      // Should have navigated to tracking screen
      expect(find.text('Tracking Screen: INC_TEST_001'), findsOneWidget);
    });

    testWidgets('b. Rapid repeated taps cannot create duplicate incidents (invoked only once)', (tester) async {
      final completer = Completer<AppResult<EmergencyIncident>>();
      mockEmergencyService.pendingCreateCompleter = completer;

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Select an option
      await tester.tap(find.text('Injury'));
      await tester.pumpAndSettle();

      final primaryButtonFinder = find.byType(PrimaryButton);

      // Rapidly tap the button 5 times in quick succession
      await tester.tap(primaryButtonFinder);
      await tester.tap(primaryButtonFinder, warnIfMissed: false);
      await tester.tap(primaryButtonFinder, warnIfMissed: false);
      await tester.tap(primaryButtonFinder, warnIfMissed: false);
      await tester.tap(primaryButtonFinder, warnIfMissed: false);
      await tester.pump();

      // Verify createIncident was called exactly ONCE
      expect(mockEmergencyService.createIncidentCallCount, equals(1));

      // Complete the request
      completer.complete(AppResult.success(EmergencyIncident(
        id: 'INC_SINGLE_001',
        userId: 'test_user',
        category: EmergencyCategory.medical,
        intent: 'Injury',
        timestamp: DateTime.now(),
      )));
      await tester.pumpAndSettle();

      expect(mockEmergencyService.createIncidentCallCount, equals(1));
      expect(find.text('Tracking Screen: INC_SINGLE_001'), findsOneWidget);
    });

    testWidgets('c. Submission becomes enabled again after API failure and shows error snackbar', (tester) async {
      mockEmergencyService.fixedResult = AppResult.failure('Backend server unreachable');

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Select an option
      await tester.tap(find.text('Ambulance'));
      await tester.pumpAndSettle();

      final primaryButtonFinder = find.byType(PrimaryButton);

      // Tap submit
      await tester.tap(primaryButtonFinder);
      await tester.pumpAndSettle(); // Pump through failure and snackbar

      // Verify error snackbar is displayed
      expect(find.text('Backend server unreachable'), findsOneWidget);

      // Verify button is re-enabled for retry
      final buttonWidgetAfter = tester.widget<PrimaryButton>(primaryButtonFinder);
      expect(buttonWidgetAfter.isLoading, isFalse);
      expect(buttonWidgetAfter.onPressed, isNotNull);

      // Dismiss snackbar so it doesn't block hits
      ScaffoldMessenger.of(tester.element(primaryButtonFinder)).hideCurrentSnackBar();
      await tester.pumpAndSettle();

      // Retry submission now with success
      mockEmergencyService.fixedResult = AppResult.success(EmergencyIncident(
        id: 'INC_RETRY_001',
        userId: 'test_user',
        category: EmergencyCategory.medical,
        intent: 'Ambulance',
        timestamp: DateTime.now(),
      ));

      await tester.tap(primaryButtonFinder);
      await tester.pumpAndSettle();

      expect(mockEmergencyService.createIncidentCallCount, equals(2));
      expect(find.text('Tracking Screen: INC_RETRY_001'), findsOneWidget);
    });

    testWidgets('d. Submission becomes enabled again after unexpected exception', (tester) async {
      mockEmergencyService.shouldThrowException = true;

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ambulance'));
      await tester.pumpAndSettle();

      final primaryButtonFinder = find.byType(PrimaryButton);
      await tester.tap(primaryButtonFinder);
      await tester.pumpAndSettle();

      // Error snackbar should be displayed
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Network socket crash'), findsOneWidget);

      // Button should be unlocked and re-enabled
      final buttonAfterException = tester.widget<PrimaryButton>(primaryButtonFinder);
      expect(buttonAfterException.isLoading, isFalse);
      expect(buttonAfterException.onPressed, isNotNull);
    });
  });
}
