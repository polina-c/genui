// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart' as firebase_ai;
import 'package:genui/genui.dart';

/// An exception thrown by this package.
class ContentConverterException implements Exception {
  /// Creates an [ContentConverterException] with the given [message].
  ContentConverterException(this.message);

  /// The message associated with the exception.
  final String message;

  @override
  String toString() => '$ContentConverterException: $message';
}

/// A class to convert between the generic `ChatMessage` and the `firebase_ai`
/// specific `Content` classes.
class GeminiContentConverter {
  /// Converts a list of [ChatMessage]s to a list of [firebase_ai.Content]s.
  List<firebase_ai.Content> toFirebaseAiContent(
    Iterable<ChatMessage> messages,
  ) {
    final result = <firebase_ai.Content>[];
    for (final message in messages) {
      final String? role = switch (message.role) {
        ChatMessageRole.user => 'user',
        ChatMessageRole.model => 'model',
        ChatMessageRole.system => null, // Skip system messages
      };

      if (role == null) continue;

      final List<firebase_ai.Part> parts = _convertParts(message.parts);
      if (parts.isNotEmpty) {
        result.add(firebase_ai.Content(role, parts));
      }
    }
    return result;
  }

  List<firebase_ai.Part> _convertParts(List<StandardPart> parts) {
    final result = <firebase_ai.Part>[];
    for (final part in parts) {
      switch (part) {
        case TextPart(:final text):
          result.add(firebase_ai.TextPart(text));
        case DataPart():
          if (part.isUiPart) {
            final UiPart uiPart = part.asUiPart!;
            result.add(
              firebase_ai.TextPart(
                uiPart.definition.asContextDescriptionText(),
              ),
            );
          } else {
            result.add(firebase_ai.InlineDataPart(part.mimeType, part.bytes));
          }
        case LinkPart(:final url):
          result.add(firebase_ai.TextPart('Image at $url'));
        case ToolPart(
          :final callId,
          :final toolName,
          :final arguments,
          result: final toolResult,
        ):
          if (toolResult != null) {
            // Tool Result
            Map<String, Object?> mapResult;
            if (toolResult is String) {
              try {
                mapResult = jsonDecode(toolResult) as Map<String, Object?>;
              } catch (_) {
                mapResult = {'result': toolResult};
              }
            } else if (toolResult is Map) {
              mapResult = toolResult as Map<String, Object?>;
            } else {
              mapResult = {'result': toolResult};
            }

            result.add(firebase_ai.FunctionResponse(callId, mapResult));
          } else {
            // Tool Call
            result.add(firebase_ai.FunctionCall(toolName, arguments ?? {}));
          }
        case ThinkingPart(:final text):
          result.add(firebase_ai.TextPart('Thinking: $text'));
      }
    }
    return result;
  }
}
