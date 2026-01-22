// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../../core/expression_parser.dart';
import '../../core/widget_utilities.dart';
import '../../model/a2ui_schemas.dart';
import '../../model/catalog_item.dart';
import '../../model/data_model.dart';
import '../../model/ui_models.dart';
import '../../primitives/simple_items.dart';

final _schema = S.object(
  description: 'A text input field.',
  properties: {
    'component': S.string(enumValues: ['TextField']),
    'text': A2uiSchemas.stringReference(
      // Note: The spec uses "value" usually for inputs, but spec says
      // "text" or "value"?
      // Spec says: "value": { "$ref": "DynamicString",
      // "description": "The value of the text field." } AND "label".
      description: 'The initial value of the text field.',
    ),
    'value': A2uiSchemas.stringReference(
      description: 'The value of the text field.',
    ),
    'label': A2uiSchemas.stringReference(),
    'variant': S.string(
      enumValues: ['shortText', 'longText', 'number', 'date', 'obscured'],
    ),
    'checks': S.list(items: S.object(properties: {'message': S.string()})),
    'validationRegexp': S.string(),
    'onSubmittedAction': A2uiSchemas.action(),
  },
);

extension type _TextFieldData.fromMap(JsonMap _json) {
  factory _TextFieldData({
    Object? value,
    Object? label,
    List<JsonMap>? checks,
    String? variant,
    String? validationRegexp,
    JsonMap? onSubmittedAction,
  }) => _TextFieldData.fromMap({
    'value': value,
    'label': label,
    'checks': checks,
    'variant': variant,
    'validationRegexp': validationRegexp,
    'onSubmittedAction': onSubmittedAction,
  });

  Object? get value => _json['value'] ?? _json['text'];
  Object? get label => _json['label'];
  List<JsonMap>? get checks => (_json['checks'] as List?)?.cast<JsonMap>();
  String? get variant =>
      _json['variant'] as String? ?? _json['textFieldType'] as String?;
  String? get validationRegexp => _json['validationRegexp'] as String?;
  JsonMap? get onSubmittedAction => _json['onSubmittedAction'] as JsonMap?;
}

class _TextField extends StatefulWidget {
  const _TextField({
    required this.initialValue,
    this.label,
    this.checks,
    this.parser,
    this.textFieldType,
    this.validationRegexp,
    required this.onChanged,
    required this.onSubmitted,
  });

  final String initialValue;
  final String? label;
  final List<JsonMap>? checks;
  final ExpressionParser? parser;
  final String? textFieldType;
  final String? validationRegexp;
  final void Function(String) onChanged;
  final void Function(String) onSubmitted;

  @override
  State<_TextField> createState() => _TextFieldState();
}

class _TextFieldState extends State<_TextField> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(_TextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue;
    }
    // Re-validate if checks changed?
    // Start with clean state or re-validate if value changed externally?
  }

  void _validate(String value) {
    if (widget.checks == null || widget.parser == null) {
      setState(() => _errorText = null);
      return;
    }

    for (final JsonMap check in widget.checks!) {
      // Each check is a CheckRule: LogicExpression + message
      // We evaluate the CheckRule as a LogicExpression.
      // But CheckRule schema says allOf [LogicExpression, {property: message}].
      // So the check object ITSELF is the logic expression (mixed in).
      // We pass the check object to evaluateLogic.
      // NOTE: evaluateLogic returns true if valid.
      // But we need to make sure we don't treat 'message' as part of logic.
      // evaluateLogic ignores unknown keys.
      final bool isValid = widget.parser!.evaluateLogic(check);
      if (!isValid) {
        setState(() {
          _errorText = check['message'] as String? ?? 'Invalid value';
        });
        return;
      }
    }
    setState(() => _errorText = null);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        labelText: widget.label,
        errorText: _errorText,
      ),
      obscureText: widget.textFieldType == 'obscured',
      keyboardType: switch (widget.textFieldType) {
        'number' => TextInputType.number,
        'longText' => TextInputType.multiline,
        'date' => TextInputType.datetime,
        _ => TextInputType.text,
      },
      onChanged: (val) {
        _validate(val);
        widget.onChanged(val);
      },
      onSubmitted: (val) {
        _validate(val);
        if (_errorText == null) {
          widget.onSubmitted(val);
        }
      },
    );
  }
}

/// A catalog item representing a Material Design text field.
///
/// This widget allows the user to enter and edit text. The `text` parameter
/// bidirectionally binds the field's content to the data model. This is
/// analogous to Flutter's [TextField] widget.
///
/// ## Parameters:
///
/// - `text`: The initial value of the text field.
/// - `label`: The text to display as the label for the text field.
/// - `textFieldType`: The type of text field. Can be `shortText`, `longText`,
///   `number`, `date`, or `obscured`.
/// - `validationRegexp`: A regular expression to validate the input.
/// - `onSubmittedAction`: The action to perform when the user submits the
///   text field.
final textField = CatalogItem(
  name: 'TextField',
  dataSchema: _schema,
  exampleData: [
    () => '''
      [
        {
          "id": "root",
          "component": "TextField",
          "text": "Hello World",
          "label": "Greeting"
        }
      ]
    ''',
    () => '''
      [
        {
          "id": "root",
          "component": "TextField",
          "text": "password123",
          "label": "Password",
          "textFieldType": "obscured"
        }
      ]
    ''',
  ],
  widgetBuilder: (itemContext) {
    final textFieldData = _TextFieldData.fromMap(itemContext.data as JsonMap);
    final Object? valueRef = textFieldData.value;
    final String? path = (valueRef is Map && valueRef.containsKey('path'))
        ? valueRef['path'] as String?
        : null;
    final ValueNotifier<String?> notifier = itemContext.dataContext
        .subscribeToString(valueRef);
    final ValueNotifier<String?> labelNotifier = itemContext.dataContext
        .subscribeToString(textFieldData.label);

    final parser = ExpressionParser(itemContext.dataContext);

    return ValueListenableBuilder<String?>(
      valueListenable: notifier,
      builder: (context, currentValue, child) {
        return ValueListenableBuilder(
          valueListenable: labelNotifier,
          builder: (context, label, child) {
            return _TextField(
              initialValue: currentValue ?? '',
              label: label,
              checks: textFieldData.checks,
              parser: parser,
              textFieldType: textFieldData.variant,
              validationRegexp: textFieldData.validationRegexp,
              onChanged: (newValue) {
                if (path != null) {
                  itemContext.dataContext.update(DataPath(path), newValue);
                }
              },
              onSubmitted: (newValue) {
                final JsonMap? actionData = textFieldData.onSubmittedAction;
                if (actionData == null) {
                  return;
                }

                if (actionData.containsKey('event')) {
                  final eventMap = actionData['event'] as JsonMap;
                  final actionName = eventMap['name'] as String;
                  final contextDefinition = eventMap['context'] as JsonMap?;
                  final JsonMap resolvedContext = resolveContext(
                    itemContext.dataContext,
                    contextDefinition,
                  );
                  itemContext.dispatchEvent(
                    UserActionEvent(
                      name: actionName,
                      sourceComponentId: itemContext.id,
                      context: resolvedContext,
                    ),
                  );
                } else if (actionData.containsKey('functionCall')) {
                  final funcMap = actionData['functionCall'] as JsonMap;
                  // Handle function call (e.g. closeModal)
                  final callName = funcMap['call'] as String;
                  if (callName == 'closeModal') {
                    Navigator.of(itemContext.buildContext).pop();
                    return;
                  }
                  // Evaluate generic function
                  parser.evaluateFunctionCall(funcMap);
                }
              },
            );
          },
        );
      },
    );
  },
);
