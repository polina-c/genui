abstract class GenItemSchema {}

class GenCatalog {
  final List<GenItemDefinition> items;

  GenCatalog({required this.items});
}

abstract class GenItemDefinition<S extends GenItemSchema> {
  final S schema;

  GenItemDefinition({required this.schema});
}

/// Handles data processing and state management for a GenItem.
abstract class GenItemController {}

abstract class GenItem<
  D extends GenItemDefinition,
  C extends GenItemController
> {
  final D definition;
  final C controller;

  GenItem({required this.definition, required this.controller});
}
