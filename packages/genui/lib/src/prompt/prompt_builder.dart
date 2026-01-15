import '../../genui.dart';
import '../model/catalog.dart';
import '../model/tools.dart';

abstract class GenUiPrompt {}

abstract class GenUiContext {}

abstract class GenUiPromptBuilder {
  static GenUiPromptBuilder basic(
    Catalog catalog, {
    required String systemPrompt,
    bool allowSurfaceCreation = true,
    bool allowSurfaceUpdate = false,
    bool allowSurfaceDeletion = false,
    List<AiTool>? additionalTools,
  }) => _BasicGenUiConfiguration(
    systemPrompt,
    allowSurfaceCreation: allowSurfaceCreation,
    allowSurfaceUpdate: allowSurfaceUpdate,
    allowSurfaceDeletion: allowSurfaceDeletion,
    additionalTools: additionalTools,
  );

  /// Produces prompt for the given user message and context.
  ///
  /// The produced prompt may be final or partial,
  /// depending on the system architecture.
  ///
  /// [userMessage] is null for CUJs where user message is processed
  /// by other part of the system, like server-side agents.
  /// [context] may contain history and context information.
  GenUiPrompt prompt({UserMessage? userMessage, GenUiContext? context});
}

class _BasicGenUiConfiguration implements GenUiPromptBuilder {
  final String systemPrompt;
  final bool allowSurfaceCreation;
  final bool allowSurfaceUpdate;
  final bool allowSurfaceDeletion;
  final List<AiTool>? additionalTools;

  _BasicGenUiConfiguration(
    this.systemPrompt, {
    this.allowSurfaceCreation = true,
    this.allowSurfaceUpdate = false,
    this.allowSurfaceDeletion = false,
    this.additionalTools,
  });

  @override
  GenUiPrompt prompt({UserMessage? userMessage, GenUiContext? context}) {
    throw UnimplementedError();
  }
}
