import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/main.dart';

void main() {
  testWidgets('Habit Tracker starts with dashboard', (tester) async {
    await tester.pumpWidget(const HabitTrackerApp());
    await tester.pumpAndSettle();
    expect(find.text('Good day 👋'), findsOneWidget);
    expect(find.text("Today's habits"), findsOneWidget);
    expect(find.text('Wake up at 05:00'), findsOneWidget);
  });

  testWidgets('Bottom navigation switches to analytics', (tester) async {
    await tester.pumpWidget(const HabitTrackerApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stats'));
    await tester.pumpAndSettle();
    expect(find.text('Analytics'), findsOneWidget);
    expect(find.text('Weekly Progress'), findsOneWidget);
  });
}
