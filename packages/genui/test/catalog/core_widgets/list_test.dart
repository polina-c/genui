// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';

void main() {
  testWidgets('List widget renders children', (WidgetTester tester) async {
    final manager = SurfaceController(
      catalogs: [
        Catalog([
          CoreCatalogItems.list,
          CoreCatalogItems.text,
        ], catalogId: 'test_catalog'),
      ],
    );
    const surfaceId = 'testSurface';
    final components = [
      const Component(
        id: 'root',
        type: 'List',
        properties: {
          'children': {
            'explicitList': ['text1', 'text2'],
          },
        },
      ),
      const Component(id: 'text1', type: 'Text', properties: {'text': 'First'}),
      const Component(
        id: 'text2',
        type: 'Text',
        properties: {'text': 'Second'},
      ),
    ];
    manager.handleMessage(
      UpdateComponents(surfaceId: surfaceId, components: components),
    );
    manager.handleMessage(
      const CreateSurface(surfaceId: surfaceId, catalogId: 'test_catalog'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Surface(genUiContext: manager.contextFor(surfaceId)),
        ),
      ),
    );

    expect(find.text('Second'), findsOneWidget);
  });

  testWidgets('List widget respects align property', (
    WidgetTester tester,
  ) async {
    final manager = SurfaceController(
      catalogs: [
        Catalog([
          CoreCatalogItems.list,
          CoreCatalogItems.text,
        ], catalogId: 'test_catalog'),
      ],
    );
    const surfaceId = 'testSurface';
    final components = [
      const Component(
        id: 'root',
        type: 'List',
        properties: {
          'align': 'center',
          'children': {
            'explicitList': ['text1'],
          },
        },
      ),
      const Component(
        id: 'text1',
        type: 'Text',
        properties: {'text': 'Center'},
      ),
    ];
    manager.handleMessage(
      UpdateComponents(surfaceId: surfaceId, components: components),
    );
    manager.handleMessage(
      const CreateSurface(surfaceId: surfaceId, catalogId: 'test_catalog'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Surface(genUiContext: manager.contextFor(surfaceId)),
        ),
      ),
    );

    expect(find.text('Center'), findsOneWidget);
    // Verify alignment logic by finding the Align widget wrapping the child.
    final Align alignWidget = tester.widget<Align>(
      find
          .ancestor(of: find.text('Center'), matching: find.byType(Align))
          .first,
    );
    expect(alignWidget.alignment, Alignment.center);
  });
}
