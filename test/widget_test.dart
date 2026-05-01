import 'package:flutter_test/flutter_test.dart';
import 'package:dog_tracker/main.dart';

void main() {
  testWidgets('Dog Growth Tracker UI smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const DogGrowthTrackerApp(isLoggedIn: true));

    // Verify that our welcome text is present.
    expect(find.text('Welcome Back!'), findsOneWidget);
    expect(find.text('Health Tools'), findsOneWidget);
  });
}
