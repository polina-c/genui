import 'package:json_schema_builder/json_schema_builder.dart';

import '../../../../genui.dart';
import '../model.dart';

sealed class ChoicePickerDefinition extends ComponentDefinition {}

enum ChoicePickerOption {
  multipleSelectionNoLimit,
  multipleSelectionWithLimit,
  mutuallyExclusive,
}

final class ChoicePickerSchema extends ComponentSchema<ChoicePickerDefinition> {
  ChoicePickerSchema({
    List<ChoicePickerOption> allowedOptions = ChoicePickerOption.values,
  }) : super(_schema(allowedOptions));

  @override
  ChoicePickerDefinition parse(JsonMap json) {
    throw UnimplementedError();
  }
}

Schema _schema(List<ChoicePickerOption> allowedOptions) {
  return S.object(
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
      'filterable': S.boolean(
        description: 'Whether the options can be filtered by the user.',
      ),
      'checks': A2uiSchemas.checkable(),
    },
    required: ['component', 'options', 'value'],
  );
}

extension type _ChoicePickerData.fromMap(JsonMap _json) {
  Object? get label => _json['label'];
  String? get variant => _json['variant'] as String?;
  Object? get options => _json['options'];
  Object get value => _json['value'] as Object;
  String? get displayStyle => _json['displayStyle'] as String?;
  bool get filterable => _json['filterable'] as bool? ?? false;
  List<JsonMap>? get checks => (_json['checks'] as List?)?.cast<JsonMap>();
}
