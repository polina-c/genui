// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dartantic_ai/dartantic_ai.dart' as dartantic;
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_primitives/genai_primitives.dart';
import 'package:genui/genui.dart' as genui; // Exports ChatMessage too? verify
import 'package:genui/src/model/parts/ui.dart'; // Explicit import if needed for UiPart extension visibility
import 'package:genui_dartantic/genui_dartantic.dart';

void main() {
  group('DartanticContentConverter', () {
    late DartanticContentConverter converter;

    setUp(() {
      converter = DartanticContentConverter();
    });

    group('toPromptAndParts', () {
      test('converts UserMessage with text to prompt string', () {
        final message = ChatMessage.user('Hello, world!');

        final ({String prompt, List<dartantic.Part> parts}) result = converter
            .toPromptAndParts(message);

        expect(result.prompt, 'Hello, world!');
        expect(result.parts, isEmpty);
      });

      test('converts UserMessage with multiple text parts', () {
        final message = ChatMessage.user(
          '',
          parts: [const TextPart('First part'), const TextPart('Second part')],
        );

        final ({List<dartantic.Part> parts, String prompt}) result = converter
            .toPromptAndParts(message);

        expect(result.prompt, 'First part\nSecond part');
        expect(result.parts, isEmpty);
      });

      test('converts UserUiInteractionMessage to prompt string/part', () {
        final message = ChatMessage.user(
          '',
          parts: [
            UiInteractionPart.create(jsonEncode({'action': 'click'})),
          ],
        );

        final ({List<dartantic.Part> parts, String prompt}) result = converter
            .toPromptAndParts(message);

        // converter _extractText skips UiInteractionPart unless specialized. It
        // converts it to DataPart in _toParts. So prompt should be empty (or
        // just generic text if any), parts should contain JSON data.
        expect(result.prompt, isEmpty);
        expect(result.parts, hasLength(1));
        expect(result.parts.first, isA<dartantic.DataPart>());
        // Verify content
        final dataPart = result.parts.first as dartantic.DataPart;
        expect(dataPart.mimeType, 'application/json');
        final String content = utf8.decode(dataPart.bytes);
        expect(content, contains('click'));
      });

      test('converts AiTextMessage to prompt string', () {
        final message = ChatMessage.model('AI response');

        final ({List<dartantic.Part> parts, String prompt}) result = converter
            .toPromptAndParts(message);

        expect(result.prompt, 'AI response');
      });

      test('converts InternalMessage to prompt string', () {
        final message = ChatMessage.system('System instruction');

        final ({List<dartantic.Part> parts, String prompt}) result = converter
            .toPromptAndParts(message);

        expect(result.prompt, 'System instruction');
        expect(result.parts, isEmpty);
      });

      test('handles ToolResponseMessage', () {
        final message = ChatMessage.user(
          '',
          parts: [
            const ToolPart.result(
              callId: 'call1',
              toolName: 'test',
              result: '{"status": "ok"}',
            ),
          ],
        );

        final ({List<dartantic.Part> parts, String prompt}) result = converter
            .toPromptAndParts(message);

        expect(result.prompt, contains('ToolResult(call1)'));
        expect(result.parts, isNotEmpty);
      });

      test('handles DataPart in message', () {
        final message = ChatMessage.user(
          'Check this data:',
          parts: [
            DataPart(
              utf8.encode('{"key": "value"}'),
              mimeType: 'application/json',
            ),
          ],
        );

        final ({List<dartantic.Part> parts, String prompt}) result = converter
            .toPromptAndParts(message);

        expect(result.prompt, contains('Check this data:'));
        expect(result.parts.whereType<dartantic.DataPart>(), hasLength(1));
      });

      test('handles Image via DataPart in message', () {
        final message = ChatMessage.user(
          'Look at this image:',
          parts: [DataPart(Uint8List(0), mimeType: 'image/png')],
        );

        final ({List<dartantic.Part> parts, String prompt}) result = converter
            .toPromptAndParts(message);

        expect(result.prompt, contains('Look at this image:'));
        // DataPart with image mimeType
        expect(result.parts.whereType<dartantic.DataPart>(), isNotEmpty);
      });

      test('handles LinkPart in message', () {
        final message = ChatMessage.user(
          'Look at this link:',
          parts: [
            LinkPart(
              Uri.parse('https://example.com/image.png'),
              mimeType: 'image/png',
            ),
          ],
        );

        final ({List<dartantic.Part> parts, String prompt}) result = converter
            .toPromptAndParts(message);

        expect(result.parts.whereType<dartantic.LinkPart>(), isNotEmpty);
      });

      test('handles ThinkingPart in message', () {
        final message = ChatMessage.model(
          '',
          parts: [
            const ThinkingPart('Let me think about this...'),
            const TextPart('Here is my answer.'),
          ],
        );

        final ({List<dartantic.Part> parts, String prompt}) result = converter
            .toPromptAndParts(message);

        expect(result.prompt, contains('Thinking: Let me think about this...'));
        expect(result.prompt, contains('Here is my answer.'));
      });

      test('includes ToolCallPart', () {
        final message = ChatMessage.model(
          '',
          parts: [
            const TextPart('Calling a tool'),
            const ToolPart.call(
              callId: 'call1',
              toolName: 'test_tool',
              arguments: {'arg': 'value'},
            ),
          ],
        );

        final ({List<dartantic.Part> parts, String prompt}) result = converter
            .toPromptAndParts(message);

        expect(result.prompt, contains('ToolCall(test_tool)'));
        expect(result.parts.whereType<dartantic.ToolPart>(), isNotEmpty);
      });
    });

    group('toHistory', () {
      test('converts user message to user role', () {
        final history = [ChatMessage.user('Hello')];

        final List<dartantic.ChatMessage> result = converter.toHistory(
          history.cast<genui.ChatMessage>(),
        );

        expect(result, hasLength(1));
        expect(result[0].role, dartantic.ChatMessageRole.user);
        expect(result[0].text, 'Hello');
      });

      test('converts model message to model role', () {
        final history = [ChatMessage.model('AI response')];

        final List<dartantic.ChatMessage> result = converter.toHistory(
          history.cast<genui.ChatMessage>(),
        );

        expect(result, hasLength(1));
        expect(result[0].role, dartantic.ChatMessageRole.model);
        expect(result[0].text, 'AI response');
      });

      test('includes system message', () {
        final history = [
          ChatMessage.user('Hello'),
          ChatMessage.system('Internal note'),
          ChatMessage.model('Response'),
        ];

        final List<dartantic.ChatMessage> result = converter.toHistory(
          history.cast<genui.ChatMessage>(),
        );

        expect(result, hasLength(3));
        expect(result[0].role, dartantic.ChatMessageRole.user);
        expect(result[1].role, dartantic.ChatMessageRole.system);
        expect(result[2].role, dartantic.ChatMessageRole.model);
      });
    });
  });
}
