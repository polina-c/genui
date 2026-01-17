import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_vertexai/firebase_vertexai.dart' as firebase_ai;
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
///
/// This class is responsible for translating the abstract [ChatMessage]
/// representation into the concrete `firebase_ai.Content` representation
/// required by the `firebase_vertexai` package.
///
/// **Note on Image Handling:** [ImagePart] instances that are provided with
/// only a `url` (and no `bytes` or `base64` data) will be converted to a
/// simple text representation of the URL (e.g., "Image at {url}"). The image
/// data is not automatically fetched from the URL by this converter.
class GeminiContentConverter {
  /// Converts a list of `ChatMessage` objects to a list of
  /// `firebase_ai.Content` objects.
  List<firebase_ai.Content> toFirebaseAiContent(
    Iterable<ChatMessage> messages,
  ) {
    final result = <firebase_ai.Content>[];
    for (final message in messages) {
      if (message.parts.isEmpty) continue;

      final role = switch (message.role) {
        ChatMessageRole.user => 'user',
        ChatMessageRole.model => 'model',
        ChatMessageRole.system => 'user',
      };

      final parts = _convertParts(message.parts);
      if (parts.isNotEmpty) {
        result.add(firebase_ai.Content(role, parts));
      }
    }
    return result;
  }

  List<firebase_ai.Part> _convertParts(Iterable<Part> parts) {
    final result = <firebase_ai.Part>[];
    for (final part in parts) {
      if (part is TextPart) {
        result.add(firebase_ai.TextPart(part.text));
      } else if (part is ImagePart) {
        if (part.bytes != null) {
          result.add(firebase_ai.InlineDataPart(part.mimeType, part.bytes!));
        } else if (part.base64 != null) {
          result.add(
            firebase_ai.InlineDataPart(
              part.mimeType,
              Uint8List.fromList(base64.decode(part.base64!)),
            ),
          );
        } else if (part.url != null) {
          result.add(firebase_ai.TextPart('Image at ${part.url}'));
        } else {
          throw ContentConverterException('ImagePart has no data.');
        }
      } else if (part is ToolPart) {
        if (part.result != null) {
          // Tool Result
          result.add(
            firebase_ai.FunctionResponse(
              part.toolName,
              // FunctionResponse expects a Map
              (part.result is String)
                  ? jsonDecode(part.result as String) as Map<String, Object?>
                  : part.result as Map<String, Object?>,
            ),
          );
        } else {
          // Tool Call
          result.add(
            firebase_ai.FunctionCall(part.toolName, part.arguments ?? {}),
          );
        }
      } else if (part is ThinkingPart) {
        // Represent thoughts as text.
        result.add(firebase_ai.TextPart('Thinking: ${part.text}'));
      } else if (part is UiPart) {
        // Convert UI definition to JSON text used for history tracking
        result.add(firebase_ai.TextPart(jsonEncode(part.definition)));
      } else if (part is UiInteractionPart) {
        result.add(firebase_ai.TextPart(part.interaction));
      }
    }
    return result;
  }
}
