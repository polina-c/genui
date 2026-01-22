// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:json_schema_builder/json_schema_builder.dart';

import '../primitives/simple_items.dart';
import 'catalog.dart';

/// Provides a set of pre-defined, reusable schema objects for common
/// A2UI patterns, simplifying the creation of CatalogItem definitions.
class A2uiSchemas {
  /// Defines the usage of the function registry.
  static Schema clientFunctions() {
    return S.list(
      title: 'A2UI Client Functions',
      description: 'A list of functions available for use in the client.',
      items: S.combined(
        oneOf: [
          _requiredFunction(),
          _regexFunction(),
          _lengthFunction(),
          _numericFunction(),
          _emailFunction(),
          _formatStringFunction(),
          _formatNumberFunction(),
          _formatCurrencyFunction(),
          _formatDateFunction(),
        ],
      ),
    );
  }

  static Schema _functionDefinition({
    required String name,
    required String description,
    required String returnType,
    required Schema parameters,
  }) {
    return S.object(
      properties: {
        'name': S.string(constValue: name),
        'description': S.string(constValue: description),
        'returnType': S.string(constValue: returnType),
        'parameters': parameters,
      },
      required: ['name', 'description', 'returnType', 'parameters'],
    );
  }

  static Schema _requiredFunction() {
    return _functionDefinition(
      name: 'required',
      description: 'Checks that the value is not null, undefined, or empty.',
      returnType: 'boolean',
      parameters: S.list(
        items: S.combined(anyOf: [S.any()]), // DynamicValue reference
        minItems: 1,
      ),
    );
  }

  static Schema _regexFunction() {
    return _functionDefinition(
      name: 'regex',
      description: 'Checks that the value matches a regular expression string.',
      returnType: 'boolean',
      parameters: S.list(
        items: S.combined(
          oneOf: [
            S.any(), // DynamicValue
            S.string(description: 'The regex pattern to match against.'),
          ],
        ),
        minItems: 2,
      ),
    );
  }

  static Schema _lengthFunction() {
    return _functionDefinition(
      name: 'length',
      description: 'Checks string length constraints.',
      returnType: 'boolean',
      parameters: S.list(
        items: S.combined(
          oneOf: [
            S.any(), // DynamicValue
            S.combined(
              allOf: [
                S.object(
                  properties: {
                    'min': S.integer(
                      minimum: 0,
                      description: 'The minimum allowed length.',
                    ),
                    'max': S.integer(
                      minimum: 0,
                      description: 'The maximum allowed length.',
                    ),
                  },
                ),
                S.combined(
                  anyOf: [
                    S.object(required: ['min']),
                    S.object(required: ['max']),
                  ],
                ),
              ],
            ),
          ],
        ),
        minItems: 2,
      ),
    );
  }

  static Schema _numericFunction() {
    return _functionDefinition(
      name: 'numeric',
      description: 'Checks numeric range constraints.',
      returnType: 'boolean',
      parameters: S.list(
        items: S.combined(
          oneOf: [
            S.any(), // DynamicValue
            S.combined(
              allOf: [
                S.object(
                  properties: {
                    'min': S.number(description: 'The minimum allowed value.'),
                    'max': S.number(description: 'The maximum allowed value.'),
                  },
                ),
                S.combined(
                  anyOf: [
                    S.object(required: ['min']),
                    S.object(required: ['max']),
                  ],
                ),
              ],
            ),
          ],
        ),
        minItems: 2,
      ),
    );
  }

  static Schema _emailFunction() {
    return _functionDefinition(
      name: 'email',
      description: 'Checks that the value is a valid email address.',
      returnType: 'boolean',
      parameters: S.list(
        items: S.combined(anyOf: [S.any()]), // DynamicValue
        minItems: 1,
      ),
    );
  }

  static Schema _formatStringFunction() {
    return _functionDefinition(
      name: 'formatString',
      description:
          '''Performs string interpolation of data model values and other functions.''',
      returnType: 'string',
      // Note: json_schema_builder doesn't support 'additionalItems' or tuple
      // validation easily in S.list. We use a generic list of DynamicValue for
      // now.
      parameters: S.list(
        items: S.any(), // DynamicValue
        minItems: 1,
      ),
    );
  }

  static Schema _formatNumberFunction() {
    return _functionDefinition(
      name: 'formatNumber',
      description:
          'Formats a number with the specified grouping and decimal precision.',
      returnType: 'string',
      parameters: S.list(
        items: S.combined(
          oneOf: [
            S.number(description: 'The number to format.'), // DynamicNumber
            S.number(
              description: 'Optional. The number of decimal places to show.',
            ), // DynamicNumber
            S.boolean(
              description:
                  '''Optional. If true, uses locale-specific grouping separators.''',
            ), // DynamicBoolean
          ],
        ),
        minItems: 1,
      ),
    );
  }

  static Schema _formatCurrencyFunction() {
    return _functionDefinition(
      name: 'formatCurrency',
      description: 'Formats a number as a currency string.',
      returnType: 'string',
      parameters: S.list(
        items: S.combined(
          oneOf: [
            S.number(description: 'The monetary amount.'), // DynamicNumber
            S.string(
              description: "The ISO 4217 currency code (e.g., 'USD', 'EUR').",
            ), // DynamicString
          ],
        ),
        minItems: 2,
      ),
    );
  }

  static Schema _formatDateFunction() {
    return _functionDefinition(
      name: 'formatDate',
      description: 'Formats a timestamp into a string using a pattern.',
      returnType: 'string',
      parameters: S.list(
        items: S.combined(
          oneOf: [
            S.string(
              description: 'The ISO 8601 timestamp string.',
            ), // DynamicString
            S.string(
              description: 'The format pattern (e.g. "MM/dd/yyyy").',
            ), // DynamicString
          ],
        ),
        minItems: 2,
      ),
    );
  }

  /// Schema for a function call.
  static Schema functionCall() => S.object(
    properties: {
      'func': S.string(description: 'The name of the function to call.'),
      'args': S.list(
        description: 'Arguments to pass to the function.',
        items: S.any(),
      ),
    },
    required: ['func', 'args'],
  );

  /// Schema for a value that can be either a literal string or a
  /// data-bound path to a string in the DataModel.
  static Schema stringReference({
    String? description,
    List<String>? enumValues,
  }) {
    final literal = S.string(
      description: 'A literal string value.',
      enumValues: enumValues,
    );
    final verboseLiteral = S.object(
      properties: {'literalString': S.string(enumValues: enumValues)},
      required: ['literalString'],
    );
    final Schema binding = dataBindingSchema(
      description: 'A path to a string.',
    );
    final Schema function = functionCall();
    return S.combined(
      oneOf: [literal, verboseLiteral, binding, function],
      description: description,
    );
  }

  /// Schema for a value that can be either a literal number or a
  /// data-bound path to a number in the DataModel.
  static Schema numberReference({String? description}) {
    final literal = S.number(description: 'A literal number value.');
    final verboseLiteral = S.object(
      properties: {'literalNumber': S.number()},
      required: ['literalNumber'],
    );
    final Schema binding = dataBindingSchema(
      description: 'A path to a number.',
    );
    final Schema function = functionCall();
    return S.combined(
      oneOf: [literal, verboseLiteral, binding, function],
      description: description,
    );
  }

  /// Schema for a value that can be either a literal boolean or a
  /// data-bound path to a boolean in the DataModel.
  static Schema booleanReference({String? description}) {
    final literal = S.boolean(description: 'A literal boolean value.');
    final verboseLiteral = S.object(
      properties: {'literalBoolean': S.boolean()},
      required: ['literalBoolean'],
    );
    final Schema binding = dataBindingSchema(
      description: 'A path to a boolean.',
    );
    final Schema function = functionCall();
    return S.combined(
      oneOf: [literal, verboseLiteral, binding, function],
      description: description,
    );
  }

  /// Helper to create a DataBinding schema.
  static Schema dataBindingSchema({String? description}) {
    return S.object(
      description: description,
      properties: {
        'path': S.string(
          description: 'A relative or absolute path in the data model.',
        ),
      },
      required: ['path'],
    );
  }

  /// Schema for a property that holds a list of child components,
  /// either as an explicit list of IDs or a data-bound template.
  static Schema componentArrayReference({String? description}) {
    // In v0.9, children are usually just a list of IDs (strings).
    // Templates are handled differently (e.g. List component).
    // For now, core support is a list of strings (IDs).
    // If we support templates inline, we'd need a complex schema.
    // Spec v0.9 says "children": ["id1", "id2"] OR template object.
    // "ChildList" in common_types.json.

    final idList = S.list(items: S.string(description: 'Component ID'));

    // We can add template support if needed, matching common_types.json For
    // Phase 1 implementation plan, it mostly talks about flattening components.
    // We'll stick to List<String> for now as per `common_types.json` "simple"
    // list. A2ui v0.9 allows ChildList to be a template too.
    return idList;
  }

  /// Schema for a user-initiated action.
  static Schema action({String? description}) => S.object(
    description: description,
    properties: {
      'name': S.string(),
      'context': S.object(
        description: 'Arbitrary context data to send with the action.',
        additionalProperties: true,
      ),
    },
    required: ['name'],
  );

  /// Schema for a value that can be either a literal array of strings or a
  /// data-bound path to an array of strings.
  static Schema stringArrayReference({String? description}) {
    final literal = S.list(items: S.string());
    final verboseLiteral = S.object(
      properties: {'literalArray': S.list(items: S.string())},
      required: ['literalArray'],
    );
    final Schema binding = dataBindingSchema(
      description: 'A path to a string list.',
    );
    final Schema function = functionCall();
    return S.combined(
      oneOf: [literal, verboseLiteral, binding, function],
      description: description,
    );
  }

  /// Schema for a createSurface message (v0.9).
  static Schema createSurfaceSchema() => S.object(
    properties: {
      surfaceIdKey: S.string(description: 'The unique ID for the surface.'),
      'catalogId': S.string(description: 'The URI of the component catalog.'),
      'theme': S.object(
        description: 'Theme parameters for the surface.',
        additionalProperties: true,
      ),
      'attachDataModel': S.boolean(
        description:
            'Whether to attach the data model to every client request.',
      ),
    },
    required: [surfaceIdKey, 'catalogId'],
  );

  /// Schema for a deleteSurface message.
  static Schema deleteSurfaceSchema() => S.object(
    properties: {surfaceIdKey: S.string()},
    required: [surfaceIdKey],
  );

  /// Schema for a updateDataModel message.
  static Schema updateDataModelSchema() => S.object(
    properties: {
      surfaceIdKey: S.string(),
      'path': S.combined(type: JsonType.string, defaultValue: '/'),
      'value': S.any(
        description:
            'The new value to write to the data model. If null/omitted, the key is removed.',
      ),
    },
    required: [surfaceIdKey],
  );

  /// Schema for a component reference (ID).
  static Schema componentReference({String? description}) {
    return S.string(description: description ?? 'The ID of a component.');
  }

  /// Schema for a updateComponents message (v0.9).
  static Schema updateComponentsSchema(Catalog catalog) {
    // Collect specific component schemas from the catalog.
    // We assume catalog items have updated v0.9 schemas (flattened).
    final List<Schema> componentSchemas = catalog.items
        .map((item) => item.dataSchema)
        .toList();

    return S.object(
      properties: {
        surfaceIdKey: S.string(
          description: 'The unique identifier for the UI surface.',
        ),
        'components': S.list(
          description: 'A flat list of component definitions.',
          minItems: 1,
          items: componentSchemas.isEmpty
              ? S.object(description: 'No components in catalog.')
              : S.combined(
                  oneOf: componentSchemas,
                  description:
                      'Must match one of the component definitions in the '
                      'catalog.',
                ),
        ),
      },
      required: [surfaceIdKey, 'components'],
    );
  }

  // Backward compatibility alias if needed, or removable.
  // We remove the old methods to enforce v0.9.
  static Schema beginRenderingSchema() => createSurfaceSchema();
  static Schema beginRenderingSchemaNoCatalogId() => S.object(
    properties: {
      surfaceIdKey: S.string(description: 'The unique ID for the surface.'),
      'theme': S.object(
        description: 'Theme parameters for the surface.',
        additionalProperties: true,
      ),
      'attachDataModel': S.boolean(
        description:
            'Whether to attach the data model to every client request.',
      ),
    },
    required: [surfaceIdKey],
  );
  static Schema surfaceDeletionSchema() => deleteSurfaceSchema();
  static Schema dataModelUpdateSchema() => updateDataModelSchema();
  static Schema surfaceUpdateSchema(Catalog catalog) =>
      updateComponentsSchema(catalog);
}
