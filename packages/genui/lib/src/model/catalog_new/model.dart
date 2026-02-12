import 'package:json_schema_builder/json_schema_builder.dart';

import '../../../genui.dart';

class GenUiContext {
  final DataModel dataModel;

  GenUiContext({required this.dataModel});
}

class GenUiItemContext {
  final String componentId;
  final String surfaceId;
  final GenUiContext genui;

  GenUiItemContext({
    required this.componentId,
    required this.surfaceId,
    required this.genui,
  });
}

abstract class GenUiItemSchema<T extends GenUiItemDefinition> {
  final Schema schema;
  final String name;

  GenUiItemSchema({required this.schema, required this.name});

  T parse(Map<String, dynamic> json);
}

/// Defines the a GenUiItem constructed by AI.
abstract class GenUiItemDefinition {
  final GenUiItemContext context;

  GenUiItemDefinition({required this.context});
}

/// Handles data processing and state management of a [GenUiItem].
abstract class GenUiItemController<T extends GenUiItemSchema> {
  final GenUiItemContext context;
  final T schema;

  GenUiItemController({required this.context, required this.schema});
}

/// Implements rendering of a [GenUiItem].
abstract class GenUiItem<
  T extends GenUiItemSchema,
  C extends GenUiItemController<T>
> {
  final C controller;

  GenUiItem({required this.controller});
}

class GenUiCatalog {
  final List<GenUiItem> items;

  GenUiCatalog({required this.items});
}
