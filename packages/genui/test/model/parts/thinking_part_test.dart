// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:genui/src/model/parts/thinking.dart';

void main() {
  group('ThinkingPart', () {
    test('supports value equality', () {
      const part1 = ThinkingPart('reasoning');
      const part2 = ThinkingPart('reasoning');
      const part3 = ThinkingPart('other');

      expect(part1, equals(part2));
      expect(part1, isNot(equals(part3)));
      expect(part1.hashCode, equals(part2.hashCode));
    });

    test('toJson returns correct map', () {
      const part = ThinkingPart('reasoning');
      expect(part.toJson(), {'type': 'thinking', 'text': 'reasoning'});
    });

    test('fromJson creates correct instance', () {
      final json = {'type': 'thinking', 'text': 'reasoning'};
      final part = ThinkingPart.fromJson(json);
      expect(part, equals(const ThinkingPart('reasoning')));
    });

    test('round trip serialization', () {
      const original = ThinkingPart('reasoning');
      final Map<String, Object?> json = original.toJson();
      final reconstructed = ThinkingPart.fromJson(json);
      expect(reconstructed, equals(original));
    });
  });
}
