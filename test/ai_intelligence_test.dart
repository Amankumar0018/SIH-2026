import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pukaar/core/models/ai_intelligence.dart';
import 'package:pukaar/core/models/emergency_enums.dart';
import 'package:pukaar/core/models/emergency_incident.dart';
import 'package:pukaar/features/responder/presentation/widgets/ai_incident_card.dart';

void main() {
  group('AIIntelligence Model Tests', () {
    test('serializes and deserializes AIIntelligence correctly', () {
      final now = DateTime.now();
      final ai = AIIntelligence(
        summary: 'Suspected cardiac arrest. Immediate paramedic response required.',
        urgencyScore: 'CRITICAL',
        hazards: const ['Airway compromise', 'Cardiac arrest'],
        recommendedActions: const [
          'Dispatch ALS ambulance',
          'Prepare AED',
          'Verify patient consciousness',
        ],
        missingInfo: const ['Patient pulse rate', 'Building floor'],
        source: 'rule_based',
        confidence: 0.85,
        generatedAt: now,
      );

      final jsonMap = ai.toJson();
      expect(jsonMap['summary'], ai.summary);
      expect(jsonMap['urgencyScore'], 'CRITICAL');
      expect(jsonMap['hazards'], ai.hazards);
      expect(jsonMap['recommendedActions'], ai.recommendedActions);
      expect(jsonMap['missingInfo'], ai.missingInfo);
      expect(jsonMap['source'], 'rule_based');
      expect(jsonMap['confidence'], 0.85);

      final deserialized = AIIntelligence.fromJson(jsonMap);
      expect(deserialized.summary, ai.summary);
      expect(deserialized.urgencyScore, 'CRITICAL');
      expect(deserialized.hazards.length, 2);
      expect(deserialized.recommendedActions.length, 3);
      expect(deserialized.missingInfo.length, 2);
      expect(deserialized.isLlm, false);
      expect(deserialized.confidence, 0.85);
    });

    test('handles empty and partial JSON maps gracefully', () {
      final ai = AIIntelligence.fromJson({});
      expect(ai.summary, '');
      expect(ai.urgencyScore, 'HIGH');
      expect(ai.hazards, isEmpty);
      expect(ai.recommendedActions, isEmpty);
      expect(ai.missingInfo, isEmpty);
      expect(ai.confidence, 0.5);
      expect(ai.source, 'rule_based');
    });

    test('EmergencyIncident handles null and populated aiIntelligence correctly', () {
      final incidentWithoutAi = EmergencyIncident(
        id: 'INC_TEST_001',
        userId: '9876543210',
        category: EmergencyCategory.medical,
        intent: 'Ambulance',
        timestamp: DateTime.now(),
      );

      final jsonWithoutAi = incidentWithoutAi.toJson();
      expect(jsonWithoutAi.containsKey('aiIntelligence'), isFalse);

      final parsedWithoutAi = EmergencyIncident.fromJson(jsonWithoutAi);
      expect(parsedWithoutAi.aiIntelligence, isNull);

      final incidentWithAi = incidentWithoutAi.copyWith(
        aiIntelligence: const AIIntelligence(
          summary: 'Medical emergency',
          urgencyScore: 'HIGH',
          hazards: ['Trauma'],
          source: 'llm',
        ),
      );

      final jsonWithAi = incidentWithAi.toJson();
      expect(jsonWithAi.containsKey('aiIntelligence'), isTrue);
      expect(jsonWithAi['aiIntelligence']['source'], 'llm');

      final parsedWithAi = EmergencyIncident.fromJson(jsonWithAi);
      expect(parsedWithAi.aiIntelligence, isNotNull);
      expect(parsedWithAi.aiIntelligence!.isLlm, isTrue);
      expect(parsedWithAi.aiIntelligence!.hazards, contains('Trauma'));
    });

    test('simulates parsing incoming WebSocket incident frame with AI payload', () {
      const rawWsMessage = '''
      {
        "type": "incident.created",
        "incident": {
          "id": "INC_12345_MEDICAL",
          "userId": "9876543210",
          "category": "medical",
          "intent": "Cardiac arrest",
          "priority": "critical",
          "status": "created",
          "timestamp": "2026-09-09T01:00:00Z",
          "aiIntelligence": {
            "summary": "High urgency cardiac emergency.",
            "urgencyScore": "CRITICAL",
            "hazards": ["Cardiac compromise"],
            "recommendedActions": ["Prepare defibrillator", "Maintain airway"],
            "missingInfo": ["Current breathing state"],
            "source": "rule_based",
            "confidence": 0.85
          }
        }
      }
      ''';

      final decoded = json.decode(rawWsMessage) as Map<String, dynamic>;
      final rawIncident = decoded['incident'] as Map<String, dynamic>;
      final incident = EmergencyIncident.fromJson(rawIncident);

      expect(incident.id, 'INC_12345_MEDICAL');
      expect(incident.priority, EmergencyPriority.critical);
      expect(incident.aiIntelligence, isNotNull);
      expect(incident.aiIntelligence!.urgencyScore, 'CRITICAL');
      expect(incident.aiIntelligence!.hazards, contains('Cardiac compromise'));
      expect(incident.aiIntelligence!.recommendedActions.length, 2);
    });
  });

  group('AIIncidentCard Widget Tests', () {
    testWidgets('renders AIIncidentCard with summary, disclaimer, and tags', (tester) async {
      const intelligence = AIIntelligence(
        summary: 'Emergency safety escort required for vulnerable citizen.',
        urgencyScore: 'HIGH',
        hazards: ['Low visibility area', 'Single individual isolated'],
        recommendedActions: [
          'Dispatch rapid patrol unit',
          'Maintain live contact',
        ],
        missingInfo: ['Exact gate number'],
        source: 'rule_based',
        confidence: 0.80,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AIIncidentCard(intelligence: intelligence),
            ),
          ),
        ),
      );

      // Verify title bar
      expect(find.text('AI INCIDENT INTELLIGENCE'), findsOneWidget);
      expect(find.text('HIGH'), findsOneWidget);

      // Verify mandatory disclaimer
      expect(find.text('AI Advisory — Verify before action'), findsOneWidget);

      // Verify summary
      expect(find.text('Emergency safety escort required for vulnerable citizen.'), findsOneWidget);

      // Verify hazards
      expect(find.text('Low visibility area'), findsOneWidget);
      expect(find.text('Single individual isolated'), findsOneWidget);

      // Verify actions
      expect(find.text('Dispatch rapid patrol unit'), findsOneWidget);
      expect(find.text('Maintain live contact'), findsOneWidget);

      // Verify missing info
      expect(find.text('Exact gate number'), findsOneWidget);
    });

    testWidgets('collapses and expands on header tap', (tester) async {
      const intelligence = AIIntelligence(
        summary: 'Test summary content',
        urgencyScore: 'MEDIUM',
        hazards: ['Hazard 1'],
        source: 'llm',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AIIncidentCard(intelligence: intelligence),
          ),
        ),
      );

      // Initially expanded
      expect(find.text('Test summary content'), findsOneWidget);

      // Tap header to collapse
      await tester.tap(find.text('AI INCIDENT INTELLIGENCE'));
      await tester.pumpAndSettle();

      // Content should be hidden
      expect(find.text('Test summary content'), findsNothing);

      // Tap header to expand again
      await tester.tap(find.text('AI INCIDENT INTELLIGENCE'));
      await tester.pumpAndSettle();

      // Content should be visible again
      expect(find.text('Test summary content'), findsOneWidget);
    });
  });
}
