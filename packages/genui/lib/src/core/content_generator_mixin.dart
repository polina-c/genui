// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import '../content_generator.dart';
import '../model/gen_ui_events.dart';

/// A mixin that implements the event stream and interceptor logic for
/// [ContentGenerator].
mixin ContentGeneratorMixin implements ContentGenerator {
  final _interceptors = <ToolInterceptor>[];
  final _eventController = StreamController<GenUiEvent>.broadcast();

  @override
  Stream<GenUiEvent> get eventStream => _eventController.stream;

  @override
  void addInterceptor(ToolInterceptor interceptor) {
    _interceptors.add(interceptor);
  }

  @override
  void removeInterceptor(ToolInterceptor interceptor) {
    _interceptors.remove(interceptor);
  }

  /// Disposes of the resources used by this mixin.
  ///
  /// Classes mixing this in must call this method in their [dispose] method.
  void disposeMixin() {
    _eventController.close();
  }

  /// Emit an event to the [eventStream].
  void emitEvent(GenUiEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  /// Executes interceptors for a tool call.
  ///
  /// Returns the result of the first interceptor that returns a non-proceed
  /// action, or [ToolActionProceed] if all interceptors proceed.
  Future<ToolAction> interceptToolCall(
    String toolName,
    Map<String, Object?> args,
  ) async {
    for (final ToolInterceptor interceptor in _interceptors) {
      final ToolAction action = await interceptor(toolName, args);
      if (action is! ToolActionProceed) {
        return action;
      }
    }
    return ToolActionProceed();
  }
}
