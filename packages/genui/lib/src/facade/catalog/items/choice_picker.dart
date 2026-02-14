import 'package:json_schema_builder/json_schema_builder.dart';

import '../../../../genui.dart';
import '../model.dart';

final class ChoicePickerSchema extends ComponentSchema<ChoicePickerDefinition> {
  ChoicePickerSchema() : super(_schema);

  @override
  ChoicePickerDefinition parse(JsonMap json) {
    throw UnimplementedError();
  }
}

sealed class ChoicePickerDefinition extends ComponentDefinition {
  final Map<String, String> options;

  ChoicePickerDefinition({required this.options});
}

final class MultipleChoiceDefinition extends ChoicePickerDefinition {
  final String? selection;

  MultipleChoiceDefinition({required this.selection, required super.options});
}

final class ExclusiveChoiceDefinition extends ChoicePickerDefinition {
  final List<String> selection;

  ExclusiveChoiceDefinition({required this.selection, required super.options});
}

Schema _schema = S.object(
  properties: {
    'component': S.string(enumValues: ['ChoicePicker']),
    'label': S.string(description: 'The label for the group of options.'),
    'options': S.list(
      description: 'The list of available options to choose from.',
      items: S.object(
        properties: {
          'label': S.string(
            description: 'The text to display for this option.',
          ),
          'value': S.string(
            description: 'The value associated with this option.',
          ),
        },
        required: ['label', 'value'],
      ),
    ),
    'value': S.combined(
      oneOf: [
        S.string(),
        S.list(items: S.string()),
        A2uiSchemas.dataBindingSchema(),
        A2uiSchemas.functionCall(),
      ],
      description: 'The list of currently selected values (or single value).',
    ),
    'variant': S.string(
      description:
          'A hint for how the choice picker should be displayed and behave.',
      enumValues: ['multipleSelection', 'mutuallyExclusive'],
    ),
  },
  required: ['component', 'options', 'value'],
);

extension type _ChoicePickerData.fromMap(JsonMap _json) {
  Object? get label => _json['label'];
  String? get variant => _json['variant'] as String?;
  Object? get options => _json['options'];
  Object get value => _json['value'] as Object;
  String? get displayStyle => _json['displayStyle'] as String?;
  bool get filterable => _json['filterable'] as bool? ?? false;
  List<JsonMap>? get checks => (_json['checks'] as List?)?.cast<JsonMap>();
}
