// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:genui/genui.dart';
import 'package:google_cloud_ai_generativelanguage_v1beta/generativelanguage.dart'
    as google_ai;
import 'package:google_cloud_protobuf/protobuf.dart' as protobuf;

/// An exception thrown by this package.
class GoogleAiClientException implements Exception {
  /// Creates a [GoogleAiClientException] with the given [message].
  GoogleAiClientException(this.message);

  /// The message associated with the exception.
  final String message;

  @override
  String toString() => '$GoogleAiClientException: $message';
}

/// A class to convert between the generic `ChatMessage` and the `google_ai`
/// specific `Content` classes.
///
/// This class is responsible for translating the abstract [ChatMessage]
/// representation into the concrete `google_ai.Content` representation
/// required by the `google_cloud_ai_generativelanguage_v1beta` package.
class GoogleContentConverter {
  /// Converts a list of `ChatMessage` objects to a list of
  /// `google_ai.Content` objects.
  List<google_ai.Content> toGoogleAiContent(Iterable<ChatMessage> messages) {
    final result = <google_ai.Content>[];
    for (final message in messages) {
      if (message.parts.isEmpty) continue;

      final role = switch (message.role) {
        ChatMessageRole.user => 'user',
        ChatMessageRole.model => 'model',
        ChatMessageRole.system => 'user',
        // System messages often map to user or specific config in Google AI
      };

      final parts = _convertParts(message.parts);
      if (parts.isNotEmpty) {
        result.add(google_ai.Content(role: role, parts: parts));
      }
    }
    return result;
  }

  List<google_ai.Part> _convertParts(Iterable<Part> parts) {
    final result = <google_ai.Part>[];
    for (final part in parts) {
      if (part is TextPart) {
        result.add(google_ai.Part(text: part.text));
      } else if (part is ImagePart) {
        if (part.bytes != null) {
          result.add(
            google_ai.Part(
              inlineData: google_ai.Blob(
                mimeType: part.mimeType,
                data: part.bytes!,
              ),
            ),
          );
        } else if (part.base64 != null) {
          result.add(
            google_ai.Part(
              inlineData: google_ai.Blob(
                mimeType: part.mimeType,
                data: Uint8List.fromList(base64.decode(part.base64!)),
              ),
            ),
          );
        } else if (part.url != null) {
          result.add(
            google_ai.Part(
              fileData: google_ai.FileData(fileUri: part.url.toString()),
            ),
          );
        } else {
          throw GoogleAiClientException('ImagePart has no data.');
        }
      } else if (part is ToolPart) {
        if (part.result != null) {
          // Tool Result
          result.add(
            google_ai.Part(
              functionResponse: google_ai.FunctionResponse(
                id: part.callId,
                name: part.toolName, // Name might be optional in response
                response: protobuf.Struct.fromJson(
                  (part.result is String)
                      ? jsonDecode(part.result as String)
                            as Map<String, Object?>
                      : part.result as Map<String, Object?>,
                ),
              ),
            ),
          );
        } else {
          // Tool Call
          result.add(
            google_ai.Part(
              functionCall: google_ai.FunctionCall(
                id: part.callId,
                name: part.toolName, // Analyzer believes this is non-null here
                args: protobuf.Struct.fromJson(part.arguments ?? {}),
              ),
            ),
          );
        }
      } else if (part is ThinkingPart) {
        result.add(google_ai.Part(text: 'Thinking: ${part.text}'));
      } else if (part is UiPart) {
        // Convert UI definition to JSON text for history
        result.add(google_ai.Part(text: jsonEncode(part.definition)));
      } else if (part is UiInteractionPart) {
        result.add(google_ai.Part(text: part.interaction));
      } else {
        // Generic fallback or ignore
        // throw GoogleAiClientException(
        //   'Unsupported part type: ${part.runtimeType}',
        // );
      }
    }
    return result;
  }
}
