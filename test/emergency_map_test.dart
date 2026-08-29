import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pukaar/core/widgets/emergency_map.dart';

void main() {
  Widget createTestWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  testWidgets('EmergencyMap displays fallback text when coordinates are null', (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget(
      const EmergencyMap(
        latitude: null,
        longitude: null,
      ),
    ));

    expect(find.text('Location Coordinates Unavailable'), findsOneWidget);
  });

  testWidgets('EmergencyMap displays fallback text when coordinates are out of bounds', (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget(
      const EmergencyMap(
        latitude: 100.0, // Invalid latitude (> 90)
        longitude: 200.0, // Invalid longitude (> 180)
      ),
    ));

    expect(find.text('Location Coordinates Unavailable'), findsOneWidget);
  });

  testWidgets('EmergencyMap renders FlutterMap when valid coordinates provided', (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget(
      const EmergencyMap(
        latitude: 28.6139,
        longitude: 77.2090,
        title: 'Test Location',
      ),
    ));

    expect(find.text('Test Location'), findsOneWidget);
    expect(find.byIcon(Icons.location_on), findsOneWidget);
  });

  testWidgets('EmergencyMap renders responder pin indicator when responder coordinates provided', (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget(
      const EmergencyMap(
        latitude: 28.6139,
        longitude: 77.2090,
        responderLatitude: 28.6150,
        responderLongitude: 77.2100,
        title: 'Test Location with Responder',
      ),
    ));

    expect(find.text('Responder Pin Active'), findsOneWidget);
    expect(find.byIcon(Icons.local_shipping), findsWidgets);
  });
}
