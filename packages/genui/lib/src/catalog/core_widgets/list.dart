// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../../model/a2ui_schemas.dart';
import '../../model/catalog_item.dart';
import '../../model/data_model.dart';
import '../../primitives/simple_items.dart';
import 'widget_helpers.dart';

final _schema = S.object(
  properties: {
    'component': S.string(enumValues: ['List']),
    'children': A2uiSchemas.componentArrayReference(),
    'direction': S.string(enumValues: ['vertical', 'horizontal']),
    'align': S.string(enumValues: ['start', 'center', 'end', 'stretch']),
  },
  required: ['component', 'children'],
);

extension type _ListData.fromMap(JsonMap _json) {
  factory _ListData({
    required Object? children,
    String? direction,
    String? align,
  }) => _ListData.fromMap({
    'children': children,
    'direction': direction,
    'align': align,
  });

  Object? get children => _json['children'];
  String? get direction => _json['direction'] as String?;
  String? get align => _json['align'] as String?;
}

/// A catalog item representing a scrollable list of widgets.
///
/// This widget is analogous to Flutter's [ListView] widget. It can display
/// children in either a vertical or horizontal direction.
///
/// ## Parameters:
///
/// - `children`: A list of child widget IDs to display in the list.
/// - `direction`: The direction of the list. Can be `vertical` or `horizontal`.
///   Defaults to `vertical`.
/// - `align`: The alignment of children along the cross axis. One of `start`,
///   `center`, `end`, `stretch`.
final list = CatalogItem(
  name: 'List',
  dataSchema: _schema,
  widgetBuilder: (itemContext) {
    final listData = _ListData.fromMap(itemContext.data as JsonMap);
    final Axis direction = listData.direction == 'horizontal'
        ? Axis.horizontal
        : Axis.vertical;
    return ComponentChildrenBuilder(
      childrenData: listData.children,
      dataContext: itemContext.dataContext,
      buildChild: itemContext.buildChild,
      getComponent: itemContext.getComponent,
      explicitListBuilder: (childIds, buildChild, getComponent, dataContext) {
        return ListView(
          shrinkWrap: true,
          scrollDirection: direction,
          children: childIds.map((id) {
            final Widget child = buildChild(id, dataContext);
            return _applyAlignment(child, listData.align, direction);
          }).toList(),
        );
      },
      templateListWidgetBuilder:
          (context, Map<String, Object?> data, componentId, dataBinding) {
            final List<Object?> values = data.values.toList();
            final List<String> keys = data.keys.toList();
            return ListView.builder(
              shrinkWrap: true,
              scrollDirection: direction,
              itemCount: values.length,
              itemBuilder: (context, index) {
                final DataContext itemDataContext = itemContext.dataContext
                    .nested(DataPath('$dataBinding/${keys[index]}'));
                final Widget child = itemContext.buildChild(
                  componentId,
                  itemDataContext,
                );
                return _applyAlignment(child, listData.align, direction);
              },
            );
          },
    );
  },
  exampleData: [
    () => '''
      [
        {
          "id": "root",
          "component": "List",
          "children": [
            "text1",
            "text2"
          ]
        },
        {
          "id": "text1",
          "component": "Text",
          "text": "First"
        },
        {
          "id": "text2",
          "component": "Text",
          "text": "Second"
        }
      ]
    ''',
  ],
  isImplicitlyFlexible: true,
);

Widget _applyAlignment(Widget child, String? align, Axis direction) {
  if (align == null || align == 'stretch') {
    return child;
  }

  final AlignmentGeometry alignment = switch ((direction, align)) {
    (Axis.vertical, 'start') => Alignment.centerLeft,
    (Axis.vertical, 'center') => Alignment.center,
    (Axis.vertical, 'end') => Alignment.centerRight,
    (Axis.horizontal, 'start') => Alignment.topCenter,
    (Axis.horizontal, 'center') => Alignment.center,
    (Axis.horizontal, 'end') => Alignment.bottomCenter,
    _ => Alignment.center,
  };

  return Align(alignment: alignment, child: child);
}
