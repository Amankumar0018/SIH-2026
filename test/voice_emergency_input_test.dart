import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pukaar/core/models/ai_intelligence.dart';
import 'package:pukaar/core/models/emergency_enums.dart';
import 'package:pukaar/core/models/emergency_incident.dart';
import 'package:pukaar/core/repositories/mock_emergency_repository.dart';
import 'package:pukaar/core/services/emergency_service.dart';
import 'package:pukaar/core/services/service_locator.dart';
import 'package:pukaar/core/utils/app_result.dart';
import 'package:pukaar/core/routing/app_routes.dart';
import 'package:pukaar/core/services/speech_service.dart';
import 'package:pukaar/features/emergency/presentation/screens/emergency_intent_screen.dart';
import 'package:pukaar/features/emergency/presentation/widgets/voice_emergency_input_card.dart';
import 'package:pukaar/features/home/presentation/screens/home_screen.dart';

class TestEmergencyService implements EmergencyService {
  final StreamController<EmergencyIncident> _controller =
      StreamController<EmergencyIncident>.broadcast();
  EmergencyIncident? _active;

  @override
  Stream<EmergencyIncident> get incidentStream => _controller.stream;

  @override
  EmergencyIncident? get activeIncident => _active;

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
    final incident = EmergencyIncident(
      id: 'INC_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId ?? 'guest_user',
      category: category,
      intent: intent,
      priority: priority,
      timestamp: DateTime.now(),
      notes: notes,
    );
    _active = incident;
    _controller.add(incident);
    return AppResult.success(incident);
  }

  @override
  Future<AppResult<EmergencyIncident>> getIncidentById(String incidentId) async =>
      _active != null ? AppResult.success(_active!) : AppResult.failure('Not found');

  @override
  Future<AppResult<List<EmergencyIncident>>> getActiveIncidents() async =>
      AppResult.success(_active != null ? [_active!] : []);

  @override
  Future<AppResult<List<EmergencyIncident>>> getAllIncidents() async =>
      AppResult.success(_active != null ? [_active!] : []);

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
  }) async {
    if (_active != null) {
      _active = _active!.copyWith(status: newStatus);
      _controller.add(_active!);
      return AppResult.success(_active!);
    }
    return AppResult.failure('Not found');
  }

  @override
  Future<AppResult<EmergencyIncident>> cancelIncident(String incidentId, {String? reason}) async {
    if (_active != null) {
      _active = _active!.copyWith(status: EmergencyStatus.cancelled);
      return AppResult.success(_active!);
    }
    return AppResult.failure('Not found');
  }

  @override
  void dispose() {
    _controller.close();
  }
}

void main() {
  late MockSpeechService mockSpeechService;
  late MockEmergencyRepository mockRepository;
  late TestEmergencyService testEmergencyService;

  setUp(() {
    mockSpeechService = MockSpeechService();
    mockRepository = MockEmergencyRepository();
    testEmergencyService = TestEmergencyService();

    ServiceLocator.instance.init(
      customSpeechService: mockSpeechService,
      customEmergencyRepository: mockRepository,
      customEmergencyService: testEmergencyService,
      useBackendApi: false,
    );
  });

  Widget createWidgetForTesting(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  group('Voice-to-Text Emergency Input Tests', () {
    // 1. Initial microphone control renders
    testWidgets('1. Initial microphone control renders with label "Describe what is happening"',
        (WidgetTester tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        createWidgetForTesting(
          VoiceEmergencyInputCard(controller: controller),
        ),
      );

      expect(find.text('Describe what is happening'), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    // 2. Speech recognition can populate the description field
    testWidgets('2. Speech recognition can populate the description field',
        (WidgetTester tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        createWidgetForTesting(
          VoiceEmergencyInputCard(controller: controller),
        ),
      );

      // Tap mic to start listening
      await tester.tap(find.byIcon(Icons.mic_rounded));
      await tester.pump(const Duration(milliseconds: 100));

      // Simulate spoken words
      mockSpeechService.emitWords(
        'There is a person unconscious near the main college gate and he is not responding.',
        isFinal: true,
      );
      await tester.pumpAndSettle();

      expect(controller.text,
          'There is a person unconscious near the main college gate and he is not responding.');
      expect(find.text('READY'), findsOneWidget);
    });

    // 3. Recognized transcript is editable
    testWidgets('3. Recognized transcript is editable by citizen',
        (WidgetTester tester) async {
      final controller = TextEditingController(text: 'Person unconscious');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        createWidgetForTesting(
          VoiceEmergencyInputCard(controller: controller),
        ),
      );

      expect(find.text('Person unconscious'), findsOneWidget);

      // Manually edit the text
      await tester.enterText(
        find.byType(TextField),
        'Person unconscious near gate 2, bleeding from forehead',
      );
      await tester.pumpAndSettle();

      expect(controller.text, 'Person unconscious near gate 2, bleeding from forehead');
    });

    // 4. Empty transcript does not submit invalid data
    testWidgets('4. Empty transcript does not submit invalid data without category intent',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: EmergencyIntentScreen(category: 'Medical Emergency'),
        ),
      );

      // Confirm button should be disabled when neither option nor voice notes exist
      final buttonFinder = find.widgetWithText(ElevatedButton, 'Confirm Emergency Request');
      expect(buttonFinder, findsOneWidget);

      final ElevatedButton button = tester.widget(buttonFinder);
      expect(button.onPressed, isNull);
    });

    // 5. Permission denied does not crash the app
    testWidgets('5. Permission denied displays clear guidance and does not crash the app',
        (WidgetTester tester) async {
      mockSpeechService.simulatePermissionDenied = true;
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        createWidgetForTesting(
          VoiceEmergencyInputCard(controller: controller),
        ),
      );

      // Tap mic
      await tester.tap(find.byIcon(Icons.mic_rounded));
      await tester.pumpAndSettle();

      expect(find.text('NO MIC PERMISSION'), findsOneWidget);
      expect(find.text('Microphone permission is required for voice input.'), findsOneWidget);
      // Manual input remains available
      expect(find.byType(TextField), findsOneWidget);
    });

    // 6. Speech recognition failure falls back to manual input
    testWidgets('6. Speech recognition failure falls back safely to manual input',
        (WidgetTester tester) async {
      mockSpeechService.simulateInitError = true;
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        createWidgetForTesting(
          VoiceEmergencyInputCard(controller: controller),
        ),
      );

      await tester.tap(find.byIcon(Icons.mic_rounded));
      await tester.pumpAndSettle();

      expect(find.text('ERROR'), findsOneWidget);
      expect(find.text('Voice recognition error. You can type manually.'), findsOneWidget);

      // Citizen types manually despite error
      await tester.enterText(find.byType(TextField), 'Manual emergency report');
      await tester.pumpAndSettle();

      expect(controller.text, 'Manual emergency report');
    });

    // 7. Existing incident creation still works without voice input
    testWidgets('7. Existing incident creation still works without voice input',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          routes: {
            AppRoutes.emergencyTracking: (_) => const Scaffold(body: Text('Tracking Screen')),
          },
          home: const EmergencyIntentScreen(category: 'Medical Emergency'),
        ),
      );

      // Select 'Ambulance' intent
      await tester.ensureVisible(find.text('Ambulance'));
      await tester.tap(find.text('Ambulance'));
      await tester.pumpAndSettle();

      // Submit
      final buttonFinder = find.widgetWithText(ElevatedButton, 'Confirm Emergency Request');
      final ElevatedButton button = tester.widget(buttonFinder);
      expect(button.onPressed, isNotNull);

      await tester.ensureVisible(buttonFinder);
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      final active = testEmergencyService.activeIncident;
      expect(active, isNotNull);
      expect(active!.category, EmergencyCategory.medical);
      expect(active.intent, 'Ambulance');
      expect(active.notes, isNull);
    });

    // 8. Transcript is included in the existing incident creation payload
    testWidgets('8. Transcript is included in the existing incident creation payload (notes)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          routes: {
            AppRoutes.emergencyTracking: (_) => const Scaffold(body: Text('Tracking Screen')),
          },
          home: const EmergencyIntentScreen(category: 'Medical Emergency'),
        ),
      );

      // Enter voice transcript
      await tester.enterText(
        find.byType(TextField),
        'There is a person unconscious near the main college gate and he is not responding.',
      );
      await tester.pumpAndSettle();

      // Select option
      await tester.ensureVisible(find.text('Unconscious Person'));
      await tester.tap(find.text('Unconscious Person'));
      await tester.pumpAndSettle();

      // Submit
      final buttonFinder = find.widgetWithText(ElevatedButton, 'Confirm Emergency Request');
      await tester.ensureVisible(buttonFinder);
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      final active = testEmergencyService.activeIncident;
      expect(active, isNotNull);
      expect(active!.category, EmergencyCategory.medical);
      expect(active.intent, 'Unconscious Person');
      expect(active.notes,
          'There is a person unconscious near the main college gate and he is not responding.');
    });

    // 9. AI Incident Intelligence can receive transcript text through existing notes field
    test('9. AI Incident Intelligence can receive transcript text through notes field', () {
      final transcript =
          'There is a person unconscious near the main college gate and he is not responding.';

      final ai = AIIntelligence(
        summary: 'Medical emergency: Unconscious Person near main college gate.',
        urgencyScore: 'CRITICAL',
        hazards: ['Unconscious patient — airway obstruction hazard'],
        recommendedActions: [
          'Dispatch nearest Advanced Life Support unit',
          'Verify patient airway and responsiveness',
        ],
        missingInfo: ['Exact floor/indoor room', 'Breathing status'],
        source: 'rule_based',
        confidence: 0.85,
        generatedAt: DateTime.now(),
      );

      final incident = EmergencyIncident(
        id: 'INC_TEST_VOICE_001',
        userId: '9876543210',
        category: EmergencyCategory.medical,
        intent: 'Unconscious Person',
        timestamp: DateTime.now(),
        notes: transcript,
        aiIntelligence: ai,
      );

      final json = incident.toJson();
      expect(json['notes'], transcript);
      expect(json['aiIntelligence'], isNotNull);
      expect(json['aiIntelligence']['urgencyScore'], 'CRITICAL');
      expect(json['aiIntelligence']['hazards'],
          contains('Unconscious patient — airway obstruction hazard'));

      final fromJson = EmergencyIncident.fromJson(json);
      expect(fromJson.notes, transcript);
      expect(fromJson.aiIntelligence?.urgencyScore, 'CRITICAL');
    });

    // 10. Existing WebSocket / realtime behavior remains unchanged
    test('10. Existing WebSocket / realtime incident stream preserves transcript notes', () async {
      final incidentCreated = EmergencyIncident(
        id: 'INC_WS_TEST_001',
        userId: '9876543210',
        category: EmergencyCategory.medical,
        intent: 'Unconscious Person',
        timestamp: DateTime.now(),
        notes: 'Unconscious citizen at library steps',
        aiIntelligence: AIIntelligence(
          summary: 'Medical alert',
          urgencyScore: 'CRITICAL',
          hazards: const ['Airway hazard'],
          recommendedActions: const ['ALS dispatch'],
          missingInfo: const [],
          source: 'rule_based',
          confidence: 0.85,
          generatedAt: DateTime.parse('2026-09-09T08:00:00Z'),
        ),
      );

      final streamFuture = mockRepository.incidentStream.first;
      await mockRepository.createIncident(incidentCreated);

      final received = await streamFuture;
      expect(received.id, 'INC_WS_TEST_001');
      expect(received.notes, 'Unconscious citizen at library steps');
      expect(received.aiIntelligence?.urgencyScore, 'CRITICAL');
    });

    // Extra: HomeScreen Voice Emergency Section renders and allows voice dispatch
    testWidgets('HomeScreen renders Voice Emergency Assistant and supports voice dispatch',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Describe what is happening'), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);

      // Enter voice transcript on HomeScreen
      await tester.enterText(
        find.byType(TextField),
        'Person unconscious near the main college gate',
      );
      await tester.pumpAndSettle();

      // Triage Category chips and Submit button should appear
      expect(find.text('Triage Category:'), findsOneWidget);
      expect(find.text('Broadcast Emergency with Voice Notes'), findsOneWidget);
    });
  });
}
