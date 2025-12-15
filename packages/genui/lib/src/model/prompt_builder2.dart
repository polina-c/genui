import '../../genui.dart';

abstract class GenUiPromptBuilder {
  static GenUiPromptBuilder custom(
    Catalog catalog, {
    required String systemPrompt,
  }) => _CustomGenUiConfiguration(systemPrompt, catalog);

  static GenUiPromptBuilder basic(
    Catalog catalog, {
    required String systemPrompt,
    bool allowSurfaceCreation = true,
    bool allowSurfaceUpdate = false,
    bool allowSurfaceDeletion = false,
  }) => _BasicGenUiConfiguration(
    systemPrompt,
    allowSurfaceCreation: allowSurfaceCreation,
    allowSurfaceUpdate: allowSurfaceUpdate,
    allowSurfaceDeletion: allowSurfaceDeletion,
  );

  String prompt(String userMessage);

  GenUiPrompt prompt(UserMessage userMessage);
}

class _CustomGenUiConfiguration implements GenUiPromptBuilder {
  final String _prompt;
  final Catalog _catalog;

  _CustomGenUiConfiguration(this._prompt, this._catalog);

  @override
  String prompt(UserMessage userMessage) => _prompt;
}

class _BasicGenUiConfiguration implements GenUiPromptBuilder {
  final String _prompt;
  final bool allowSurfaceCreation;
  final bool allowSurfaceUpdate;
  final bool allowSurfaceDeletion;

  _BasicGenUiConfiguration(
    this._prompt, {
    required this.allowSurfaceCreation,
    required this.allowSurfaceUpdate,
    required this.allowSurfaceDeletion,
  });

  @override
  String prompt(UserMessage userMessage) => throw UnimplementedError();
}
