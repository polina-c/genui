// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../../core/widget_utilities.dart';
import '../../model/a2ui_schemas.dart';
import '../../model/catalog_item.dart';
import '../../primitives/simple_items.dart';

final _schema = S.object(
  properties: {
    'component': S.string(enumValues: ['Tabs']),
    'tabs': S.list(
      items: S.object(
        properties: {
          'label': A2uiSchemas.stringReference(
            description: 'The label for the tab.',
          ),
          'content': A2uiSchemas.componentReference(
            description:
                'The content (widget ID) to display when this tab is active.',
          ),
        },
        required: ['label', 'content'],
      ),
    ),
  },
  required: ['component', 'tabs'],
);

extension type _TabsData.fromMap(JsonMap _json) {
  factory _TabsData({required List<JsonMap> tabs}) =>
      _TabsData.fromMap({'tabs': tabs});

  List<JsonMap> get tabs {
    return (_json['tabs'] as List? ?? _json['tabItems'] as List)
        .cast<JsonMap>();
  }
}

/// A catalog item representing a Material Design tab layout.
///
/// This widget displays a [TabBar] and a [TabBarView] to allow navigation
/// between different child components. Each tab in `tabItems` has a title and
/// a corresponding child component ID to display when selected.
///
/// ## Parameters:
///
/// - `tabItems`: A list of tabs to display, each with a `title` and a `child`
///   widget ID.
final tabs = CatalogItem(
  name: 'Tabs',
  dataSchema: _schema,
  widgetBuilder: (itemContext) {
    final tabsData = _TabsData.fromMap(itemContext.data as JsonMap);
    return DefaultTabController(
      length: tabsData.tabs.length,
      child: Column(
        children: [
          TabBar(
            tabs: tabsData.tabs.map((tabItem) {
              final Object? labelRef = tabItem['label'] ?? tabItem['title'];
              final ValueNotifier<String?> titleNotifier = itemContext
                  .dataContext
                  .subscribeToString(labelRef);
              return ValueListenableBuilder<String?>(
                valueListenable: titleNotifier,
                builder: (context, title, child) {
                  return Tab(text: title ?? '');
                },
              );
            }).toList(),
          ),
          Builder(
            builder: (context) {
              final TabController tabController = DefaultTabController.of(
                context,
              );
              return AnimatedBuilder(
                animation: tabController,
                builder: (context, child) {
                  final JsonMap tabItem = tabsData.tabs[tabController.index];
                  final contentId =
                      (tabItem['content'] ?? tabItem['child']) as String;
                  return itemContext.buildChild(contentId);
                },
              );
            },
          ),
        ],
      ),
    );
  },
  exampleData: [
    () => '''
      [
        {
          "id": "root",
          "component": "Tabs",
          "tabs": [
            {
              "label": "Overview",
              "content": "text1"
            },
            {
              "label": "Details",
              "content": "text2"
            }
          ]
        },
        {
          "id": "text1",
          "component": "Text",
          "text": "This is a short summary of the item."
        },
        {
          "id": "text2",
          "component": "Text",
          "text": "This is a much longer, more detailed description of the item, providing in-depth information and context. It can span multiple lines and include rich formatting if needed."
        }
      ]
    ''',
  ],
);
