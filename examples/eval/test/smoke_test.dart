import 'package:flutter_test/flutter_test.dart';

import 'test_infra/io_get_api_key.dart';

void main() {
  test('smoke test', () {
    final String key = apiKey();
    expect(key, isNotEmpty);
  });
}
