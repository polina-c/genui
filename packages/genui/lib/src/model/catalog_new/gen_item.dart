abstract class GenItemDefinition {}

abstract class GenItemController {}

abstract class GenItem<
  D extends GenItemDefinition,
  C extends GenItemController
> {
  final D definition;
  final C controller;

  GenItem({required this.definition, required this.controller});
}
