import 'package:flutter/foundation.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../../genui.dart';
import '../primitives/list_notifier.dart';

abstract class ComponentDecoder<NODE extends Object> {
  final Schema schema;

  ComponentDecoder({required this.schema});

  NODE decode(Object json, ComponentContext context);
}

class ComponentContext {
  DataModel model;
  ComponentAddress address;

  ComponentContext({required this.model, required this.address});

  ListValueNotifier<T?> listNotifier<T>(ValueRef<List<T>> ref) =>
      throw UnimplementedError();

  ValueNotifier<T?> valueNotifier<T>(ValueRef<T> ref) =>
      throw UnimplementedError();

  T? value<T>(ValueRef<T> ref) => ref.value(model);

  void dispose() {}
}

/// A reference to a value in the data model.
class ValueRef<T> {
  final String path;

  ValueRef(this.path);

  T? value(DataModel model) => throw UnimplementedError();
}
