// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:dartantic_ai/dartantic_ai.dart' as dartantic;
import 'package:genui/genui.dart' as genui;

/// An exception thrown by this package.
class ContentConverterException implements Exception {
  /// Creates a [ContentConverterException] with the given [message].
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
  /// Maps GenUI message types to dartantic roles:
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

    if (systemInstruction != null) {
      result.add(dartantic.ChatMessage.system(systemInstruction));
    }

    if (history != null) {
      for (final genui.ChatMessage message in history) {
        final dartantic.ChatMessageRole role;
        switch (message.role) {
          case genui.ChatMessageRole.user:
            role = dartantic.ChatMessageRole.user;
          case genui.ChatMessageRole.model:
            role = dartantic.ChatMessageRole.model;
          case genui.ChatMessageRole.system:
            role = dartantic.ChatMessageRole.system;
        }

        result.add(
          dartantic.ChatMessage(role: role, parts: _toParts(message.parts)),
        );
      }
    }

    return result;
  }

  /// Extracts text content from a list of [genui.StandardPart] instances.
  ///
  /// Joins all [genui.TextPart] text values with newlines.
  /// Also includes text representation of other parts if possible/needed.
  String _extractText(List<genui.StandardPart> parts) {
    final textParts = <String>[];
    for (final part in parts) {
      if (part is genui.TextPart) {
        textParts.add(part.text);
      } else if (part.isUiInteractionPart) {
        // UI Interactions are handled as data parts in _toParts.
      } else if (part is genui.DataPart) {
        // Skip data parts in text prompt
      } else if (part is genui.LinkPart) {
        textParts.add('Image at ${part.url}');
      } else if (part is genui.ToolPart) {
        if (part.kind == genui.ToolPartKind.call) {
          textParts.add('ToolCall(${part.toolName}): ${part.argumentsRaw}');
        } else {
          textParts.add('ToolResult(${part.callId}): ${part.result}');
        }
      } else if (part is genui.ThinkingPart) {
        textParts.add('Thinking: ${part.text}');
      }
    }
    return textParts.join('\n');
  }

  /// Converts GenUI message parts to dartantic parts.
  List<dartantic.Part> _toParts(List<genui.StandardPart> parts) {
    final converted = <dartantic.Part>[];
    for (final part in parts) {
      if (part is genui.TextPart) {
        converted.add(dartantic.TextPart(part.text));
      } else if (part.isUiInteractionPart) {
        final genui.UiInteractionPart uiPart = part.asUiInteractionPart!;
        converted.add(
          dartantic.DataPart(
            utf8.encode(uiPart.interaction),
            mimeType: 'application/json',
          ),
        );
      } else if (part.isUiPart) {
        final genui.UiPart uiPart = part.asUiPart!;
        converted.add(
          dartantic.DataPart(
            utf8.encode(jsonEncode(uiPart.definition.toJson())),
            mimeType: 'application/json',
          ),
        );
      } else if (part is genui.DataPart) {
        converted.add(dartantic.DataPart(part.bytes, mimeType: part.mimeType));
      } else if (part is genui.LinkPart) {
        converted.add(
          dartantic.LinkPart(
            part.url,
            mimeType: part.mimeType,
            name: part.name,
          ),
        );
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
          converted.add(
            dartantic.ToolPart.result(
              id: part.callId,
              name: part.toolName,
              result: part.result,
            ),
          );
        }
      } else if (part is genui.ThinkingPart) {
        converted.add(dartantic.TextPart('Thinking: ${part.text}'));
      }
    }
    return converted;
  }

  /// Converts GenUI message parts to dartantic parts, excluding text parts to
  /// avoid duplicate text in both prompt and attachments.
  List<dartantic.Part> _toPartsWithoutText(List<genui.StandardPart> parts) {
    final List<genui.StandardPart> filtered = parts
        .where((p) => p is! genui.TextPart)
        .toList();
    return _toParts(filtered);
  }
}
