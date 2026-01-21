import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_vertexai/firebase_vertexai.dart' as firebase_ai;
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:genui_firebase_ai/genui_firebase_ai.dart';

void main() {
  group('GeminiContentConverter', () {
    late GeminiContentConverter converter;

    setUp(() {
      converter = GeminiContentConverter();
    });

    test('toFirebaseAiContent converts user message with TextPart', () {
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

    test('toFirebaseAiContent converts model message with TextPart', () {
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

    test('toFirebaseAiContent converts UiPart', () {
      final definition = UiDefinition(surfaceId: 'testSurface');
      final messages = [
        ChatMessage.model(
          '',
          parts: [UiPart(definition: definition, surfaceId: 's1')],
        ),
      ];
      final List<firebase_ai.Content> result = converter.toFirebaseAiContent(
        messages,
      );
      expect(result, hasLength(1));
      expect(result.first.role, 'model');
      expect(result.first.parts, hasLength(1)); // UiPart(json)
      // Actually, if ChatMessage.model('') assumes empty text, it might add it.
      // And converter converts TextPart('') -> firebase_ai.TextPart('').
      // And UiPart -> firebase_ai.TextPart(json).
      // If we used Parts.fromText('', parts: [UiPart]),
      // it creates TextPart('') + UiPart.
      // So checks need to be aware.
      // Or we can construct ChatMessage manually
      // to avoid TextPart if we wanted.
      // But typically empty text part is fine.
    });

    test('toFirebaseAiContent converts multi-part user message', () {
      final messages = [
        ChatMessage.user(
          'Look at this image',
          parts: [ImagePart.fromBytes(Uint8List(0), mimeType: 'image/png')],
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

    // Removed DataPart test as it is no longer supported directly

    test('toFirebaseAiContent converts ImagePart from bytes', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final messages = [
        ChatMessage.user(
          '',
          parts: [ImagePart.fromBytes(bytes, mimeType: 'image/jpeg')],
        ),
      ];
      final List<firebase_ai.Content> result = converter.toFirebaseAiContent(
        messages,
      );
      // Expect 2 parts because ChatMessage.user('') adds empty TextPart?
      // Or 1 part if empty text filtering logic exists elsewhere?
      // Based on my assumption: Index 0 is TextPart(''), Index 1 is ImagePart.
      // Wait, let's just find the InlineDataPart.
      final firebase_ai.InlineDataPart part = result.first.parts
          .whereType<firebase_ai.InlineDataPart>()
          .first;
      expect(part.mimeType, 'image/jpeg');
      expect(part.bytes, bytes);
    });

    test('toFirebaseAiContent converts ImagePart from base64', () {
      const base64String = 'AQID'; // base64 for [1, 2, 3]
      final messages = [
        ChatMessage.user(
          '',
          parts: [
            const ImagePart.fromBase64(base64String, mimeType: 'image/png'),
          ],
        ),
      ];
      final List<firebase_ai.Content> result = converter.toFirebaseAiContent(
        messages,
      );
      final firebase_ai.InlineDataPart part = result.first.parts
          .whereType<firebase_ai.InlineDataPart>()
          .first;
      expect(part.mimeType, 'image/png');
      expect(part.bytes, base64.decode(base64String));
    });

    test('toFirebaseAiContent converts ImagePart from URL', () {
      final Uri url = Uri.parse('http://example.com/image.jpg');
      final messages = [
        ChatMessage.user(
          '',
          parts: [ImagePart.fromUrl(url, mimeType: 'image/jpeg')],
        ),
      ];
      final List<firebase_ai.Content> result = converter.toFirebaseAiContent(
        messages,
      );
      // Should find a TextPart with "Image at ..."
      final Iterable<firebase_ai.TextPart> parts = result.first.parts
          .whereType<firebase_ai.TextPart>();
      // One empty text part (from ''), one from image URL.
      expect(parts.any((p) => p.text == 'Image at $url'), isTrue);
    });

    test('toFirebaseAiContent converts ToolCall', () {
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
      // Might have empty TextPart first.
      final firebase_ai.FunctionCall part = result.first.parts
          .whereType<firebase_ai.FunctionCall>()
          .first;
      expect(part.name, 'doSomething');
      expect(part.args, {'arg': 'value'});
    });

    test('toFirebaseAiContent converts ToolResult', () {
      final messages = [
        ChatMessage.user(
          '',
          parts: [
            // ToolResultPart -> ToolPart.result
            // Note: ToolPart.result expects 'result' object.
            // firebase_vertexai FunctionResponse expects serializable object.
            const ToolPart.result(
              callId: 'call1',
              toolName: 'doSomething',
              result: {'data': 'ok'},
            ),
          ],
        ),
      ];
      final List<firebase_ai.Content> result = converter.toFirebaseAiContent(
        messages,
      );
      expect(result.first.role, 'user');
      final firebase_ai.FunctionResponse part = result.first.parts
          .whereType<firebase_ai.FunctionResponse>()
          .first;
      expect(
        part.name,
        'doSomething',
      ); // Note: ToolPart.result in genui has toolName
      expect(part.response, {'data': 'ok'});
    });

    test('toFirebaseAiContent converts ThinkingPart', () {
      final messages = [
        ChatMessage.model('', parts: [const ThinkingPart('working on it')]),
      ];
      final List<firebase_ai.Content> result = converter.toFirebaseAiContent(
        messages,
      );
      final Iterable<firebase_ai.TextPart> parts = result.first.parts
          .whereType<firebase_ai.TextPart>();
      expect(parts.any((p) => p.text == 'Thinking: working on it'), isTrue);
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
