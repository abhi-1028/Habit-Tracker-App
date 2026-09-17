import 'package:flutter_test/flutter_test.dart';

import 'package:habit_tracker/main.dart';

void main() {
  testWidgets('Habit Tracker app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const HabitTrackerApp());

    await tester.pumpAndSettle();

    expect(find.text('Habit Tracker'), findsOneWidget);
  });
}