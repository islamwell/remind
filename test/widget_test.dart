import 'package:flutter_test/flutter_test.dart';
import 'package:good_deeds_reminder/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(GoodDeedsReminderApp());

    // Verify that the app launches
    expect(find.text('Reminders'), findsOneWidget);
  });
}
