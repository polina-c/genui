// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:dartantic_ai/dartantic_ai.dart' as dartantic;
import 'package:genui/genui.dart' as genui;

/// An exception thrown by this package.
class ContentConverterException implements Exception {
  /// Creates an [ContentConverterException] with the given [message].
  ContentConverterException(this.message);

  /// The message associated with the exception.
  final String message;

  @override
  String toString() => '$ContentConverterException: $message';
}

/// A class to convert between GenUI `ChatMessage` types and text/data formats
/// suitable for dartantic_ai.
///
/// Since dartantic_ai's Chat class manages conversation history automatically
/// and accepts simple string prompts, this converter primarily extracts text
/// content from GenUI messages.
class DartanticContentConverter {
  /// Converts a GenUI [genui.ChatMessage] into a prompt string plus dartantic
  /// parts so we can send full multimodal content (text, data, tools).
  ({String prompt, List<dartantic.Part> parts}) toPromptAndParts(
    genui.ChatMessage message,
  ) {
    return (
      prompt: _extractText(message.parts),
      parts: _toPartsWithoutText(message.parts),
    );
  }

  /// Converts GenUI chat history to a list of dartantic
  /// [dartantic.ChatMessage].
  ///
  /// Maps GenUI message roles to dartantic roles:
  /// - [genui.ChatMessageRole.user] -> [dartantic.ChatMessage.user]
  /// - [genui.ChatMessageRole.model] -> [dartantic.ChatMessage.model]
  /// - [genui.ChatMessageRole.system] -> [dartantic.ChatMessage.system]
  ///
  /// If [systemInstruction] is provided, it is added as the first message using
  /// [dartantic.ChatMessage.system].
  List<dartantic.ChatMessage> toHistory(
    Iterable<genui.ChatMessage>? history, {
    String? systemInstruction,
  }) {
    final result = <dartantic.ChatMessage>[];

    // Add system instruction first if provided
    if (systemInstruction != null) {
      result.add(dartantic.ChatMessage.system(systemInstruction));
    }

    // Convert each GenUI message to dartantic format
    if (history != null) {
      for (final genui.ChatMessage message in history) {
        switch (message.role) {
          case genui.ChatMessageRole.user:
            result.add(
              dartantic.ChatMessage(
                role: dartantic.ChatMessageRole.user,
                parts: _toParts(message.parts),
              ),
            );
          case genui.ChatMessageRole.model:
            result.add(
              dartantic.ChatMessage(
                role: dartantic.ChatMessageRole.model,
                parts: _toParts(message.parts),
              ),
            );
          case genui.ChatMessageRole.system:
            final text = _extractText(message.parts);
            if (text.isNotEmpty) {
              result.add(dartantic.ChatMessage.system(text));
            }
        }
      }
    }

    return result;
  }

  /// Extracts text content from a list of [genui.Part] instances.
  ///
  /// Joins all text values with newlines.
  String _extractText(Iterable<genui.Part> parts) {
    final textParts = <String>[];
    for (final part in parts) {
      if (part is genui.TextPart) {
        textParts.add(part.text);
      } else if (part is genui.ImagePart) {
        // Note: dartantic_ai may support images natively in some providers,
        // but for simplicity we just note the presence of an image.
        if (part.url != null) {
          textParts.add('Image at ${part.url}');
        } else {
          textParts.add('[Image data]');
        }
      } else if (part is genui.ToolPart) {
        if (part.kind == genui.ToolPartKind.call) {
          textParts.add('ToolCall(${part.toolName}): ${part.argumentsRaw}');
        } else {
          textParts.add('ToolResult(${part.callId}): ${part.result}');
        }
      } else if (part is genui.ThinkingPart) {
        textParts.add('Thinking: ${part.text}');
      } else if (part is genui.UiPart) {
        textParts.add(jsonEncode(part.definition));
      } else if (part is genui.UiInteractionPart) {
        textParts.add(part.interaction);
      }
    }
    return textParts.join('\n');
  }

  /// Converts GenUI message parts to dartantic parts.
  List<dartantic.Part> _toParts(Iterable<genui.Part> parts) {
    final converted = <dartantic.Part>[];
    for (final part in parts) {
      if (part is genui.TextPart) {
        converted.add(dartantic.TextPart(part.text));
      } else if (part is genui.ImagePart) {
        if (part.url != null) {
          converted.add(
            dartantic.LinkPart(part.url!, mimeType: part.mimeType, name: null),
          );
        } else {
          converted.add(const dartantic.TextPart('[Image data]'));
        }
      } else if (part is genui.ToolPart) {
        if (part.kind == genui.ToolPartKind.call) {
          converted.add(
            dartantic.ToolPart.call(
              id: part.callId,
              name: part.toolName,
              arguments: part.arguments ?? {},
            ),
          );
        } else {
          // Tool result
          converted.add(
            dartantic.ToolPart.result(
              id: part.callId,
              name: 'tool_response', // Is this correct? Or toolName?
              result: _decodeMaybeJson(part.result),
            ),
          );
        }
      } else if (part is genui.ThinkingPart) {
        converted.add(dartantic.TextPart('Thinking: ${part.text}'));
      } else if (part is genui.UiPart) {
        converted.add(dartantic.TextPart(jsonEncode(part.definition)));
      } else if (part is genui.UiInteractionPart) {
        converted.add(dartantic.TextPart(part.interaction));
      }
    }
    return converted;
  }

  /// Converts GenUI message parts to dartantic parts, excluding text parts to
  /// avoid duplicate text in both prompt and attachments.
  List<dartantic.Part> _toPartsWithoutText(Iterable<genui.Part> parts) {
    final List<genui.Part> filtered = parts
        .where((p) => p is! genui.TextPart)
        .toList();
    return _toParts(filtered);
  }

  /// Attempts to decode a JSON string or map; returns input/decoded.
  Object? _decodeMaybeJson(Object? input) {
    if (input is String) {
      try {
        return jsonDecode(input);
      } catch (_) {
        return input;
      }
    }
    return input;
  }
}
