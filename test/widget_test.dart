import 'package:flutter_test/flutter_test.dart';
import 'package:f1_tracker/app.dart';

void main() {
  testWidgets('F1 Tracker home screen renders', (tester) async {
    await tester.pumpWidget(const F1TrackerApp());

    expect(find.text('F1 TRACKER'), findsOneWidget);
    expect(find.text('NEXT RACE'), findsOneWidget);
  });
}
