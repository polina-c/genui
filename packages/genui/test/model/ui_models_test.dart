// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:genui/src/model/tools.dart'; // For surfaceIdKey
import 'package:genui/src/model/ui_models.dart';
import 'package:test/test.dart';

void main() {
  group('UiDefinition', () {
    test('toJson returns correct map', () {
      final uiDef = UiDefinition(
        surfaceId: 'testSurface',
        rootComponentId: 'root1',
        catalogId: 'cat1',
        components: {
          'comp1': const Component(
            id: 'comp1',
            componentProperties: {'type': 'text'},
          ),
        },
        styles: {'color': 'red'},
      );

      final json = uiDef.toJson();

      expect(json[surfaceIdKey], 'testSurface');
      expect(json['rootComponentId'], 'root1');
      expect(json['catalogId'], 'cat1');
      expect(json['components'], isA<Map<String, Object?>>());
      expect(
        (json['components'] as Map<String, Object?>)['comp1'],
        isA<Map<String, Object?>>(),
      );
      expect(json['styles'], {'color': 'red'});
    });

    test('fromJson creates correct instance', () {
      final json = {
        surfaceIdKey: 'testSurface',
        'rootComponentId': 'root1',
        'catalogId': 'cat1',
        'components': {
          'comp1': {
            'id': 'comp1',
            'component': {'type': 'text'},
          },
        },
        'styles': {'color': 'red'},
      };

      final uiDef = UiDefinition.fromJson(json);

      expect(uiDef.surfaceId, 'testSurface');
      expect(uiDef.rootComponentId, 'root1');
      expect(uiDef.catalogId, 'cat1');
      expect(uiDef.components, hasLength(1));
      expect(uiDef.components['comp1']?.id, 'comp1');
      expect(uiDef.styles, {'color': 'red'});
    });

    test('round trip serialization', () {
      final original = UiDefinition(
        surfaceId: 'testSurface',
        rootComponentId: 'root1',
        catalogId: 'cat1',
        components: {
          'comp1': const Component(
            id: 'comp1',
            componentProperties: {'type': 'text'},
          ),
        },
        styles: {'color': 'red'},
      );

      final json = original.toJson();
      final reconstructed = UiDefinition.fromJson(json);

      expect(reconstructed.surfaceId, original.surfaceId);
      expect(reconstructed.rootComponentId, original.rootComponentId);
      expect(reconstructed.catalogId, original.catalogId);
      expect(reconstructed.styles, original.styles);
      // Component equality might need to be checked carefully or just check ids/props
      expect(reconstructed.components.keys, original.components.keys);
    });

    test('handles missing optional fields', () {
      final json = <String, Object?>{surfaceIdKey: 'testSurface'};

      final uiDef = UiDefinition.fromJson(json);

      expect(uiDef.surfaceId, 'testSurface');
      expect(uiDef.rootComponentId, isNull);
      expect(uiDef.catalogId, isNull);
      expect(uiDef.components, isEmpty);
      expect(uiDef.styles, isNull);
    });
  });
}
