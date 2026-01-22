// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../../core/widget_utilities.dart';
import '../../model/a2ui_schemas.dart';
import '../../model/catalog_item.dart';
import '../../model/data_model.dart';
import '../../primitives/simple_items.dart';

final _schema = S.object(
  properties: {
    'component': S.string(enumValues: ['DateTimeInput']),
    'value': A2uiSchemas.stringReference(
      description: 'The selected date and/or time.',
    ),
    'variant': S.string(
      description: 'The input type: date, time, or datetime.',
      enumValues: ['date', 'time', 'datetime'],
    ),
    'min': S.string(
      description:
          'The earliest selectable date (YYYY-MM-DD). Defaults to -9999-01-01.',
    ),
    'max': S.string(
      description:
          'The latest selectable date (YYYY-MM-DD). Defaults to 9999-12-31.',
    ),
  },
  required: ['component', 'value'],
);

extension type _DateTimeInputData.fromMap(JsonMap _json) {
  factory _DateTimeInputData({
    required JsonMap value,
    String? variant,
    String? min,
    String? max,
  }) => _DateTimeInputData.fromMap({
    'value': value,
    'variant': variant,
    'min': min,
    'max': max,
  });

  Object get value => _json['value'] as Object;
  String? get variant => _json['variant'] as String?;

  bool get enableDate {
    final String? v = variant;
    if (v == null) {
      if (_json.containsKey('enableDate')) return _json['enableDate'] as bool;
      return true;
    }
    return v == 'date' || v == 'datetime';
  }

  bool get enableTime {
    final String? v = variant;
    if (v == null) {
      if (_json.containsKey('enableTime')) return _json['enableTime'] as bool;
      return true;
    }
    return v == 'time' || v == 'datetime';
  }

  DateTime get firstDate =>
      DateTime.tryParse(
        (_json['min'] ?? _json['firstDate']) as String? ?? '',
      ) ??
      DateTime(-9999);
  DateTime get lastDate =>
      DateTime.tryParse((_json['max'] ?? _json['lastDate']) as String? ?? '') ??
      DateTime(9999, 12, 31);
}

/// A catalog item representing a Material Design date and/or time input field.
///
/// This widget displays a field that, when tapped, opens the native date and/or
/// time pickers. The selected value is stored as a string in the data model
/// path specified by the `value` parameter.
///
/// ## Parameters:
///
/// - `value`: The selected date and/or time, as a string.
/// - `enableDate`: Whether to allow the user to select a date. Defaults to
///   `true`.
/// - `enableTime`: Whether to allow the user to select a time. Defaults to
///   `true`.
/// - `outputFormat`: The format to use for the output string.
final dateTimeInput = CatalogItem(
  name: 'DateTimeInput',
  dataSchema: _schema,
  widgetBuilder: (itemContext) {
    final dateTimeInputData = _DateTimeInputData.fromMap(
      itemContext.data as JsonMap,
    );
    final ValueNotifier<String?> valueNotifier = itemContext.dataContext
        .subscribeToString(dateTimeInputData.value);

    return ValueListenableBuilder<String?>(
      valueListenable: valueNotifier,
      builder: (context, value, child) {
        final MaterialLocalizations localizations = MaterialLocalizations.of(
          context,
        );
        final String displayText = _getDisplayText(
          value,
          dateTimeInputData,
          localizations,
        );

        return ListTile(
          key: Key(itemContext.id),
          title: Text(displayText, key: Key('${itemContext.id}_text')),
          onTap: () => _handleTap(
            context: itemContext.buildContext,
            dataContext: itemContext.dataContext,
            data: dateTimeInputData,
            value: value,
          ),
        );
      },
    );
  },
  exampleData: [
    () => '''
      [
        {
          "id": "root",
          "component": "DateTimeInput",
          "value": {
            "path": "/myDateTime"
          }
        }
      ]
    ''',
    () => '''
       [
        {
          "id": "root",
          "component": "DateTimeInput",
          "value": {
            "path": "/myDate"
          },
          "enableTime": false
        }
      ]
    ''',
    () => '''
      [
        {
          "id": "root",
          "component": "DateTimeInput",
          "value": {
            "path": "/myTime"
          },
          "enableDate": false
        }
      ]
    ''',
  ],
);

Future<void> _handleTap({
  required BuildContext context,
  required DataContext dataContext,
  required _DateTimeInputData data,
  required String? value,
}) async {
  final Object val = data.value;
  final String? path = (val is Map && val.containsKey('path'))
      ? val['path'] as String?
      : null;

  if (path == null) {
    return;
  }

  final DateTime initialDate =
      DateTime.tryParse(value ?? '') ??
      DateTime.tryParse('1970-01-01T$value') ??
      DateTime.now();

  var resultDate = initialDate;
  var resultTime = TimeOfDay.fromDateTime(initialDate);

  if (data.enableDate) {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: data.firstDate,
      lastDate: data.lastDate,
    );
    if (pickedDate == null) return; // User cancelled.
    resultDate = pickedDate;
  }

  if (data.enableTime) {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (pickedTime == null) return; // User cancelled.
    resultTime = pickedTime;
  }

  final finalDateTime = DateTime(
    resultDate.year,
    resultDate.month,
    resultDate.day,
    data.enableTime ? resultTime.hour : 0,
    data.enableTime ? resultTime.minute : 0,
  );

  String formattedValue;

  if (data.enableDate && !data.enableTime) {
    formattedValue = finalDateTime.toIso8601String().split('T').first;
  } else if (!data.enableDate && data.enableTime) {
    final String hour = finalDateTime.hour.toString().padLeft(2, '0');
    final String minute = finalDateTime.minute.toString().padLeft(2, '0');
    formattedValue = '$hour:$minute:00';
  } else {
    // Both enabled (or both disabled, which shouldn't happen),
    // write full ISO string.
    formattedValue = finalDateTime.toIso8601String();
  }

  dataContext.update(DataPath(path), formattedValue);
}

String _getDisplayText(
  String? value,
  _DateTimeInputData data,
  MaterialLocalizations localizations,
) {
  String getPlaceholderText() {
    if (data.enableDate && data.enableTime) {
      return 'Select a date and time';
    } else if (data.enableDate) {
      return 'Select a date';
    } else if (data.enableTime) {
      return 'Select a time';
    }
    return 'Select a date/time';
  }

  DateTime? tryParseDateOrTime(String value) {
    return DateTime.tryParse(value) ?? DateTime.tryParse('1970-01-01T$value');
  }

  String formatDateTime(DateTime date) {
    final List<String> parts = [
      if (data.enableDate) localizations.formatFullDate(date),
      if (data.enableTime)
        localizations.formatTimeOfDay(TimeOfDay.fromDateTime(date)),
    ];
    return parts.join(' ');
  }

  if (value == null) {
    return getPlaceholderText();
  }

  final DateTime? date = tryParseDateOrTime(value);
  if (date == null) {
    return value;
  }

  return formatDateTime(date);
}
