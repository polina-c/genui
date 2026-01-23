// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

/// Utilities for parsing JSON blocks from text, commonly used when extracting
/// structured data from LLM text responses.
class JsonBlockParser {
  /// Parses the first valid JSON object or array found in [text].
  ///
  /// This method looks for JSON patterns, handling:
  /// - Markdown code blocks (e.g., ```json ... ```)
  /// - Raw JSON objects/arrays directly in text
  ///
  /// Returns `null` if no valid JSON is found.
  static Object? parseFirstJsonBlock(String text) {
    // 1. Try to find markdown JSON blocks first as they are most reliable
    final String? markdownBlock = _extractMarkdownJson(text);
    if (markdownBlock != null) {
      try {
        return jsonDecode(markdownBlock);
      } catch (_) {
        // Continue if markdown block contained invalid JSON
      }
    }

    // 2. Look for the first occurrence of '{' or '['
    final int firstBrace = text.indexOf('{');
    final int firstBracket = text.indexOf('[');

    var start = -1;
    if (firstBrace != -1 && firstBracket != -1) {
      start = firstBrace < firstBracket ? firstBrace : firstBracket;
    } else if (firstBrace != -1) {
      start = firstBrace;
    } else if (firstBracket != -1) {
      start = firstBracket;
    }

    if (start == -1) return null;

    // 3. Attempt to parse from the found start index
    // We'll try to find the balancing closing character.
    // This is a naive implementation; for robust streaming/partial parsing
    // a more complex state machine might be needed, but this suffices for
    // complete messages.
    final String input = text.substring(start);
    try {
      // Optimistic attempt: maybe the rest of the string is valid JSON?
      return jsonDecode(input);
    } catch (_) {
      // Fallback: Try to find the matching closing character manually
      // This helps if there is strict text *after* the JSON.
      final String? result = _extractBalancedJson(input);
      if (result != null) {
        try {
          return jsonDecode(result);
        } catch (_) {
          return null;
        }
      }
      return null;
    }
  }

  static String? _extractMarkdownJson(String text) {
    final regex = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```');
    final RegExpMatch? match = regex.firstMatch(text);
    return match?.group(1);
  }

  static String? _extractBalancedJson(String input) {
    if (input.isEmpty) return null;
    final String startChar = input[0];
    final String? endChar = startChar == '{'
        ? '}'
        : (startChar == '[' ? ']' : null);
    if (endChar == null) return null;

    var balance = 0;
    var inString = false;
    var isEscaped = false;

    for (var i = 0; i < input.length; i++) {
      final String char = input[i];

      if (isEscaped) {
        isEscaped = false;
        continue;
      }

      if (char == '\\') {
        isEscaped = true;
        continue;
      }

      if (char == '"') {
        inString = !inString;
        continue;
      }

      if (!inString) {
        if (char == startChar) {
          balance++;
        } else if (char == endChar) {
          balance--;
          if (balance == 0) {
            return input.substring(0, i + 1);
          }
        }
      }
    }
    return null;
  }

  /// Removes the first found JSON block from the text.
  static String stripJsonBlock(String text) {
    // 1. Try markdown block
    final markdownRegex = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```');
    if (markdownRegex.hasMatch(text)) {
      return text.replaceFirst(markdownRegex, '').trim();
    }

    // 2. Try balanced JSON
    // We reuse _extractBalancedJson to find the *string* content, then replace
    // it. This is slightly inefficient but safe.
    final String? jsonString = _extractBalancedJson(text);
    if (jsonString != null) {
      return text.replaceFirst(jsonString, '').trim();
    }

    return text;
  }
}
