// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart' as firebase_ai;
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:genui_firebase_ai/genui_firebase_ai.dart';

void main() {
  group('GeminiContentConverter', () {
    late GeminiContentConverter converter;

    setUp(() {
      converter = GeminiContentConverter();
    });

    test('toFirebaseAiContent converts ChatMessage.user with TextPart', () {
      final messages = [ChatMessage.user('Hello')];
      final List<firebase_ai.Content> result = converter.toFirebaseAiContent(
        messages,
      );

      expect(result, hasLength(1));
      expect(result.first.role, 'user');
      expect(result.first.parts, hasLength(1));
      expect(result.first.parts.first, isA<firebase_ai.TextPart>());
      expect((result.first.parts.first as firebase_ai.TextPart).text, 'Hello');
    });

    test('toFirebaseAiContent converts ChatMessage.model with TextPart', () {
      final messages = [ChatMessage.model('Hi there')];
      final List<firebase_ai.Content> result = converter.toFirebaseAiContent(
        messages,
      );

      expect(result, hasLength(1));
      expect(result.first.role, 'model');
      expect(result.first.parts, hasLength(1));
      expect(result.first.parts.first, isA<firebase_ai.TextPart>());
      expect(
        (result.first.parts.first as firebase_ai.TextPart).text,
        'Hi there',
      );
    });

    test('toFirebaseAiContent converts UiPart to text description', () {
      final definition = UiDefinition(surfaceId: 'testSurface');
      final messages = [
        ChatMessage.model(
          '',
          parts: [
            UiPart.create(definition: definition, surfaceId: 'testSurface'),
          ],
        ),
      ];
      final List<firebase_ai.Content> result = converter.toFirebaseAiContent(
        messages,
      );
      expect(result, hasLength(1));
      expect(result.first.role, 'model');
      expect(result.first.parts, hasLength(1));
      expect(result.first.parts.first, isA<firebase_ai.TextPart>());
      expect(
        (result.first.parts.first as firebase_ai.TextPart).text,
        definition.asContextDescriptionText(),
      );
    });

    test('toFirebaseAiContent ignores ChatMessage.system', () {
      final messages = [ChatMessage.system('Thinking...')];
      final List<firebase_ai.Content> result = converter.toFirebaseAiContent(
        messages,
      );
      expect(result, isEmpty);
    });

    test('toFirebaseAiContent converts multi-part user message', () {
      final messages = [
        ChatMessage.user(
          '',
          parts: [
            const TextPart('Look at this image'),
            DataPart(Uint8List(0), mimeType: 'image/png'),
          ],
        ),
      ];
      final List<firebase_ai.Content> result = converter.toFirebaseAiContent(
        messages,
      );

      expect(result, hasLength(1));
      expect(result.first.role, 'user');
      expect(result.first.parts, hasLength(2));
      expect(result.first.parts[0], isA<firebase_ai.TextPart>());
      expect(result.first.parts[1], isA<firebase_ai.InlineDataPart>());
    });

    test('toFirebaseAiContent converts DataPart', () {
      final String data = jsonEncode({'key': 'value'});
      final messages = [
        ChatMessage.user(
          '',
          parts: [DataPart(utf8.encode(data), mimeType: 'application/json')],
        ),
      ];
      final List<firebase_ai.Content> result = converter.toFirebaseAiContent(
        messages,
      );
      final part = result.first.parts.first as firebase_ai.InlineDataPart;
      expect(part.mimeType, 'application/json');
      expect(utf8.decode(part.bytes), data);
    });

    test('toFirebaseAiContent converts DataPart (image)', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final messages = [
        ChatMessage.user('', parts: [DataPart(bytes, mimeType: 'image/jpeg')]),
      ];
      final List<firebase_ai.Content> result = converter.toFirebaseAiContent(
        messages,
      );
      final part = result.first.parts.first as firebase_ai.InlineDataPart;
      expect(part.mimeType, 'image/jpeg');
      expect(part.bytes, bytes);
    });

    test('toFirebaseAiContent converts LinkPart', () {
      final Uri url = Uri.parse('http://example.com/image.jpg');
      final messages = [
        ChatMessage.user('', parts: [LinkPart(url, mimeType: 'image/jpeg')]),
      ];
      final List<firebase_ai.Content> result = converter.toFirebaseAiContent(
        messages,
      );
      final part = result.first.parts.first as firebase_ai.TextPart;
      expect(part.text, 'Image at $url');
    });

    test('toFirebaseAiContent converts ToolCallPart', () {
      final messages = [
        ChatMessage.model(
          '',
          parts: [
            const ToolPart.call(
              callId: 'call1',
              toolName: 'doSomething',
              arguments: {'arg': 'value'},
            ),
          ],
        ),
      ];
      final List<firebase_ai.Content> result = converter.toFirebaseAiContent(
        messages,
      );
      final part = result.first.parts.first as firebase_ai.FunctionCall;
      expect(part.name, 'doSomething');
      expect(part.args, {'arg': 'value'});
    });

    test('toFirebaseAiContent converts ToolResultPart', () {
      final messages = [
        ChatMessage.user(
          '',
          parts: [
            const ToolPart.result(
              callId: 'call1',
              toolName: 'test',
              result: {'data': 'ok'},
            ),
          ],
        ),
      ];
      final List<firebase_ai.Content> result = converter.toFirebaseAiContent(
        messages,
      );
      expect(result.first.role, 'user');
      final part = result.first.parts.first as firebase_ai.FunctionResponse;
      expect(part.name, 'call1');
      expect(part.response, {'data': 'ok'});
    });

    test('toFirebaseAiContent converts ThinkingPart', () {
      final messages = [
        ChatMessage.model('', parts: [const ThinkingPart('working on it')]),
      ];
      final List<firebase_ai.Content> result = converter.toFirebaseAiContent(
        messages,
      );
      final part = result.first.parts.first as firebase_ai.TextPart;
      expect(part.text, 'Thinking: working on it');
    });

    test(
      'toFirebaseAiContent handles multiple messages of different types',
      () {
        final messages = <ChatMessage>[
          ChatMessage.user('First message'),
          ChatMessage.model('Second message'),
          ChatMessage.user('Third message'),
        ];
        final List<firebase_ai.Content> result = converter.toFirebaseAiContent(
          messages,
        );

        expect(result, hasLength(3));
        expect(result[0].role, 'user');
        expect(
          (result[0].parts.first as firebase_ai.TextPart).text,
          'First message',
        );
        expect(result[1].role, 'model');
        expect(
          (result[1].parts.first as firebase_ai.TextPart).text,
          'Second message',
        );
        expect(result[2].role, 'user');
        expect(
          (result[2].parts.first as firebase_ai.TextPart).text,
          'Third message',
        );
      },
    );
  });
}
