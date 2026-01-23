// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'model/a2ui_client_capabilities.dart';
import 'model/a2ui_message.dart';
import 'model/chat_message.dart';
import 'model/gen_ui_events.dart';

/// Represents an action to take for an intercepted tool call.
sealed class ToolAction {}

/// Proceed with the tool execution as normal.
class ToolActionProceed extends ToolAction {}

/// Cancel the tool execution. The AI will receive an error or a cancellation message.
class ToolActionCancel extends ToolAction {
  final String reason;
  ToolActionCancel(this.reason);
}

/// Skip execution and provide a mock result to the AI.
class ToolActionMock extends ToolAction {
  final Map<String, Object?> result;
  ToolActionMock(this.result);
}

/// A function that intercepts a tool call.
/// [toolName]: The name of the tool being called.
/// [args]: The arguments passed by the AI.
typedef ToolInterceptor =
    Future<ToolAction> Function(String toolName, Map<String, Object?> args);

/// An error produced by a [ContentGenerator].
final class ContentGeneratorError implements Exception {
  /// The error that occurred.
  final Object error;

  /// The stack trace of the error.
  final StackTrace? stackTrace;

  /// Creates a [ContentGeneratorError].
  const ContentGeneratorError(this.error, [this.stackTrace]);
}

/// An abstract interface for a content generator.
///
/// A content generator is responsible for generating UI content and handling
/// user interactions.
abstract interface class ContentGenerator {
  /// A stream of A2UI messages produced by the generator.
  ///
  /// The `GenUiConversation` will listen to this stream and forward messages
  /// to the `A2uiMessageProcessor`.
  Stream<A2uiMessage> get a2uiMessageStream;

  /// A stream of text responses from the agent.
  Stream<String> get textResponseStream;

  /// A stream of events related to the generation process (tool calls, usage, etc.).
  Stream<GenUiEvent> get eventStream;

  /// A stream of errors from the agent.
  Stream<ContentGeneratorError> get errorStream;

  /// Whether the content generator is currently processing a request.
  ValueListenable<bool> get isProcessing;

  /// Sends a message to the content source to generate a response, optionally
  /// including the previous conversation history.
  ///
  /// Some implementations, particularly those that manage their own state
  /// (stateful), may ignore the `history` parameter.
  Future<void> sendRequest(
    ChatMessage message, {
    Iterable<ChatMessage>? history,
    A2UiClientCapabilities? clientCapabilities,
    Map<String, Object?>? clientDataModel,
  });

  /// Adds a tool interceptor.
  void addInterceptor(ToolInterceptor interceptor);

  /// Removes a tool interceptor.
  void removeInterceptor(ToolInterceptor interceptor);

  /// Disposes of the resources used by this generator.
  void dispose();
}
