// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../model/data_model.dart';
import '../primitives/logging.dart';
import 'functions.dart';

/// Parses and evaluates expressions in the A2UI `${expression}` format.
class ExpressionParser {
  ExpressionParser(this.context);

  final DataContext context;
  final FunctionRegistry _functions = FunctionRegistry();

  static const int _maxRecursionDepth = 10;

  /// Parses the input string and resolves any embedded expressions.
  ///
  /// If the string contains a single expression that encompasses the entire
  /// string (e.g. "${/foo}"), the return value may be of any type (not just
  /// String).
  ///
  /// If the string contains text mixed with expressions (e.g. "Value: ${/foo}"),
  /// the return value will always be a String.
  Object? parse(String input) {
    if (!input.contains(r'${')) {
      return input;
    }

    // Check for whole-string expression: "^${...}$" without other content?
    // But we need to handle escaping: "\${" is literal.
    // Let's rely on a tokenizer/parser approach.

    // Quick check: is it EXACTLY one expression?
    // We'll parse it fully. If result is single expression value, return it.
    // If it's mixed string parts, return concatenated string.

    return _parseStringWithInterpolations(input);
  }

  Object? _parseStringWithInterpolations(String input) {
    var i = 0;

    // We might have multiple parts: literals and expressions.
    // If we have exactly ONE part and it IS an expression, we return that
    // object.

    final parts = <Object?>[];

    while (i < input.length) {
      final int startIndex = input.indexOf(r'${', i);
      if (startIndex == -1) {
        // No more start tokens
        parts.add(input.substring(i));
        break;
      }

      // Check for escape
      if (startIndex > 0 && input[startIndex - 1] == r'\') {
        // Escaped: add "input[i...startIndex-1]" + "${"
        // Actually, we need to handle the escape char.
        // "abc\${def" -> "abc${def"
        parts.add(input.substring(i, startIndex - 1));
        parts.add(r'${'); // The literal characters
        i = startIndex + 2;
        continue;
      }

      // Add text before start
      if (startIndex > i) {
        parts.add(input.substring(i, startIndex));
      }

      // Parse expression content
      final (String content, int endIndex) = _extractExpressionContent(
        input,
        startIndex + 2,
      );
      if (endIndex == -1) {
        // Unclosed brace? Treat as literal?
        // Or throw?
        // Let's treat as literal rest of string if malformed, or just append.
        parts.add(input.substring(startIndex));
        break;
      }

      // Evaluate content
      final Object? value = _evaluateExpression(content, 0);
      parts.add(value);

      i = endIndex + 1; // Skip closing '}'
    }

    if (parts.length == 1 && parts[0] is! String) {
      return parts[0];
    }

    // If parts contain non-strings, we stringify them for interpolation (unless
    // it was single object return)
    return parts.map((e) => e?.toString() ?? '').join('');
  }

  (String, int) _extractExpressionContent(String input, int start) {
    var balance = 1;
    var i = start;
    while (i < input.length) {
      if (input[i] == r'{') {
        balance++;
      } else if (input[i] == r'}') {
        balance--;
        if (balance == 0) {
          return (input.substring(start, i), i);
        }
      }
      // Also handle quoted strings inside expression?
      // e.g. ${formatString('Hello } world')}
      // Yes, we need a smarter scanner if we support strings with braces
      // inside.
      // The spec says: "Function arguments must be literals (quoted strings,
      // numbers, booleans) or nested expressions"
      // We should handle quotes: ' or "
      if (input[i] == "'" || input[i] == '"') {
        // Skip string literal
        final String quote = input[i];
        i++;
        while (i < input.length) {
          if (input[i] == quote && input[i - 1] != r'\') {
            break;
          }
          i++;
        }
      }
      i++;
    }
    return ('', -1);
  }

  Object? _evaluateExpression(String content, int depth) {
    if (depth > _maxRecursionDepth) {
      genUiLogger.warning(
        'Max recursion depth reached in expression: $content',
      );
      return null;
    }

    // Content can be:
    // 1. Path: /foo/bar or relative/path
    // 2. Function call: funcName(arg1, arg2, ...)
    // 3. Nested expression.

    // Now we have content like "func(${path})".
    // We need to resolve nested parts first?
    // Or parse "func(...)" and arguments might contain ${...} tokens?

    // Actually, "content" might contain "${path}".
    // We should resolve any inner `${...}` sequences first.
    // RECURSIVE EVALUATION of the content string itself?

    // But wait, the content string IS the expression.
    // If it has `${...}` inside, it means we have mixed content?
    // "func(${path})" -> The argument to func is THE RESULT of ${path}.
    // So we need to parse the arguments.

    content = content.trim();

    // Is it a function call? name(...)
    final RegExpMatch? funcMatch = RegExp(
      r'^([a-zA-Z0-9_]+)\((.*)\)$',
    ).firstMatch(content);
    if (funcMatch != null) {
      final String funcName = funcMatch.group(1)!;
      final String argsStr = funcMatch.group(2)!;
      final List<Object?> args = _parseArgs(argsStr, depth + 1);
      return _functions.invoke(funcName, args);
    }

    // Is it a path? (starts with / or is just characters)
    // Note: Standard JSON Pointer starts with /. GenUI paths might correspond
    // to JSON pointers or relative.
    // If it starts with a quote, it's a literal? But this is inside ${...}.
    // Usually literal strings in ${...} are pointless unless as function args.
    // So distinct bare words are likely paths.

    // Check if it is an inner expression ${...}?
    // No, _extractExpressionContent extracted the content *between* the outer
    // ${ and }.
    // If we have `${path}`, content is `/path`.
    // If we have `func(${path})`, content is `func(${path})`.

    // Resolve inner expressions manually?
    // The args parser will handle this.

    // If it's just a path:
    return _resolvePath(content);
  }

  List<Object?> _parseArgs(String argsStr, int depth) {
    // Split by comma, respecting quotes and parentheses (and braces)
    final args = <Object?>[];
    var balanceParens = 0;
    var balanceBraces = 0;
    var inQuote = false;
    var quoteChar = '';

    var start = 0;
    for (var i = 0; i < argsStr.length; i++) {
      final String char = argsStr[i];

      if (inQuote) {
        if (char == quoteChar && (i == 0 || argsStr[i - 1] != r'\')) {
          inQuote = false;
        }
        continue;
      }

      if (char == "'" || char == '"') {
        inQuote = true;
        quoteChar = char;
        continue;
      }

      if (char == '(') balanceParens++;
      if (char == ')') balanceParens--;
      if (char == '{') balanceBraces++;
      if (char == '}') balanceBraces--;

      if (char == ',' && balanceParens == 0 && balanceBraces == 0) {
        args.add(_parseArg(argsStr.substring(start, i).trim(), depth));
        start = i + 1;
      }
    }
    args.add(_parseArg(argsStr.substring(start).trim(), depth));

    return args;
  }

  Object? _parseArg(String arg, int depth) {
    if (arg.isEmpty) return null;

    // If arg is wrapped in ${...}, evaluate it.
    if (arg.startsWith(r'${') && arg.endsWith(r'}')) {
      // Recurse!
      // Extract content
      final String content = arg.substring(2, arg.length - 1);
      return _evaluateExpression(content, depth);
    }

    // Literals
    if (arg.startsWith("'") && arg.endsWith("'")) {
      return arg.substring(1, arg.length - 1);
    }
    if (arg.startsWith('"') && arg.endsWith('"')) {
      return arg.substring(1, arg.length - 1);
    }

    if (arg == 'true') return true;
    if (arg == 'false') return false;
    if (arg == 'null') return null;

    final num? numVal = num.tryParse(arg);
    if (numVal != null) return numVal;

    // If it looks like a path but NOT wrapped in ${}, it is a string literal.
    // In function args: `formatString('template', /path)`
    // Paths in args should be wrapped in ${} if they are to be resolved.
    // Spec: "Function arguments must be literals ... or nested expressions
    // (e.g., `${...}`)"
    // Bare paths are NOT allowed in function args.

    return arg; // Return as string if unknown?
  }

  Object? _resolvePath(String pathStr) {
    // Remove leading/trailing whitespace
    pathStr = pathStr.trim();
    return context.getValue(DataPath(pathStr));
  }
}
