// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:json_schema_builder/json_schema_builder.dart';

import '../primitives/simple_items.dart';
import 'catalog.dart';

/// Provides a set of pre-defined, reusable schema objects for common
/// A2UI patterns, simplifying the creation of CatalogItem definitions.
class A2uiSchemas {
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
    final Schema binding = _dataBindingSchema(
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
    final Schema binding = _dataBindingSchema(
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
    final Schema binding = _dataBindingSchema(
      description: 'A path to a boolean.',
    );
    final Schema function = functionCall();
    return S.combined(
      oneOf: [literal, verboseLiteral, binding, function],
      description: description,
    );
  }

  /// Helper to create a DataBinding schema.
  static Schema _dataBindingSchema({String? description}) {
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
    final Schema binding = _dataBindingSchema(
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
