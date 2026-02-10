// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../functions/expression_parser.dart';

import '../primitives/logging.dart';
import '../primitives/simple_items.dart';

/// Represents a path in the data model, either absolute or relative.
@immutable
class DataPath {
  factory DataPath(String path) {
    if (path == _separator) return root;
    final List<String> segments = path
        .split(_separator)
        .where((s) => s.isNotEmpty)
        .toList();
    return DataPath._(segments, path.startsWith(_separator));
  }

  const DataPath._(this.segments, this.isAbsolute);

  final List<String> segments;
  final bool isAbsolute;

  static const String _separator = '/';
  static const DataPath root = DataPath._([], true);

  String get basename => segments.last;

  DataPath get dirname =>
      DataPath._(segments.sublist(0, segments.length - 1), isAbsolute);

  DataPath join(DataPath other) {
    if (other.isAbsolute) {
      return other;
    }
    return DataPath._([...segments, ...other.segments], isAbsolute);
  }

  bool startsWith(DataPath other) {
    if (other.segments.length > segments.length) {
      return false;
    }
    for (var i = 0; i < other.segments.length; i++) {
      if (segments[i] != other.segments[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  String toString() {
    final String path = segments.join(_separator);
    return isAbsolute ? '$_separator$path' : path;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DataPath &&
          runtimeType == other.runtimeType &&
          isAbsolute == other.isAbsolute &&
          listEquals(segments, other.segments);

  @override
  int get hashCode =>
      Object.hash(isAbsolute, const DeepCollectionEquality().hash(segments));
}

/// A contextual view of the main DataModel, used by widgets to resolve
/// relative and absolute paths.
class DataContext {
  DataContext(this._dataModel, String path) : path = DataPath(path);

  DataContext._(this._dataModel, this.path);

  final DataModel _dataModel;
  final DataPath path;

  /// Subscribes to a path or expression, resolving it against the current
  /// context.
  ValueNotifier<T?> subscribe<T>(String pathOrExpression) {
    if (pathOrExpression.contains(r'${')) {
      // Expressions require reactivity based on their dependencies.
      // Since `ExpressionParser` doesn't currently return dependencies, we use
      // a `_ComputedValueNotifier` that attempts to extract paths from the
      // expression.
      return _createComputedNotifier<T>(pathOrExpression);
    }

    final DataPath absolutePath = resolvePath(DataPath(pathOrExpression));
    return _dataModel.subscribe<T>(absolutePath);
  }

  /// Gets a value, resolving the path/expression against the current context.
  T? getValue<T>(String pathOrExpression) {
    if (pathOrExpression.contains(r'${')) {
      final parser = ExpressionParser(this);
      return parser.parse(pathOrExpression) as T?;
    }
    final DataPath absolutePath = resolvePath(DataPath(pathOrExpression));
    return _dataModel.getValue<T>(absolutePath);
  }

  /// Updates the data model, resolving the path against the current context.
  void update(String pathStr, Object? contents) {
    final DataPath absolutePath = resolvePath(DataPath(pathStr));
    _dataModel.update(absolutePath, contents);
  }

  /// Creates a new, nested DataContext for a child widget.
  /// Used by list/template widgets for their children.
  DataContext nested(String relativePath) {
    final DataPath newPath = resolvePath(DataPath(relativePath));
    return DataContext._(_dataModel, newPath);
  }

  DataPath resolvePath(DataPath pathToResolve) {
    if (pathToResolve.isAbsolute) {
      return pathToResolve;
    }
    return path.join(pathToResolve);
  }

  /// Resolves any expressions in the given value.
  Object? resolve(Object? value) {
    if (value is String) {
      return ExpressionParser(this).parse(value);
    }
    if (value is Map && value.containsKey('call')) {
      return ExpressionParser(this).evaluateFunctionCall(value as JsonMap);
    }
    return value;
  }

  ValueNotifier<T?> _createComputedNotifier<T>(String expression) {
    // Create a notifier that re-evaluates the expression when its dependencies
    // change.
    // Currently uses a heuristic to extract paths from the expression string.
    return _ComputedValueNotifier<T>(this, expression);
  }
}

class _ComputedValueNotifier<T> extends ValueNotifier<T?> {
  _ComputedValueNotifier(this.context, this.expression) : super(null) {
    initialEvaluation();
  }

  final DataContext context;
  final String expression;
  final List<VoidCallback> unsubscribers = [];

  void initialEvaluation() {
    // Parse the expression to find what paths it accesses.
    // This is a "best effort" reactive binding for now, using regex extraction.
    // TODO: Update ExpressionParser to report accessed paths for robust
    // dependency tracking.

    // Attempt to extract paths roughly
    final Set<DataPath> paths = extractPaths(expression);

    for (final path in paths) {
      final ValueNotifier<dynamic> notifier = context.subscribe(
        path.toString(),
      ); // Re-enter subscribe for raw paths
      void listener() => evaluate();
      notifier.addListener(listener);
      unsubscribers.add(() => notifier.removeListener(listener));
    }
    evaluate();
  }

  void evaluate() {
    final parser = ExpressionParser(context);
    final Object? result = parser.parse(expression);
    value = result as T?;
  }

  Set<DataPath> extractPaths(String expr) {
    final paths = <DataPath>{};
    // Basic extraction of ${path}.
    // TODO: Support function calls and nested expressions in dependency
    // extraction.
    final exp = RegExp(r'\$\{([^}]+)\}');
    for (final RegExpMatch match in exp.allMatches(expression)) {
      String content = match.group(1)!;
      content = content.trim();
      if (!content.contains('(')) {
        paths.add(context.resolvePath(DataPath(content)));
      }
    }
    return paths;
  }

  @override
  void dispose() {
    for (final VoidCallback unsub in unsubscribers) {
      unsub();
    }
    super.dispose();
  }
}

/// Manages the application's Object? data model and provides
/// a subscription-based mechanism for reactive UI updates.
class DataModel {
  JsonMap _data = {};
  final Map<DataPath, ValueNotifier<Object?>> _subscriptions = {};

  final List<VoidCallback> _cleanupCallbacks = [];

  /// The full contents of the data model.
  JsonMap get data => _data;

  /// Updates the data model at a specific absolute path and notifies all
  /// relevant subscribers.
  ///
  /// If [absolutePath] is null or root, the entire data model is replaced
  /// (if contents is a Map).
  void update(DataPath? absolutePath, Object? contents) {
    genUiLogger.info(
      'DataModel.update: path=$absolutePath, contents='
      '${const JsonEncoder.withIndent('  ').convert(contents)}',
    );

    if (absolutePath == null ||
        absolutePath.segments.isEmpty ||
        absolutePath == DataPath.root) {
      if (contents is Map) {
        _data = Map<String, Object?>.from(contents);
      } else {
        genUiLogger.warning(
          'DataModel.update: contents for root path is not a Map: $contents',
        );
        if (contents == null) {
          _data = {};
        }
      }
      _notifySubscribers(DataPath.root);
      return;
    }

    _updateValue(_data, absolutePath.segments, contents);
    _notifySubscribers(absolutePath);
  }

  /// Subscribes to a specific absolute path in the data model.
  ValueNotifier<T?> subscribe<T>(DataPath absolutePath) {
    genUiLogger.finer('DataModel.subscribe: path=$absolutePath');
    final T? initialValue = getValue<T>(absolutePath);
    if (_subscriptions.containsKey(absolutePath)) {
      final notifier = _subscriptions[absolutePath]! as ValueNotifier<T?>;

      return notifier;
    }
    final notifier = ValueNotifier<T?>(initialValue);
    _subscriptions[absolutePath] = notifier;
    return notifier;
  }

  final List<VoidCallback> _externalSubscriptions = [];

  /// Binds an external state [source] to a [path] in the DataModel.
  ///
  /// If [twoWay] is true, changes in the DataModel at [path] will also
  /// update the [source] (assuming [source] is a [ValueNotifier]).
  void bindExternalState<T>({
    required DataPath path,
    required ValueListenable<T> source,
    bool twoWay = false,
  }) {
    update(path, source.value);

    void onSourceChanged() {
      final T newValue = source.value;
      final T? currentValue = getValue<T>(path);
      if (currentValue != newValue) {
        update(path, newValue);
      }
    }

    source.addListener(onSourceChanged);
    _externalSubscriptions.add(() => source.removeListener(onSourceChanged));

    if (twoWay) {
      if (source is! ValueNotifier<T>) {
        genUiLogger.warning(
          'bindExternalState: twoWay is true but source is not a '
          'ValueNotifier.',
        );
      } else {
        final ValueNotifier<T> notifier = source;
        final ValueNotifier<T?> subscription = subscribe<T>(path);

        void onModelChanged() {
          final T? modelValue = subscription.value;
          if (modelValue != null && modelValue != notifier.value) {
            notifier.value = modelValue;
          }
        }

        subscription.addListener(onModelChanged);
        _externalSubscriptions.add(
          () => subscription.removeListener(onModelChanged),
        );
      }
    }
  }

  /// Disposes resources and bindings.
  void dispose() {
    for (final VoidCallback callback in _cleanupCallbacks) {
      callback();
    }
    _cleanupCallbacks.clear();

    for (final VoidCallback callback in _externalSubscriptions) {
      callback();
    }
    _externalSubscriptions.clear();

    for (final ValueNotifier<Object?> notifier in _subscriptions.values) {
      notifier.dispose();
    }
    _subscriptions.clear();
  }

  /// Retrieves a static, one-time value from the data model at the
  /// specified absolute path without creating a subscription.
  T? getValue<T>(DataPath absolutePath) {
    if (absolutePath == DataPath.root) {
      return _data as T?;
    }
    return _getValue(_data, absolutePath.segments) as T?;
  }

  /// Retrieves a static, one-time value from the data model at the
  /// specified path segments without creating a subscription.
  Object? _getValue(Object? current, List<String> segments) {
    if (segments.isEmpty) {
      return current;
    }

    final String segment = segments.first;
    final List<String> remaining = segments.sublist(1);

    if (current is Map) {
      return _getValue(current[segment], remaining);
    } else if (current is List) {
      final int? index = int.tryParse(segment);
      if (index != null && index >= 0 && index < current.length) {
        return _getValue(current[index], remaining);
      }
    }
    return null;
  }

  /// Updates the given path with a new value without creating a subscription.
  void _updateValue(Object? current, List<String> segments, Object? value) {
    if (segments.isEmpty) {
      return;
    }

    final String segment = segments.first;
    final List<String> remaining = segments.sublist(1);

    if (current is Map) {
      if (remaining.isEmpty) {
        if (value == null) {
          current.remove(segment);
        } else {
          current[segment] = value;
        }
        return;
      }

      Object? nextNode = current[segment];
      if (nextNode == null) {
        if (value == null) {
          return;
        }

        final String nextSegment = remaining.first;
        final isNextSegmentListIndex = int.tryParse(nextSegment) != null;
        nextNode = isNextSegmentListIndex ? <dynamic>[] : <String, dynamic>{};
        current[segment] = nextNode;
      }
      _updateValue(nextNode, remaining, value);
    } else if (current is List) {
      final int? index = int.tryParse(segment);
      if (index != null && index >= 0) {
        if (remaining.isEmpty) {
          if (index < current.length) {
            if (value == null) {
              current[index] = value;
            } else {
              current[index] = value;
            }
          } else if (index == current.length) {
            if (value != null) current.add(value);
          }
        } else {
          if (index < current.length) {
            _updateValue(current[index], remaining, value);
          } else if (index == current.length) {
            final String nextSegment = remaining.first;
            final isNextSegmentListIndex = int.tryParse(nextSegment) != null;
            final Object newItem = isNextSegmentListIndex
                ? <dynamic>[]
                : <String, dynamic>{};
            current.add(newItem);
            _updateValue(newItem, remaining, value);
          }
        }
      }
    }
  }

  void _notifySubscribers(DataPath path) {
    if (_subscriptions.containsKey(path)) {
      _subscriptions[path]!.value = getValue(path);
    }

    var parent = path;
    while (!parent.isAbsolute || parent.segments.isNotEmpty) {
      if (parent == DataPath.root) break;
      parent = parent.dirname;
      if (_subscriptions.containsKey(parent)) {
        _subscriptions[parent]!.value = getValue(parent);
      }
    }
    if (path != DataPath.root && _subscriptions.containsKey(DataPath.root)) {
      _subscriptions[DataPath.root]!.value = getValue(DataPath.root);
    }
    for (final DataPath p in _subscriptions.keys) {
      if (p.startsWith(path) && p != path) {
        _subscriptions[p]!.value = getValue(p);
      }
    }
  }
}
