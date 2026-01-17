// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';

import '../model.dart';

final class _Json {
  static const text = 'text';
}

/// A "thinking" part of a message, used by some models to show reasoning.
@immutable
final class ThinkingPart extends Part {
  static const type = 'Thinking';

  /// Creates a thinking part.
  const ThinkingPart(this.text);

  /// The thinking content.
  final String text;

  /// Creates a thinking part from a JSON map.
  factory ThinkingPart.fromJson(Map<String, Object?> json) {
    return ThinkingPart(json[_Json.text] as String);
  }

  @override
  Map<String, Object?> toJson() => {Part.typeKey: type, _Json.text: text};

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    return other is ThinkingPart && other.text == text;
  }

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'ThinkingPart(text: $text)';
}
