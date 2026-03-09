import 'package:flutter/foundation.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../primitives/list_notifier.dart';

abstract class ComponentDecoder<NODE extends Object> {
  final Schema schema;

  ComponentDecoder({required this.schema});

  NODE decode(Object json, ComponentContext context);
}

class ComponentContext {
  ListValueNotifier<T> listNotifier<T>(ValueRef<List<T>> ref) =>
      throw UnimplementedError();

  ValueNotifier<T> valueNotifier<T>(ValueRef<T> ref) =>
      throw UnimplementedError();
}

/// A reference to a value in the data model.
class ValueRef<T> {
  final String path;

  ValueRef({required this.path});
}
