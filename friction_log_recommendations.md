GenUI Friction Log Recommendations
This document addresses the items raised in the GenUI Friction Log (Last Updated: 2026-01-10). It provides recommendations for either existing solutions or proposed API changes to resolve the identified friction points and adoption risks.
Category 1: Adoption Risks (P0)
🔴 ENH-001: Two-Way State Sync Between GenUI and App State
Analysis: The current DataModel is isolated and ephemeral. Integrating with external state management (Provider, Bloc, Riverpod) is manual and error-prone. There is no built-in mechanism to "bind" an external value to a DataModel path bi-directionally.

Recommendation: Introduce an External Data Binding API to DataModel or GenUiConversation.

Context Injection (App -> GenUI): Add a method to bind external ValueListenables or Streams to DataModel paths.

// Example API Proposal
genUiConversation.bindExternalState(
  path: DataPath.parse('/user/profile'),
  source: userProfileNotifier, // ValueListenable
  // Optional: two-way sync
  onUpdate: (newValue) => userProfileNotifier.value = newValue,
);

This allows the DataModel to automatically update when the external state changes, and optionally update the external state when the AI mutates the data.

Secure Context: Implement a "Shadow Binding" where the DataModel holds a reference/token, but the actual value is resolved only at render time or action time, never sent to the LLM.

Proposed Change: Add secure: true metadata to DataPath or a SecureValue wrapper that is redacted in DataModel.toJson() but available to widget builders.

v0.9 Impact: The A2UI v0.9 protocol introduces watchDataModel and dataModelChanged messages which formalize the channel for synchronizing state between client and server. However, it does not explicitly define a mechanism for binding external client-side state (like a local database or auth token) into the DataModel in a way that is "secure" or "local-only". The recommendation to add an External Data Binding API remains relevant, but any implementation should strictly adhere to the watchDataModel configuration (e.g., ensuring local-only paths are never configured to send onChanged events).


🔴 ENH-002: Provide Predictable Data Paths for Reliable State Sync
Analysis: DataModel is currently "schemaless" and permissive. It accepts whatever structure the AI generates.

Recommendation: Introduce Schema-Enforced DataModel.

Schema Definition: Allow providing a JsonSchema to the DataModel (or GenUiConversation) at initialization.

final dataModel = DataModel(
  schema: userProfileSchema,
  enforceSchema: true, // properties: false logic for unknown keys
);

Validation: When update() is called, validate the new data against the schema. If enforceSchema is true, reject invalid updates or unknown keys with a warning (or error in debug).

v0.9 Impact: A2UI v0.9 introduces a standard ValidationFailed error format for the client to report schema violations back to the server (LLM). This aligns perfectly with this recommendation. If the DataModel enforces a schema locally, it can now communicate violations in a way the protocol officially supports, enabling the "Prompt-Generate-Validate" self-correction loop described in the v0.9 specification.


🔴 ENH-003: Rich AI Processing Visibility (Tool Events, Metrics, Response Metadata)
Analysis: ContentGenerator abstracts away too much. Stream<String> and Stream<A2uiMessage> are insufficient for observing the internal state of the generation (tool calls, thinking, tokens).

Recommendation: Expand the event system.

Rich Event Stream: Replace (or augment) existing streams with a Stream<GenUiEvent> that emits typed events:

ThinkingEvent(String content)
ToolCallEvent(String name, Map args)
ToolResultEvent(String name, Object result)
TokenUsageEvent(int input, int output)
ContentGeneratedEvent(String text)

Expose Metrics: Add metrics getter to ContentGenerator that returns the latest session metrics (latency, tokens).


🔴 ENH-004: Tool Execution Lifecycle Control
Analysis: Tools run automatically. Developers need interception points for auth, confirmation, and error handling.

Recommendation: Add Tool Middleware / Interceptors.

Interceptor API:

typedef ToolInterceptor = Future<ToolAction> Function(ToolCall call);

class ToolAction {
  factory ToolAction.proceed();
  factory ToolAction.cancel();
  factory ToolAction.replaceResult(Object result);
  factory ToolAction.error(Object error);
}

Configuration: Allow passing toolInterceptors to ContentGenerator. This allows implementing "Ask for confirmation" dialogs (by pausing/canceling and triggering a UI request), or pre-check logic.


🔴 ENH-005: Control Tool Execution Order Without Prompt Engineering
Analysis: Dependencies between tools (e.g. SurfaceUpdate before BeginRendering) are currently enforced only by prompt instructions.

Recommendation: Framework-Level Sequencing.

Buffered Execution: In A2uiMessageProcessor, implement a buffering strategy where SurfaceUpdate messages are always processed/applied before BeginRendering within the same turn/batch, regardless of the order they appeared in the stream (or warn if they are inverted).

Tool Dependencies: Allow defining dependencies in AiTool definition (e.g., dependencies: ['surfaceUpdate']), though this might be complex for the LLM. Framework-level buffering is more robust.

v0.9 Impact: A2UI v0.9 explicitly replaces beginRendering with createSurface. The protocol mandates that createSurface "MUST be sent before the first updateComponents message that references this surfaceId." This stricter lifecycle reduces ambiguity, but enforcing the correct temporal order of tool calls from the LLM (ensuring it calls createSurface before updateComponents) is still a valid concern that framework-level buffering or validation could address.


🔴 ENH-006: Unified Client for UI + Structured Generation Workflows
Analysis: ContentGenerator hides the underlying client (e.g. GenerativeModel).

Recommendation: Passthrough & Shared Configuration.

Expose Client: Add T getClient<T>() to ContentGenerator. GoogleGenerativeAiContentGenerator would return the GenerativeModel.
Shared Service: Promote the pattern of passing a GenerativeService (or GenerativeModel) to the ContentGenerator constructor, so the app can reuse the same instance/config for non-UI tasks.


Category 2: Friction (P1)
🟡 ENH-007: Constrain Catalog and Surface Capabilities per Surface
Recommendation: Add catalogId or allowedTools constraint to sendRequest.

Allow passing a subset of the catalog or a specific Catalog instance for a specific turn.

v0.9 Impact: v0.9 moves towards a "Unified Catalog" defined in standard_catalog.json and supports explicit catalogId in createSurface. The capability negotiation via a2uiClientCapabilities in A2A metadata allows the client to declare which catalogs it supports. This recommendation could be implemented by having the client dynamically adjust its reported supportedCatalogIds based on the surface context.
🟡 ENH-008: Request Lifecycle Control (Cancel, Timeout)
Recommendation:

Cancellation: Return a CancelableOperation or Future<void> that accepts a CancellationToken in sendRequest.
Timeout: Add timeout parameter to sendRequest.
🟡 ENH-009: Manage Long Conversations
Recommendation:

Token Counting: Expose totalTokens on ContentGenerator.
Pruning: Implement ConversationManager that handles history pruning (sliding window) automatically.
Persistence: Add toJson/fromJson to ChatMessage and DataModel to allow saving/restoring session state.
🟡 ENH-010: Clean Up UI When Surface is Deleted
Recommendation: Introduce GenUiSurfaceManager widget.

A widget that listens to GenUiConversation and automatically manages the list of active GenUiSurface widgets, checking for deleteSurface events.
🟡 ENH-011: Track and Validate DataModel Mutations
Recommendation: Add onUpdate callback to DataModel.

Stream<DataModelUpdateEvent> get updates;
Arguments: path, oldValue, newValue.
Allows implementing Undo/Redo and Audit logging.

v0.9 Impact: The dataModelChanged message in v0.9 is the protocol-level manifestation of this. Implementing onUpdate is essential for the client to generate these messages. The recommendation stands as a necessary implementation detail to support v0.9 conformance.
🟡 ENH-012: Trigger Regeneration on External State Changes
Recommendation: Add refresh() method to ContentGenerator which sends a hidden prompt (e.g. "State updated, refresh UI") or re-processes the last prompt with new context.
🟡 ENH-013: Reverse Traceability for Debugging
Recommendation: Attach messageId and toolCallId to UiDefinition and GenUiSurface.

When a surface renders, it should know which turn created it.
🟡 ENH-014: Automate Surface Cleanup
Recommendation: Add cleanupPolicy to GenUiConversation.

SurfaceCleanupPolicy.keepLatest(int n): Automatically sends deleteSurface tools or locally removes surfaces when limit is reached.
🟡 ENH-015: Consolidate Fallback Visibility in Debug Mode
Recommendation: Standardize Fallback Widgets.

Create a GenUiFallback widget used by all core widgets when errors occur.
It checks kDebugMode to decide whether to show a red box/error text or SizedBox.shrink().
🟡 ENH-016: Handle Concurrent Requests Safely
Recommendation: Implement a Request Queue in GenUiConversation.

If sendRequest is called while isProcessing is true, either queue it or throw ConcurrentRequestException (configurable).
🟡 ENH-017: Close Modals Programmatically
Recommendation: Add CloseModal action/tool to the standard catalog.

The GenUiSurface or generic ActionHandler should recognize closeModal and call Navigator.pop().

v0.9 Impact: The v0.9 Modal component (and Tabs) purely defines structure (trigger, content). It does not introduce a standardized "close" tool. However, the improved data binding allows for more reactive patterns. For example, a Modal's visibility could theoretically be bound to a boolean in the DataModel (if the component supported it), allowing the AI to close it by updating data. Since the Modal schema in standard_catalog.json does not currently have a visible or isOpen property, the recommendation for a dedicated CloseModal action or tool remains valid and necessary.
🟡 ENH-018: Navigate Tabs Programmatically
Recommendation: Update Tabs widget schema.

Add an activeTab property that binds to an integer/string in DataModel.
When DataModel updates, Tabs switches tabs.
AI can then "navigate" by updating the data model.

v0.9 Impact: The Tabs component in v0.9 standard_catalog.json defines tabs array but does not expose an activeTab or selectedIndex property. This confirms that the AI currently cannot control the active tab state programmatically. This recommendation to update the Tabs schema to include a bindable activeTab property is critical for v0.9.
🟡 ENH-019: Control What Data Goes to AI on Actions
Recommendation: Add localOnly flag to ActionContext.

In the schema/action definition, allow marking specific context keys as localOnly: true. These are available to client-side handlers but stripped before sending to LLM.

v0.9 Impact: v0.9 simplifies action context to a standard JSON object. While it doesn't have a localOnly flag, the watchDataModel message allows strictly defining which paths trigger updates to the server. A localOnly flag in the schema would be a useful developer-experience enhancement to auto-configure watchDataModel or filter action payloads.
🟡 ENH-020: Inspect and Manage Tool Registration
Recommendation: Expose unmodifiableList<AiTool> get tools on ContentGenerator.
🟡 ENH-021: Distinguish Error Types
Recommendation: Subclass ContentGeneratorError.

NetworkError, RateLimitError, AuthError, GenerationError.
Parsers in concrete implementations should map native errors to these types.

v0.9 Impact: v0.9 specifies ValidationFailed for schema errors, which should be treated as a distinct error type that allows for retry/correction loops, separate from fatal infrastructure errors.
🟡 ENH-022: Handle Malformed AI Responses Gracefully
Recommendation: Wrap GenUiSurface (or individual components) in ErrorBoundary widgets that catch render exceptions and show the GenUiFallback widget.
🟡 BUG-001: Clean Up DataModel Resources
Recommendation: Add dispose() to DataModel.

And call it when GenUiConversation is disposed.
🟡 BUG-002: Make TextField Validation Work
Recommendation: Implement TextFormField validation logic using validationRegexp.

Or deprecate/remove the property if client-side validation logic is unsupported in the current architecture.
🟡 BUG-003: Apply BeginRendering Styles
Recommendation: Wire up UiDefinition.styles.

Apply them to a Theme widget wrapping the GenUiSurface.
⚪ BUG-004: Google Generator Emits Duplicate Errors
Recommendation: Fix: Remove the double catch/rethrow in google_generative_ai_content_generator.dart.

Either handle it in _generate OR sendRequest, not both.
Category 4: Minor Issues (P3)
ENH-023: Validate Surface IDs: Log warnings for non-standard IDs.
ENH-024: Action Registry: Provide ActionRegistry class to map names to handlers.
ENH-025: Multi-Field Binding: Create MultiSourceBuilder widget.
ENH-026: Typed Context Data: Add generic T data accessor to CatalogItemContext.
ENH-027: Logging Cleanup: Return StreamSubscription from configureGenUiLogging.
ENH-028: Add Nav Widgets: Add Drawer, NavigationBar to core_catalog.
ENH-029: Surface Limits: Add maxSurfaces config.
ENH-030: Latency: Implement parallel tool execution where possible (requires dependency graph or AI hints), or batch UI updates (only render after all surfaceUpdates in a turn are processed).