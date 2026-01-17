// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:dartantic_ai/dartantic_ai.dart' as dartantic;
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart' as genui;
import 'package:genui_dartantic/genui_dartantic.dart';

void main() {
  group('DartanticContentConverter', () {
    late DartanticContentConverter converter;

    setUp(() {
      converter = DartanticContentConverter();
    });

    group('toPromptAndParts', () {
      test('converts UserMessage with text to prompt string', () {
        final message = genui.ChatMessage.user('Hello, world!');

        final ({String prompt, List<dartantic.Part> parts}) result = converter
            .toPromptAndParts(message);

        expect(result.prompt, 'Hello, world!');
        // Text parts are excluded from parts to avoid duplication (text is in
        // prompt)
        expect(result.parts, isEmpty);
      });

      test('converts UserMessage with multiple text parts', () {
        final message = genui.ChatMessage.user(
          'First part',
          parts: [const genui.TextPart('Second part')],
        );

        final ({String prompt, List<dartantic.Part> parts}) result = converter
            .toPromptAndParts(message);

        expect(result.prompt, 'First part\nSecond part');
        // Text parts are excluded from parts to avoid duplication (text is in
        // prompt)
        expect(result.parts, isEmpty);
      });

      test('converts UserUiInteractionMessage to prompt string', () {
        final message = genui.ChatMessage.user(
          '',
          parts: [const genui.UiInteractionPart('UI interaction')],
        );
        // Note: Logic converts UiInteractionPart to string in extractText

        final ({String prompt, List<dartantic.Part> parts}) result = converter
            .toPromptAndParts(message);

        expect(result.prompt, 'UI interaction');
      });

      test('converts AiTextMessage to prompt string', () {
        final message = genui.ChatMessage.model('AI response');

        final ({String prompt, List<dartantic.Part> parts}) result = converter
            .toPromptAndParts(message);

        expect(result.prompt, 'AI response');
      });

      test('converts InternalMessage to prompt string', () {
        final message = genui.ChatMessage.system('System instruction');

        final ({String prompt, List<dartantic.Part> parts}) result = converter
            .toPromptAndParts(message);

        expect(result.prompt, 'System instruction');
        // InternalMessage returns empty parts (text is in prompt only)
        expect(result.parts, isEmpty);
      });

      test('handles ToolResponseMessage', () {
        final message = genui.ChatMessage.user(
          '',
          parts: [
            const genui.ToolPart.result(
              callId: 'call1',
              toolName: 'toolName',
              result: '{"status": "ok"}',
            ),
          ],
        );

        final ({String prompt, List<dartantic.Part> parts}) result = converter
            .toPromptAndParts(message);

        expect(result.prompt, contains('ToolResult(call1)'));
        expect(result.parts, isNotEmpty);
      });

      test('handles ImagePart with URL in message', () {
        final message = genui.ChatMessage.user(
          'Look at this image:',
          parts: [
            genui.ImagePart.fromUrl(
              Uri.parse('https://example.com/image.png'),
              mimeType: 'image/png',
            ),
          ],
        );

        final ({String prompt, List<dartantic.Part> parts}) result = converter
            .toPromptAndParts(message);

        expect(result.prompt, contains('Look at this image:'));
        expect(
          result.prompt,
          contains('Image at https://example.com/image.png'),
        );
        expect(result.parts.whereType<dartantic.LinkPart>(), isNotEmpty);
      });

      test('handles ThinkingPart in message', () {
        final message = genui.ChatMessage.model(
          'Here is my answer.',
          parts: [const genui.ThinkingPart('Let me think about this...')],
        );

        final ({String prompt, List<dartantic.Part> parts}) result = converter
            .toPromptAndParts(message);

        expect(result.prompt, contains('Thinking: Let me think about this...'));
        expect(result.prompt, contains('Here is my answer.'));
      });

      test('includes ToolCallPart in prompt', () {
        final message = genui.ChatMessage.model(
          'Calling a tool',
          parts: [
            const genui.ToolPart.call(
              callId: 'call1',
              toolName: 'test_tool',
              arguments: {'arg': 'value'},
            ),
          ],
        );

        final ({String prompt, List<dartantic.Part> parts}) result = converter
            .toPromptAndParts(message);

        expect(result.prompt, contains('ToolCall(test_tool)'));
        expect(result.parts.whereType<dartantic.ToolPart>(), isNotEmpty);
      });

      test('includes ToolResultPart in prompt', () {
        final message = genui.ChatMessage.model(
          'Got result',
          parts: [
            const genui.ToolPart.result(
              callId: 'call1',
              toolName: 't',
              result: '{}',
            ),
          ],
        );

        final ({String prompt, List<dartantic.Part> parts}) result = converter
            .toPromptAndParts(message);

        expect(result.prompt, contains('ToolResult(call1)'));
        expect(result.parts.whereType<dartantic.ToolPart>(), isNotEmpty);
      });

      test('handles empty message parts', () {
        final message = genui.ChatMessage.user(''); // Empty text part

        final ({String prompt, List<dartantic.Part> parts}) result = converter
            .toPromptAndParts(message);

        expect(result.prompt, '');
      });
    });

    group('toHistory', () {
      test('returns empty list for null history', () {
        final result = converter.toHistory(null);

        expect(result, isEmpty);
      });

      test('returns empty list for empty history', () {
        final result = converter.toHistory([]);

        expect(result, isEmpty);
      });

      test('includes system instruction as first message', () {
        final result = converter.toHistory(
          null,
          systemInstruction: 'You are a helpful assistant.',
        );

        expect(result, hasLength(1));
        expect(result[0].role, dartantic.ChatMessageRole.system);
        expect(result[0].text, 'You are a helpful assistant.');
      });

      test('converts UserMessage to user role', () {
        final history = [genui.ChatMessage.user('Hello')];

        final result = converter.toHistory(history);

        expect(result, hasLength(1));
        expect(result[0].role, dartantic.ChatMessageRole.user);
        expect(result[0].text, 'Hello');
      });

      test('converts UserUiInteractionMessage to user role', () {
        final history = [
          genui.ChatMessage.user(
            '',
            parts: [const genui.UiInteractionPart('Clicked button')],
          ),
        ];

        final result = converter.toHistory(history);

        expect(result, hasLength(1));
        expect(result[0].role, dartantic.ChatMessageRole.user);
        expect(result[0].text, 'Clicked button');
      });

      test('converts AiTextMessage to model role', () {
        final history = [genui.ChatMessage.model('AI response')];

        final result = converter.toHistory(history);

        expect(result, hasLength(1));
        expect(result[0].role, dartantic.ChatMessageRole.model);
        expect(result[0].text, 'AI response');
      });

      test('includes InternalMessage as system', () {
        final List<genui.ChatMessage> history = [
          genui.ChatMessage.user('Hello'),
          genui.ChatMessage.system('Internal note'),
          genui.ChatMessage.model('Response'),
        ];

        final result = converter.toHistory(history);

        expect(result, hasLength(3));
        expect(result[0].role, dartantic.ChatMessageRole.user);
        expect(result[1].role, dartantic.ChatMessageRole.system);
        expect(result[2].role, dartantic.ChatMessageRole.model);
      });

      test('includes ToolResponseMessage as user tool results', () {
        final List<genui.ChatMessage> history = [
          genui.ChatMessage.user('Hello'),
          genui.ChatMessage.user(
            '',
            parts: [
              const genui.ToolPart.result(
                callId: 'call1',
                toolName: 't',
                result: '{}',
              ),
            ],
          ),
          genui.ChatMessage.model('Response'),
        ];

        final result = converter.toHistory(history);

        expect(result, hasLength(3));
        expect(result[0].role, dartantic.ChatMessageRole.user);
        expect(result[1].role, dartantic.ChatMessageRole.user);
        expect(
          result[1].parts.whereType<dartantic.ToolPart>().length,
          greaterThanOrEqualTo(1),
        );
        expect(result[2].role, dartantic.ChatMessageRole.model);
      });

      test('handles full conversation with system instruction', () {
        final List<genui.ChatMessage> history = [
          genui.ChatMessage.user('What is 2+2?'),
          genui.ChatMessage.model('2+2 equals 4.'),
          genui.ChatMessage.user('And 3+3?'),
        ];

        final result = converter.toHistory(
          history,
          systemInstruction: 'You are a math tutor.',
        );

        expect(result, hasLength(4));
        expect(result[0].role, dartantic.ChatMessageRole.system);
        expect(result[0].text, 'You are a math tutor.');
        expect(result[1].role, dartantic.ChatMessageRole.user);
        expect(result[1].text, 'What is 2+2?');
        expect(result[2].role, dartantic.ChatMessageRole.model);
        expect(result[2].text, '2+2 equals 4.');
        expect(result[3].role, dartantic.ChatMessageRole.user);
        expect(result[3].text, 'And 3+3?');
      });
    });
  });
}
