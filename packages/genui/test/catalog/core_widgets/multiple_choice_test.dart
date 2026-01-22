// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';

void main() {
  testWidgets('MultipleChoice widget renders and handles changes', (
    WidgetTester tester,
  ) async {
    final processor = A2uiMessageProcessor(
      catalogs: [
        Catalog([
          CoreCatalogItems.multipleChoice,
          CoreCatalogItems.text,
        ], catalogId: 'test_catalog'),
      ],
    );
    const surfaceId = 'testSurface';
    final components = [
      const Component(
        id: 'root',
        type: 'MultipleChoice',
        properties: {
          'selections': {'path': '/mySelections'},
          'options': [
            {'label': 'Option 1', 'value': '1'},
            {'label': 'Option 2', 'value': '2'},
          ],
        },
      ),
    ];
    processor.handleMessage(
      UpdateComponents(surfaceId: surfaceId, components: components),
    );
    processor.handleMessage(
      const CreateSurface(surfaceId: surfaceId, catalogId: 'test_catalog'),
    );
    processor.dataModelForSurface(surfaceId).update(DataPath('/mySelections'), [
      '1',
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GenUiSurface(host: processor, surfaceId: surfaceId),
        ),
      ),
    );

    expect(find.text('Option 1'), findsOneWidget);
    expect(find.text('Option 2'), findsOneWidget);
    final CheckboxListTile checkbox1 = tester.widget<CheckboxListTile>(
      find.byType(CheckboxListTile).first,
    );
    expect(checkbox1.value, isTrue);
    final CheckboxListTile checkbox2 = tester.widget<CheckboxListTile>(
      find.byType(CheckboxListTile).last,
    );
    expect(checkbox2.value, isFalse);

    await tester.tap(find.text('Option 2'));
    expect(
      processor
          .dataModelForSurface(surfaceId)
          .getValue<List<Object?>>(DataPath('/mySelections')),
      ['1', '2'],
    );
  });

  testWidgets(
    'MultipleChoice widget handles non-integer maxAllowedSelections from JSON',
    (WidgetTester tester) async {
      final processor = A2uiMessageProcessor(
        catalogs: [
          Catalog([
            CoreCatalogItems.multipleChoice,
            CoreCatalogItems.text,
          ], catalogId: 'test_catalog'),
        ],
      );
      const surfaceId = 'testSurface';

      final components = [
        const Component(
          id: 'root',
          type: 'MultipleChoice',
          properties: {
            'selections': {'path': '/mySelections'},
            'maxAllowedSelections': 3.0,
            'options': [
              {'label': 'Option 1', 'value': '1'},
              {'label': 'Option 2', 'value': '2'},
            ],
          },
        ),
      ];

      processor.handleMessage(
        UpdateComponents(surfaceId: surfaceId, components: components),
      );
      processor.handleMessage(
        const CreateSurface(surfaceId: surfaceId, catalogId: 'test_catalog'),
      );

      processor
          .dataModelForSurface(surfaceId)
          .update(DataPath('/mySelections'), []);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GenUiSurface(host: processor, surfaceId: surfaceId),
          ),
        ),
      );

      // No exception was thrown.
    },
  );
}
