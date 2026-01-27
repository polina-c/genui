// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:dartantic_ai/dartantic_ai.dart' as dartantic;
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart' as genui;
import 'package:genui_dartantic/genui_dartantic.dart';

void main() {
  group('DartanticClient', () {
    // Use the ollama provider for testing - it doesn't require API keys
    // Note: These tests only verify object construction, not actual AI calls
    late dartantic.OllamaProvider testProvider;

    setUp(() {
      testProvider = dartantic.OllamaProvider();
    });

    group('construction', () {
      test('creates client with required parameters', () {
        final client = DartanticClient(
          provider: testProvider,
          catalog: const genui.Catalog({}),
        );

        expect(client, isNotNull);
        expect(client.catalog, isNotNull);
        expect(client.isProcessing.value, isFalse);

        client.dispose();
      });

      test('creates client with all optional parameters', () {
        final client = DartanticClient(
          provider: testProvider,
          catalog: const genui.Catalog({}),
          systemInstruction: 'You are a helpful assistant.',
          additionalTools: [
            genui.DynamicAiTool<Map<String, Object?>>(
              name: 'testTool',
              description: 'A test tool',
              invokeFunction: (args) async => {'result': 'ok'},
            ),
          ],
        );

        expect(client, isNotNull);
        expect(client.systemInstruction, 'You are a helpful assistant.');

        client.dispose();
      });
    });

    group('streams', () {
      test('provides a2uiMessageStream', () {
        final client = DartanticClient(
          provider: testProvider,
          catalog: const genui.Catalog({}),
        );

        expect(client.a2uiMessageStream, isA<Stream<genui.A2uiMessage>>());

        client.dispose();
      });

      test('provides textResponseStream', () {
        final client = DartanticClient(
          provider: testProvider,
          catalog: const genui.Catalog({}),
        );

        expect(client.textResponseStream, isA<Stream<String>>());

        client.dispose();
      });

      test('provides errorStream', () {
        final client = DartanticClient(
          provider: testProvider,
          catalog: const genui.Catalog({}),
        );

        expect(client.errorStream, isA<Stream<Object>>());

        client.dispose();
      });
    });

    group('isProcessing', () {
      test('initially false', () {
        final client = DartanticClient(
          provider: testProvider,
          catalog: const genui.Catalog({}),
        );

        expect(client.isProcessing.value, isFalse);

        client.dispose();
      });
    });
  });
}
