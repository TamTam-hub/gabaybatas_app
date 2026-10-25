import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gabaybatas_app/features/info/presentation/report_guide_page.dart';

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.drag(find.byType(ListView), const Offset(0, -600));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> _answerUpToVenue(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: ReportGuidePage()));
  await _tap(tester, 'No'); // danger
  await _tap(tester, 'No'); // VAWC
  await _tap(tester, 'No, a private person');
  await _tap(tester, 'No, it is something else');
  await _tap(tester, 'No'); // online
  await _tap(tester, 'Yes'); // Catbalogan City
  await _tap(tester, 'No, it is a dispute or minor offense');
  expect(find.text('Does the other person live in Barangay Muñoz?'), findsOneWidget);
}

void main() {
  testWidgets('respondent in another barangay is sent to that barangay', (tester) async {
    await _answerUpToVenue(tester);
    await _tap(tester, 'No, they live in another barangay');
    expect(find.text('The barangay where the other person lives'), findsOneWidget);
    expect(find.text('Submit a Case'), findsNothing);
  });

  testWidgets('land in Barangay Muñoz can be filed here', (tester) async {
    await _answerUpToVenue(tester);
    await _tap(tester, 'No, but it is about land located in Barangay Muñoz');
    expect(find.text('Barangay Muñoz — Lupong Tagapamayapa'), findsOneWidget);
    expect(find.text('Submit a Case'), findsOneWidget);
  });
}
