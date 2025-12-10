import 'package:flutter_test/flutter_test.dart';
import 'package:simple_chat/io_get_api_key.dart';
import 'package:simple_chat/main.dart';

void main() {
  setUpAll(() {
    debugApiKey = 'dummy_api_key';
  });

  tearDownAll(() {
    debugApiKey = null;
  });

  testWidgets('Smoke test: App starts without issues', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(ChatScreen), findsOneWidget);
  });
}
