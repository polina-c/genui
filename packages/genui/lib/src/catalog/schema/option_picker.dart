import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:meta/meta.dart';

import '../../../genui.dart';
import '../../model/component.dart';

@immutable
final class OptionNode {
  OptionNode({required this.label, required this.value});

  final String label;
  final String value;
}

@immutable
final class OptionDecoder extends ComponentDecoder<OptionNode> {
  OptionDecoder() : super(schema: _schema);

  static final _schema = S.object(
    properties: {
      'label': S.string(description: 'The text to display for this option.'),
      'value': S.string(description: 'The value associated with this option.'),
    },
    required: ['label', 'value'],
  );

  @override
  OptionNode decode(Object? json, ComponentContext context) {
    final map = json as Map<String, Object?>;
    return OptionNode(
      label: map['label'] as String,
      value: map['value'] as String,
    );
  }

  JsonMap? create(String label, String value) {
    return {'label': label, 'value': value};
  }
}

@immutable
final class OptionsDecoder extends ComponentDecoder<OptionsNode> {
  OptionsDecoder() : super(schema: _schema);

  static final _schema = S.list(items: OptionDecoder().schema);

  @override
  OptionsNode decode(Object? json, ComponentContext context) {
    final list = json as List<Object?>;
    return OptionsNode(
      options: list.map((e) => OptionDecoder().decode(e, context)).toList(),
    );
  }
}

@immutable
final class OptionsNode {
  OptionsNode({required this.options});

  final List<OptionNode> options;
}

@immutable
sealed class OptionPickerNode {
  OptionPickerNode({required this.options});

  final List<OptionNode> options;
}

@immutable
final class OptionsPickerDecoder extends ComponentDecoder<OptionPickerNode> {
  OptionsPickerDecoder() : super(schema: _schema);

  static final _schema = throw UnimplementedError();

  @override
  OptionPickerNode decode(Object? json, ComponentContext context) {
    final map = json as Map<String, Object?>;
    if (map['variant'] == 'multipleSelection') {
      return MultipleOptionPickerNode(
        options: OptionsDecoder().decode(json['options'], context).options,
        selections: context.listNotifier(
          ValueRef<Iterable<String>>(json['selection']),
        ),
      );
    } else {
      return SingleOptionPickerNode(
        options: OptionsDecoder().decode(json['options'], context).options,
        selection: context.valueNotifier(ValueRef(json['selection'])),
      );
    }
  }
}

@immutable
final class SingleOptionPickerNode extends OptionPickerNode {
  SingleOptionPickerNode({required super.options, required this.selection});

  final ValueNotifier<String?> selection;
}

@immutable
final class MultipleOptionPickerNode extends OptionPickerNode {
  MultipleOptionPickerNode({
    required super.options,
    required this.selections,
    this.maxSelections,
  });

  final ListNotifier<List<String>> selections;
  final int? maxSelections;
}
