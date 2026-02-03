// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import '../model/a2ui_message.dart';
import '../model/catalog.dart';
import '../model/data_model.dart';
import '../model/ui_models.dart';

/// An interface for a message sink that accepts [A2uiMessage]s.
abstract interface class A2uiMessageSink {
  /// Handles a message from the client.
  void handleMessage(A2uiMessage message);
}

/// An interface for a class that hosts UI surfaces.
///
/// This is used by `GenUiSurface` to get the UI definition for a surface,
/// listen for updates, and notify the host of user interactions.
abstract interface class GenUiContext {
  /// A stream of updates for the surfaces managed by this host.
  ///
  /// Implementations may choose to filter redundant updates. Consumers should
  /// rely on [getSurfaceNotifier] for the current state of a specific
  /// surface.
  Stream<GenUiUpdate> get surfaceUpdates;

  /// Returns a [ValueNotifier] for the surface with the given [surfaceId].
  ValueNotifier<UiDefinition?> getSurfaceNotifier(String surfaceId);

  /// The catalogs of UI components available to the AI.
  Iterable<Catalog> get catalogs;

  /// A map of data models for storing the UI state of each surface.
  Map<String, DataModel> get dataModels;

  /// The data model for storing the UI state for a given surface.
  DataModel dataModelForSurface(String surfaceId);

  /// A callback to handle an action from a surface.
  void handleUiEvent(UiEvent event);
}
