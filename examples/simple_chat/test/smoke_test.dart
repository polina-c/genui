import 'package:flutter_test/flutter_test.dart';
import 'package:simple_chat/io_get_api_key.dart';
import 'package:simple_chat/main.dart';

void main() {
  testWidgets('Smoke test: App starts without issues', (
    WidgetTester tester,
  ) async {
    // Set a mock API key to avoid environment variable requirement
    debugApiKey = 'dummy_api_key';

    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the ChatScreen is displayed
    expect(find.byType(ChatScreen), findsOneWidget);

    // Clean up
    debugApiKey = null;
  });
}
