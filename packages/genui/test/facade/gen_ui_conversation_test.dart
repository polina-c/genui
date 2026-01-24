// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';

class FakeContentGenerator implements ContentGenerator {
  @override
  final ValueNotifier<bool> isProcessing = ValueNotifier(false);

  @override
  Stream<A2uiMessage> get a2uiMessageStream => const Stream.empty();
  @override
  Stream<ContentGeneratorError> get errorStream => const Stream.empty();
  @override
  Stream<GenUiEvent> get eventStream => const Stream.empty();
  @override
  Stream<String> get textResponseStream => const Stream.empty();

  @override
  Future<void> sendRequest(
    ChatMessage message, {
    Iterable<ChatMessage>? history,
    A2UiClientCapabilities? clientCapabilities,
    Map<String, Object?>? clientDataModel,
    CancellationSignal? cancellationSignal,
  }) async {
    isProcessing.value = true;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    isProcessing.value = false;
  }

  @override
  void addInterceptor(ToolInterceptor interceptor) {}
  @override
  void dispose() {}
  @override
  void removeInterceptor(ToolInterceptor interceptor) {}
}

void main() {
  group('GenUiConversation', () {
    test('prevents concurrent requests', () async {
      final generator = FakeContentGenerator();
      final processor = A2uiMessageProcessor(catalogs: []);
      final conversation = GenUiConversation(
        contentGenerator: generator,
        a2uiMessageProcessor: processor,
      );

      // Send first request
      final Future<void> future = conversation.sendRequest(
        ChatMessage.user('', parts: [UiInteractionPart.create('hi')]),
      );

      // Expect second request to fail
      expect(
        () => conversation.sendRequest(
          ChatMessage.user('', parts: [UiInteractionPart.create('second')]),
        ),
        throwsStateError,
      );

      await future;

      // Should succeed now
      await conversation.sendRequest(
        ChatMessage.user('', parts: [UiInteractionPart.create('third')]),
      );
    });
  });
}
