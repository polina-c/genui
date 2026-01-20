/// A provider-specific part for "thinking" blocks.
final class ThinkingPart implements MessagePart {
  /// The reasoning content from the model.
  final String text;

  /// Creates a [ThinkingPart] with the given [text].
  const ThinkingPart(this.text);
}
