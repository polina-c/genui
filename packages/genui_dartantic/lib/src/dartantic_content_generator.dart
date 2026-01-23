// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: specify_nonobvious_local_variable_types

import 'dart:async';

import 'package:dartantic_ai/dartantic_ai.dart' as dartantic;
import 'package:flutter/foundation.dart';
import 'package:genui/genui.dart';

import 'dartantic_content_converter.dart';
import 'dartantic_schema_adapter.dart';

/// A [ContentGenerator] that uses Dartantic AI to generate content.
///
/// This generator utilizes a [dartantic.Provider] to interact with various
/// AI providers (OpenAI, Anthropic, Google, Mistral, Cohere, Ollama) through
/// the dartantic_ai package.
///
/// The generator creates tools from the GenUI catalog and any additional tools
/// provided, then uses dartantic's built-in tool calling and structured output
/// capabilities to generate UI content.
///
/// This implementation is **stateless** - it does not maintain internal
/// conversation history. Instead, it uses the history provided by
/// [GenUiConversation] via the [sendRequest] method's `history` parameter.
class DartanticContentGenerator
    with ContentGeneratorMixin
    implements ContentGenerator {
  /// Creates a [DartanticContentGenerator] instance.
  ///
  /// - [provider]: The dartantic AI provider to use (e.g., `Providers.google`,
  ///   `Providers.openai`, `Providers.anthropic`).
  /// - [catalog]: The catalog of UI components available to the AI.
  /// - [systemInstruction]: Optional system instruction for the AI model.
  /// - [modelName]: The name of the model to use (specific to the provider).
  /// - [additionalTools]: Additional GenUI [AiTool] instances to make
  ///   available.
  DartanticContentGenerator({
    required dartantic.Provider provider,
    required this.catalog,
    this.systemInstruction,
    this.modelName,
    List<AiTool<JsonMap>> additionalTools = const [],
  }) {
    // Build GenUI tools
    final genUiTools = <AiTool<JsonMap>>[
      ...additionalTools,
    ];

    // Convert all tools to dartantic format
    final List<dartantic.Tool> dartanticTools = _convertTools(genUiTools);

    // Create agent with converted tools
    _agent = dartantic.Agent.forProvider(
      provider,
      chatModelName: modelName,
      tools: dartanticTools,
    );

    // Create additional system instructions to augment what the client sends
    _extraInstructions =
        '''
<tools>
${dartanticTools.map((tool) => tool.toJson()).join('\n\n')}
</tools>

<a2ui_schema>
${A2uiMessage.a2uiMessageSchema(catalog).toJson(indent: '  ')}
</a2ui_schema>

''';

    genUiLogger.info('Extra system instructions: $_extraInstructions');
  }

  /// The catalog of UI components available to the AI.
  final Catalog catalog;

  /// The system instruction to use for the AI model.
  final String? systemInstruction;

  /// The model name to use.
  final String? modelName;

  /// The configuration of the GenUI system.

  late final dartantic.Agent _agent;
  final DartanticContentConverter _converter = DartanticContentConverter();

  final _a2uiMessageController = StreamController<A2uiMessage>.broadcast();
  final _textResponseController = StreamController<String>.broadcast();
  final _errorController = StreamController<ContentGeneratorError>.broadcast();
  final _isProcessing = ValueNotifier<bool>(false);
  late final String _extraInstructions;

  @override
  Stream<A2uiMessage> get a2uiMessageStream => _a2uiMessageController.stream;

  @override
  Stream<String> get textResponseStream => _textResponseController.stream;

  @override
  Stream<ContentGeneratorError> get errorStream => _errorController.stream;

  @override
  ValueListenable<bool> get isProcessing => _isProcessing;

  @override
  void dispose() {
    disposeMixin();
    _a2uiMessageController.close();
    _textResponseController.close();
    _errorController.close();
    _isProcessing.dispose();
  }

  CancellationSignal? _currentCancellationSignal;

  @override
  Future<void> sendRequest(
    ChatMessage message, {
    Iterable<ChatMessage>? history,
    A2UiClientCapabilities? clientCapabilities,
    Map<String, Object?>? clientDataModel,
    CancellationSignal? cancellationSignal,
  }) async {
    _isProcessing.value = true;
    _currentCancellationSignal = cancellationSignal;
    try {
      if (cancellationSignal?.isCancelled ?? false) {
        throw const CancellationException();
      }

      // Convert GenUI history to dartantic ChatMessage list
      final List<dartantic.ChatMessage> dartanticHistory = _converter.toHistory(
        history,
        systemInstruction: '$systemInstruction\n\n$_extraInstructions',
      );

      // Convert the current GenUI message into prompt text plus parts so we
      // preserve text, data, and tool content.
      final ({String prompt, List<dartantic.Part> parts}) promptAndParts =
          _converter.toPromptAndParts(message);

      // We should never have tool calls or results in request message.
      assert(promptAndParts.parts.every((part) => part is! dartantic.ToolPart));

      genUiLogger.info(
        'Sending request to Dartantic: "${promptAndParts.prompt}"',
      );
      genUiLogger.fine('History contains ${dartanticHistory.length} messages');

      // Use Agent.send for unstructured text output.
      // We expect the model to include A2UI JSON in its text response.
      final result = await _agent.send(
        promptAndParts.prompt,
        history: dartanticHistory,
        attachments: promptAndParts.parts,
      );

      var responseText = result.output;
      // Parse JSON from text
      final List<Object> jsonBlocks = JsonBlockParser.parseJsonBlocks(
        responseText,
      );
      for (final jsonBlock in jsonBlocks) {
        try {
          if (jsonBlock is Map<String, dynamic>) {
            final message = A2uiMessage.fromJson(jsonBlock);
            _a2uiMessageController.add(message);
            genUiLogger.info(
              'Emitted A2UI message from prompt extraction: '
              '${message.runtimeType}',
            );
          }
        } catch (e) {
          genUiLogger.warning(
            'Failed to parse extracted JSON as A2uiMessage: $e',
          );
        }
      }

      if (jsonBlocks.isNotEmpty) {
        // remove the JSON from the text response
        responseText = JsonBlockParser.stripJsonBlock(responseText);
      }

      _textResponseController.add(responseText);
      genUiLogger.info('Received response from Dartantic: $responseText');
    } on CancellationException {
      genUiLogger.info('Request cancelled');
    } catch (e, st) {
      genUiLogger.severe('Error generating content', e, st);
      _errorController.add(ContentGeneratorError(e, st));
    } finally {
      _currentCancellationSignal = null;
      _isProcessing.value = false;
    }
  }

  /// Converts GenUI [AiTool] instances to dartantic [dartantic.Tool] instances.
  List<dartantic.Tool> _convertTools(List<AiTool<JsonMap>> tools) => tools
      .map(
        (aiTool) => dartantic.Tool(
          name: aiTool.name,
          description: aiTool.description,
          inputSchema: adaptSchema(aiTool.parameters),
          onCall: (Map<String, dynamic> args) async {
            if (_currentCancellationSignal?.isCancelled ?? false) {
              throw const CancellationException();
            }

            // Intercept tool call
            final toolAction = await interceptToolCall(aiTool.name, args);

            if (toolAction is ToolActionCancel) {
              genUiLogger.info(
                'Tool call ${aiTool.name} cancelled by interceptor.',
              );
              return {'error': 'Tool call cancelled by client.'};
            } else if (toolAction is ToolActionMock) {
              genUiLogger.info(
                'Tool call ${aiTool.name} mocked by interceptor '
                'with result: ${toolAction.result}',
              );
              return toolAction.result as Map<String, dynamic>;
            }

            genUiLogger.fine('Invoking tool: ${aiTool.name} with args: $args');

            // Emit ToolStartEvent
            emitEvent(ToolStartEvent(toolName: aiTool.name, args: args));

            dynamic result;
            final startTime = DateTime.now();
            try {
              result = await aiTool.invoke(args);
              genUiLogger.fine('Tool ${aiTool.name} returned: $result');
            } catch (e, st) {
              genUiLogger.severe('Tool ${aiTool.name} failed', e, st);
              result = {'error': e.toString()};
            }
            final duration = DateTime.now().difference(startTime);

            // Emit ToolEndEvent
            emitEvent(
              ToolEndEvent(
                toolName: aiTool.name,
                result: result,
                duration: duration,
              ),
            );

            return result is Map<String, dynamic> ? result : {'result': result};
          },
        ),
      )
      .toList();

}
