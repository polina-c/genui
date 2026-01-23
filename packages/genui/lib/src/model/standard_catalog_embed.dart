// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// A static container for the standard catalog and rules, embedded to avoid
/// file I/O and duplication across providers.
class StandardCatalogEmbed {
  /// The text content of standard_catalog_rules.txt.
  static const String standardCatalogRules = r'''
**REQUIRED PROPERTIES:** You MUST include ALL required properties for every component, even if they are inside a template or will be bound to data.
- For 'Text', you MUST provide 'text'. If dynamic, use { "path": "..." }.
- For 'Image', you MUST provide 'url'. If dynamic, use { "path": "..." }.
- For 'Button', you MUST provide 'action'.
- For 'TextField', 'CheckBox', etc., you MUST provide 'label'.

**OUTPUT FORMAT:**
You must output a VALID JSON object representing one of the A2UI message types (`createSurface`, `updateComponents`, `updateDataModel`, `deleteSurface`).
- Do NOT use function blocks or tool calls for these messages.
- You can treat the A2UI schema as a specification for the JSON you typically output.
- You may include a brief conversational explanation before or after the JSON block if it helps the user, but the JSON block must be valid and complete.
- Ensure your JSON is fenced with ```json and ``` or just plain JSON.
''';
}
