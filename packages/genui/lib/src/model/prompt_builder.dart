abstract class GenUiPromptBuilder {
  static GenUiPromptBuilder custom(String prompt) =>
      _CustomGenUiPromptBuilder(prompt);

  static GenUiPromptBuilder basic(
    String prompt, {
    bool allowSurfaceCreation = true,
    bool allowSurfaceUpdate = false,
    bool allowSurfaceDeletion = false,
  }) => _BasicPromptBuilder(
    prompt,
    allowSurfaceCreation: allowSurfaceCreation,
    allowSurfaceUpdate: allowSurfaceUpdate,
    allowSurfaceDeletion: allowSurfaceDeletion,
  );

  /// Returns the prompt to be sent to the model.
  // It is not getter to allow parameters in future.
  String build();
}

class _CustomGenUiPromptBuilder implements GenUiPromptBuilder {
  final String prompt;

  _CustomGenUiPromptBuilder(this.prompt);

  @override
  String build() => prompt;
}

class _BasicPromptBuilder implements GenUiPromptBuilder {
  final String prompt;
  final bool allowSurfaceCreation;
  final bool allowSurfaceUpdate;
  final bool allowSurfaceDeletion;

  _BasicPromptBuilder(
    this.prompt, {
    required this.allowSurfaceCreation,
    required this.allowSurfaceUpdate,
    required this.allowSurfaceDeletion,
  });

  @override
  String build() => throw UnimplementedError();
}
