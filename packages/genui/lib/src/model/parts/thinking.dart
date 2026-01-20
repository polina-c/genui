import 'package:genai_primitives/genai_primitives.dart';

/// A provider-specific part for "thinking" blocks.
final class ThinkingPart extends Part {
  /// The reasoning content from the model.
  final String text;

  /// Creates a [ThinkingPart] with the given [text].
  const ThinkingPart(this.text);
}
