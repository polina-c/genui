import 'dart:async';

import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart' as genui;
import 'package:genui_firebase_ai/src/firebase_ai_content_generator.dart';
import 'package:genui_firebase_ai/src/gemini_generative_model.dart';
import 'package:json_schema_builder/json_schema_builder.dart' as dsb;

void main() {
  group('FirebaseAiContentGenerator', () {
    test('isProcessing is true during request', () async {
      final generator = FirebaseAiContentGenerator(
        catalog: const genui.Catalog({}),
        modelCreator:
            ({required configuration, systemInstruction, tools, toolConfig}) {
              return FakeGeminiGenerativeModel([
                GenerateContentResponse([
                  Candidate(
                    Content.model([
                      FunctionCall('provideFinalOutput', {
                        'output': {'response': 'Hello'},
                      }),
                    ]),
                    [],
                    null,
                    FinishReason.stop,
                    '',
                  ),
                ], null),
              ]);
            },
      );

      expect(generator.isProcessing.value, isFalse);
      final Future<void> future = generator.sendRequest(
        genui.ChatMessage.user('Hi'),
      );
      expect(generator.isProcessing.value, isTrue);
      await future;
      expect(generator.isProcessing.value, isFalse);
    });

    test('can call a tool and return a result', () async {
      final generator = FirebaseAiContentGenerator(
        catalog: const genui.Catalog({}),
        additionalTools: [
          genui.DynamicAiTool<Map<String, Object?>>(
            name: 'testTool',
            description: 'A test tool',
            parameters: dsb.Schema.object(), // using json_schema_builder Schema
            invokeFunction: (args) async => {'result': 'tool result'},
          ),
        ],
        modelCreator:
            ({required configuration, systemInstruction, tools, toolConfig}) {
              return FakeGeminiGenerativeModel([
                GenerateContentResponse([
                  Candidate(
                    Content.model([FunctionCall('testTool', {})]),
                    [],
                    null,
                    FinishReason.stop,
                    '',
                  ),
                ], null),
                GenerateContentResponse([
                  Candidate(
                    Content.model([
                      FunctionCall('provideFinalOutput', {
                        'output': {'response': 'Tool called'},
                      }),
                    ]),
                    [],
                    null,
                    FinishReason.stop,
                    '',
                  ),
                ], null),
              ]);
            },
      );

      final hi = genui.ChatMessage.user('Hi');
      final completer = Completer<String>();
      unawaited(generator.textResponseStream.first.then(completer.complete));
      await generator.sendRequest(hi);
      final String response = await completer.future;
      expect(response, 'Tool called');
    });

    test('returns a simple text response', () async {
      final generator = FirebaseAiContentGenerator(
        catalog: const genui.Catalog({}),
        modelCreator:
            ({required configuration, systemInstruction, tools, toolConfig}) {
              return FakeGeminiGenerativeModel([
                GenerateContentResponse([
                  Candidate(
                    Content.model([
                      FunctionCall('provideFinalOutput', {
                        'output': {'response': 'Hello'},
                      }),
                    ]),
                    [],
                    null,
                    FinishReason.stop,
                    '',
                  ),
                ], null),
              ]);
            },
      );

      final hi = genui.ChatMessage.user('Hi');
      final completer = Completer<String>();
      unawaited(generator.textResponseStream.first.then(completer.complete));
      await generator.sendRequest(hi);
      final String response = await completer.future;
      expect(response, 'Hello');
    });
  });
}

class FakeGeminiGenerativeModel implements GeminiGenerativeModelInterface {
  FakeGeminiGenerativeModel(this.responses);

  final List<GenerateContentResponse> responses;
  int callCount = 0;

  @override
  Future<GenerateContentResponse> generateContent(Iterable<Content> content) {
    return Future.delayed(Duration.zero, () => responses[callCount++]);
  }
}
