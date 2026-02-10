// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:genui/src/catalog/core_widgets/text.dart';

class FakeSurfaceContext implements SurfaceContext {
  FakeSurfaceContext({
    required this.surfaceId,
    required this.dataModel,
    required this.catalogs,
    required this.definition,
    required this.handleUiEventCallback,
  });

  @override
  final String surfaceId;

  @override
  final DataModel dataModel;

  @override
  final Iterable<Catalog> catalogs;

  @override
  final ValueNotifier<UiDefinition?> definition;

  final void Function(UiEvent) handleUiEventCallback;

  @override
  void handleUiEvent(UiEvent event) {
    handleUiEventCallback(event);
  }
}

void main() {
  group('SurfaceWidget', () {
    late DataModel dataModel;
    late FakeSurfaceContext surfaceContext;
    late Catalog catalog;

    setUp(() {
      dataModel = DataModel();
      catalog = Catalog([text], catalogId: 'test_catalog');
      surfaceContext = FakeSurfaceContext(
        surfaceId: 'test_surface',
        dataModel: dataModel,
        catalogs: [catalog],
        definition: ValueNotifier<UiDefinition?>(null),
        handleUiEventCallback: (event) {},
      );
    });

    testWidgets('renders empty when no definition', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Surface(genUiContext: surfaceContext)),
      );

      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('renders default builder when no definition', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Surface(
            genUiContext: surfaceContext,
            defaultBuilder: (context) => const Text('Loading...'),
          ),
        ),
      );

      expect(find.text('Loading...'), findsOneWidget);
    });

    testWidgets('renders root component', (tester) async {
      surfaceContext.definition.value = UiDefinition(
        surfaceId: 'test_surface',
        catalogId: 'test_catalog',
        components: {
          'root': const Component(
            id: 'root',
            type: 'Text',
            properties: {'text': 'Hello World'},
          ),
        },
      );

      await tester.pumpWidget(
        MaterialApp(home: Surface(genUiContext: surfaceContext)),
      );

      expect(find.text('Hello World'), findsOneWidget);
    });

    testWidgets('handles missing root component', (tester) async {
      surfaceContext.definition.value = UiDefinition(
        surfaceId: 'test_surface',
        catalogId: 'test_catalog',
        components: {
          'other': const Component(
            id: 'other',
            type: 'Text',
            properties: {'text': 'Hidden'},
          ),
        },
      );

      await tester.pumpWidget(
        MaterialApp(home: Surface(genUiContext: surfaceContext)),
      );

      expect(find.text('Hidden'), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('propogates data context', (tester) async {
      dataModel.update(DataPath('/message'), 'Dynamic Content');
      surfaceContext.definition.value = UiDefinition(
        surfaceId: 'test_surface',
        catalogId: 'test_catalog',
        components: {
          'root': const Component(
            id: 'root',
            type: 'Text',
            properties: {
              'text': {'path': '/message'},
            },
          ),
        },
      );

      await tester.pumpWidget(
        MaterialApp(home: Surface(genUiContext: surfaceContext)),
      );

      expect(find.text('Dynamic Content'), findsOneWidget);

      // Update data
      dataModel.update(DataPath('/message'), 'Updated Content');
      await tester.pump();

      expect(find.text('Updated Content'), findsOneWidget);
    });
  });
}
