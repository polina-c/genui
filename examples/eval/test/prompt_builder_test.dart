// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';

import 'test_infra/ai_client.dart';

void main() {
  test('test can talk with AI', () async {
    final aiClient = DartanticAiClient();
    addTearDown(aiClient.dispose);

    final String result = await aiClient
        .sendStream('Please, tell me a joke.', history: [])
        .first;
    expect(result, isNotEmpty);
    print('Result: $result');
  });
}
