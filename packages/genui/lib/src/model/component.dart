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

  ListValueNotifier<T?> listNotifier<T>(ValueRefNode<List<T>> ref) =>
      throw UnimplementedError();

  ValueNotifier<T?> valueNotifier<T>(ValueRefNode<T> ref) =>
      throw UnimplementedError();

  T? value<T>(ValueRefNode<T> ref) => ref.value(model);

  void dispose() {}
}

/// A reference to a value in the data model.
class ValueRefNode<T> {
  final String path;

  ValueRefNode(this.path);

  T? value(DataModel model) => throw UnimplementedError();
}

/// Decoder for [ValueRefNode].
class ValueRefDecoder<T> extends ComponentDecoder<ValueRefNode<T>> {
  ValueRefDecoder() : super(schema: _schema);

  static final Schema _schema = A2uiSchemas.dataBindingSchema(
    description: 'The list of currently selected values (or single value).',
  );

  @override
  ValueRefNode<T> decode(Object json, ComponentContext context) {
    return ValueRefNode(json as String);
  }
}
