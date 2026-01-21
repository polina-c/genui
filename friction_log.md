# **GenUI Friction Log**

Developer experience research for the Google Flutter team
Evaluating GenUI SDK for production app implementation
Last Updated: 2026-01-10
This document captures what developers need to build production apps with GenUI. Items are framed as developer needs and capabilities, not code critiques.

## **Summary**

| Priority | Count | Description |
| :---- | :---- | :---- |
| 🔴 **P0 \- Adoption Risks** | 6 | Would pause adoption without external support |
| 🟡 **P1 \- Friction** | 19 | Frustrating but can continue with workarounds |
| 🟡 **P2 \- Gaps** | 5 | Missing docs, requires source exploration |
| ⚪ **P3 \- Minor** | 9 | Nice to have, low impact |
| 🟢 **Positive Findings** | 16 | Solid patterns worth preserving (See Category 5\) |

**Total: 39 friction items**
GenUI excels at chat-style AI interfaces. For wizard flows and live collaboration patterns, state management, schema predictability, and typed response output are the primary adoption risks.

### **Pattern Support Assessment**

GenUI was evaluated against three common AI-UI patterns:

| Pattern | What It Is | GenUI Fit | Key Gaps |
| :---- | :---- | :---- | :---- |
| **Conversation** | Turn-based chat with rich responses | ✅ Excellent | Minor: cancellation, metrics |
| **Collaboration** | AI \+ user work on shared, mutable content | ⚠️ Challenging | State sync, mutations, version history |
| **Guided Flow** | Step-by-step wizards with structured input | ⚠️ Challenging | State persistence, cascading regeneration, escape hatches |

Understanding which patterns GenUI supports helps developers make informed adoption decisions.

## **🔴 Category 1: Adoption Risks (P0)**

These are areas where developers would pause adoption without external help.
**Pattern Context:** These adoption risks primarily affect **Collaboration** and **Guided Flow** patterns. For **Conversation** patterns (chat interfaces), experienced Flutter developers can work around these with manual bridging. The severity is highest for teams attempting wizard flows or live collaboration without deep GenUI/Flutter expertise.

### **🔴 ENH-001: Two-Way State Sync Between GenUI and App State**

#### **Developer Need**

Apps using Provider/Bloc/Riverpod/Signals need two-way sync between GenUI's DataModel and their existing state management — both providing context to AI (app → GenUI) and receiving updates from user interactions (GenUI → app).

#### **Current Experience**

GenUI's DataModel is per-surface and ephemeral (deleted when the surface is deleted):

* Not automatically sent to AI on each turn
* No reactive binding to external state changes (internal ValueNotifiers only)
* resolveContext allows some data to flow one way (GenUI → app), but requires explicit declaration per action
* Bridging with state management libraries requires manual sync boilerplate

#### **Impact**

* Cannot build wizard flows where state persists across surfaces
* Cannot sync App State data updates to AI surfaces
* Multi-surface apps can show stale data
* Verbose boilerplate to bridge state management libraries

#### **What's Needed**

1. A way to provide app state to the AI on each turn (context injection)
2. A way to receive state changes from GenUI (event capture)
3. Documentation for integrating with common state management libraries
4. **Secure context injection** — ability to bind UI to sensitive data and PII (Personal Identifiable Information) without sending actual values to the AI. The LLM knows a binding *path* exists but not the *value*, which resolves client-side only.

#### **Workaround**

* resolveContext in actions specifies which DataModel paths to include with events (data flows one way: GenUI → app)
* Manual context stuffing in prompts for app state not in DataModel
* Manual DataModel.update() calls to sync external state into GenUI

### **🔴 ENH-002: Provide Predictable Data Paths for Reliable State Sync**

#### **Developer Need**

Production apps need a stable data contract — consistent DataModel paths that both app code and AI surfaces use. When paths drift or new keys appear unexpectedly, the app cannot reliably read, update, or audit state.

#### **Current Experience**

DataModel updates are intentionally permissive. GenUI accepts AI-provided keys/paths and will create missing nodes as needed. There is no built-in way to constrain updates to an expected set of paths or reject unknown keys, so path drift is common unless you pre-populate and strongly steer the model.
Some model backends support stricter structured output / schema enforcement, but GenUI doesn't provide a clear, documented path to apply that to DataModel updates today.

#### **Impact**

* App logic cannot count on stable paths across turns
* State sync becomes prompt-dependent without pre-populating paths
* Unexpected keys enter the DataModel silently, complicating debugging and auditing

#### **What's Needed**

* Clear guidance on designing and maintaining a stable DataModel contract (naming, pre-population, prompt patterns, drift detection)
* An opt-in way to constrain or validate DataModel updates (at least detect/ignore unknown paths)

#### **Workaround**

Pre-populate DataModel paths and instruct the AI in the system prompt to reuse those exact paths.

### **🔴 ENH-003: Rich AI Processing Visibility (Tool Events, Metrics, Response Metadata)**

#### **Developer Need**

Apps need programmatic access to AI processing data — tool calls, metrics, response metadata — for debugging, auditing, progress UIs, and building richer AI experiences.

#### **Current Experience**

GenUI provides logging-based visibility but lacks typed/programmatic APIs. The abstraction loses information — typed primitives exist for inputs, but outputs are simplified:

* textResponseStream discards structured metadata (tool calls, thinking blocks, finish reasons)
* Tool invocations logged but not exposed as typed events
* Token usage requires accessing concrete implementations (not on the interface)
* Latency is logged but NOT exposed as a property
* Only binary isProcessing — no intermediate states
* **Thinking block configuration** (budgets, visibility) not exposed through the abstraction — developers cannot adjust thinking settings without building custom generators; in production testing, thinking budgets caused errors until removed, and diagnosing the cause required better observability than GenUI exposes today

#### **Impact**

* Cannot build "AI is calling tool X..." progress indicators without log parsing
* Cannot display tool call history or "AI is thinking" UIs
* Cannot audit tool invocations for compliance in a type-safe way
* Cannot track latency or token usage without accessing concrete implementations

#### **What's Needed**

* Typed response stream including tool calls, thinking blocks, and model metadata
* Typed stream of tool invocation events (name, args, result, duration)
* Consistent exposure of token usage AND latency on the interface
* Granular processing states beyond binary isProcessing
* Direct access to thinking block configuration without requiring custom generators

#### **Workaround**

Use configureGenUiLogging() to capture log messages. Access concrete generator implementations and add logging to AiTool.invoke() — fragile but unblocks audits.

### **🔴 ENH-004: Tool Execution Lifecycle Control**

#### **Developer Need**

Apps need control over the tool execution lifecycle — intercepting tools before execution for authorization, handling errors after execution, and detecting runaway patterns that could waste resources or harm UX. Enterprise apps especially need user consent flows before AI accesses sensitive data or performs privileged operations.
**Example:** An AI tool that fetches personal information (e.g., getPersonalDetails) should prompt: "This AI assistant wants to access your personal information. Allow?" — rather than executing automatically.

#### **Current Experience**

Tools execute unconditionally with no lifecycle hooks:

* No pre-execution hooks for authorization or user confirmation
* No post-execution callbacks — tool errors are logged and sent to AI, not exposed to the app
* No loop detection — runaway patterns (e.g., infinite add/update/delete) run until maxToolUsageCycles=40

#### **Impact**

* AI can invoke dangerous actions (send email, delete data) without user consent
* Cannot implement "retry on failure" patterns at the app level
* Cannot show user-friendly error messages for tool failures
* No visibility into tool health for monitoring/alerting
* Resource waste from undetected runaway tool patterns

#### **What's Needed**

* Pre-execution hook for authorization/confirmation flows
* Post-execution callback for error handling
* Optional rate limiting for expensive API calls
* Loop detection for problematic repeated patterns (e.g., same tool sequence repeating)

#### **Workaround**

Build authorization and error handling wrappers inside each tool's invoke() method; emit errors to a custom stream.

### **🔴 ENH-005: Control Tool Execution Order Without Prompt Engineering**

#### **Developer Need**

Consistent tool execution ordering (e.g., surfaceUpdate before beginRendering, surfaces created in specific sequence) without relying on fragile prompt instructions.

#### **Current Experience**

Tool call order is entirely controlled by AI behavior. The framework processes tool calls in whatever order the AI returns them. Developers must write detailed prompt rules, for example:

* Call surfaceUpdate with all components before beginRendering
* For wizard flows, create surfaces in step order
* Never interleave surfaceUpdate calls for different surfaces

This is fragile because:

* LLMs don't always follow ordering instructions reliably
* Different models/versions behave differently (e.g., Gemini 2.5 Flash showed inconsistent ordering vs 3 Flash being more reliable in production testing)
* No framework-level validation warns when ordering is wrong — problems manifest as empty surfaces or blinking

#### **Impact**

* Wizard steps may appear out of order
* Developers discover ordering requirements through trial and error

#### **What's Needed**

A way to ensure consistent tool execution order without relying on prompt engineering. This could include framework-level ordering hints, surface display ordering, or debug-mode warnings when ordering violations occur.

#### **Workaround**

Detailed prompt engineering with explicit ordering rules (fragile, model-dependent).

### **🔴 ENH-006: Unified Client for UI \+ Structured Generation Workflows**

#### **Developer Need**

Production apps often combine GenUI UI collection with non-UI structured generation (JSON outputs, assets). They need one AI client/config to share auth, safety, telemetry, retries, and conversation context across both workflows.

#### **Current Experience**

GenUI's ContentGenerator is UI-focused (A2UI messages \+ text stream). For structured output tasks, apps must call a separate AI client with responseSchema. In the production app, chat surfaces use GoogleGenerativeAiContentGenerator, while deck generation uses the raw Google AI client with responseSchema. This splits model configuration, logging, error handling, and context management across two clients.
**The Gatekeeper Problem:** GenUI's ContentGenerator abstraction acts as a "gatekeeper" that limits access to underlying AI client capabilities. When using GenUI for UI generation, developers lose access to:

* Thinking block configuration (thinking budgets, thinking visibility)
* Model-specific parameters available on the raw client
* Fine-grained control over generation settings

**Note:** For example, GenUI's built-in generators don't expose a way to set a thinking budget or disable thinking; apps must use the raw client or implement a custom ContentGenerator to control that.
This means GenUI is excellent for UI rendering but can feel like a limited AI client when developers need both UI generation AND full underlying client capabilities in the same workflow. The alternative — creating a custom ContentGenerator — is significant engineering overhead just to access standard AI features.

#### **Impact**

* Duplicated client configuration and model policy logic
* No unified cancellation/timeout/metrics across UI \+ generation steps
* Manual, brittle context handoff between GenUI and structured generation
* Higher integration cost for apps that need both flows

#### **What's Needed**

A supported pattern/API for shared client configuration and passthrough access to underlying client capabilities (e.g., structured outputs / responseSchema, thinking configuration, telemetry), plus guidance for passing context between UI collection and structured generation without duplicating clients.

#### **Workaround**

Use a second AI client for structured generation and manually pass prompts/state between GenUI and the generator.

## **🟡 Category 2: Friction (P1)**

These issues cause significant friction but workarounds exist.

### **🟡 ENH-007: Constrain Catalog and Surface Capabilities per Surface**

#### **Developer Need**

Teams need to scope which widgets the AI can use per surface (e.g., step 1 only uses select cards, step 2 only uses sliders) and apply surface constraints (single active surface, max surfaces) without prompt bloat.

#### **Current Experience**

The AI can choose any widget in the active catalog. In practice, catalog choice is set up front (tool schema \+ host configuration), and the default flow does not provide a per-surface way to switch catalogs or enforce widget allowlists. The only control is prompt instructions or creating separate catalogs and running separate generators.

#### **Impact**

* Large catalogs lead to inconsistent widget choices
* Prompts become bloated with widget allowlists and rules
* Surfaces drift from the intended flow, requiring manual cleanup
* Hard to make wizard steps predictable without heavy prompt engineering

#### **What's Needed**

* Host-defined surface constraints (allowed catalog IDs, per-surface widget allowlists)
* Optional enforcement or debug warnings when the AI violates constraints
* A simple "single-surface" mode for guided flows

#### **Workaround**

Create smaller catalogs per step and add prompt rules; validate component IDs after the fact and delete invalid surfaces manually. In complex flows, run separate generators per step to force catalog changes.

### **🟡 ENH-008: Request Lifecycle Control (Cancel, Timeout)**

#### **Developer Need**

Apps need to control in-flight AI requests — cancel on user action ("Stop generating"), timeout on slow responses, and handle graceful termination.

#### **Current Experience**

Once sendRequest() is called, it runs to completion (up to 40 tool cycles) with no abort or timeout capability:

* No cancellation token pattern for "Stop generating" buttons
* No built-in timeout mechanism — requests can hang indefinitely on network issues
* The only "cancel" is disposing the entire conversation (loses all context)
* Future.timeout() wrapper doesn't actually cancel — request continues in background
* No semantics for "keep partial output" vs "discard"

**Note:** A2A integrations support cancellation via A2AClient.cancelTask(), but Firebase/Google generators have no cancel API.

#### **Impact**

* No "Stop generating" button capability
* Users stuck waiting for long-running or hung requests
* Cannot implement graceful timeout handling with user feedback
* Different backends have inconsistent timeout behaviors

#### **What's Needed**

* Cancellation API with clear semantics (keep partial vs discard)
* Configurable request timeout with callback
* Consistent behavior across Firebase/Google backends

#### **Workaround**

Dispose the entire conversation and recreate (loses context), or wrap with Future.timeout() (request continues in background).

### **🟡 ENH-009: Manage Long Conversations (Tokens, Pruning, Persistence)**

#### **Developer Need**

Production apps with long conversations need to track token usage, prune old messages before hitting context limits, and save/restore conversation state across app restarts.

#### **Current Experience**

No built-in token counting, context window management, or conversation serialization. Token fields exist on concrete implementations but aren't on the ContentGenerator interface.

#### **Impact**

* Cannot predict API costs
* Long conversations fail unexpectedly when context window fills
* App restarts lose all conversation history

#### **What's Needed**

* Token usage visibility on the interface (not just concrete implementations)
* Context window management (limits, pruning, warnings)
* Conversation serialization for persistence

#### **Workaround**

Access token counts by casting to concrete implementation (e.g., (generator as FirebaseAiContentGenerator).inputTokenUsage), use a third-party tokenizer library, or estimate based on word count. Prune and serialize manually.

### **🟡 ENH-010: Clean Up UI When Surface is Deleted**

#### **Developer Need**

When AI deletes a surface, the corresponding GenUiSurface widget should automatically clear or notify the parent so the UI stays in sync.

#### **Current Experience**

When a surface is deleted, GenUiSurface shows empty content (SizedBox.shrink()) rather than notifying the parent or removing itself. Cleanup is app-managed: apps must remove the corresponding widget from the tree (typically by tracking active surface IDs). GenUiConversation provides an onSurfaceDeleted callback (documented), but this still requires manual wiring and does not help if an app uses GenUiSurface directly.

#### **Impact**

* Easy to accidentally leave "empty surfaces" in the UI when wiring is missed
* Extra boilerplate to keep the widget tree in sync with surface lifecycle
* Cleanup behavior differs depending on whether the app adopts GenUiConversation

#### **What's Needed**

Either add a callback directly on GenUiSurface, or provide a higher-level widget/pattern that manages surface add/remove so apps don't have to hand-roll lifecycle wiring.

#### **Workaround**

Use GenUiConversation.onSurfaceDeleted (or listen to surfaceUpdates) and remove surface IDs from your UI list.

### **🟡 ENH-011: Track and Validate DataModel Mutations**

#### **Developer Need**

Apps need to track DataModel mutations for audit logging, undo/redo support, persistence triggers, and validation of AI updates before they're applied.

#### **Current Experience**

DataModel mutations are fire-and-forget with no interception points:

* No pre-update hook to validate or reject changes
* No post-update callback for tracking (only internal subscriber notification)
* No onUpdate/onChange/onMutation callback parameters
* A2uiMessageProcessor.handleMessage() calls dataModel.update() directly with no interception

#### **Impact**

* Cannot implement undo/redo for AI-generated changes
* Cannot audit what the AI changed (only that something changed)
* Cannot validate AI updates before they corrupt app state
* Cannot trigger persistence on mutation events

#### **What's Needed**

Optional mutation hooks on DataModel — pre-update for validation/rejection, post-update for tracking/logging.

**Additional context:** Without pre-update hooks, invalid AI output (e.g., out-of-bounds list indices from tool calls) throws ArgumentError and crashes the app—no graceful degradation path exists.

#### **Workaround**

Wrap DataModel access with a custom facade that intercepts update() calls and fires custom callbacks. Requires duplicating the DataModel API surface.

### **🟡 ENH-012: Trigger Regeneration on External State Changes**

#### **Developer Need**

Apps need to notify GenUI when external state changes (database updates, real-time notifications) and trigger UI regeneration without requiring user interaction.

#### **Current Experience**

There's no lightweight way to regenerate AI-generated UI based on external events. DataModel.update() updates data (when the UI is data-bound) but does not trigger UI structure regeneration. There is no invalidateSurface() / regenerateSurface() style API, so the default workaround is to call sendRequest() with a synthetic ChatMessage (full AI round-trip).

#### **Impact**

* External updates (database/realtime) can't reliably refresh AI-generated UI structure
* Guided flows can't easily do cascading regeneration (change step N → invalidate steps N+1…)
* Apps end up using expensive AI round-trips for state changes that aren't user interactions

#### **What's Needed**

A way to invalidate/regenerate surfaces programmatically (without faking a user message), including cascading regeneration across dependent surfaces (change surface A → invalidate surfaces B/C).

#### **Workaround**

Call sendRequest() with a descriptive ChatMessage like "Data has changed to X, please update." Works, but it's expensive and prompt-y.

### **🟡 ENH-013: Reverse Traceability for Debugging**

#### **Developer Need**

When render errors occur (widget not found, invalid component), developers need to trace back to which AI message and tool call created the problematic surface for debugging and error reporting.

#### **Current Experience**

Render errors include widget/surface IDs, but not the originating AI turn or tool call. The surface definition and widget builder context don't expose correlation IDs, so logs can't answer "which response/tool call produced this surface?"

* No turn/message ID associated with a surface or component
* No tool call ID associated with beginRendering / surfaceUpdate
* Error logs don't include turn/tool IDs

#### **Impact**

* Debugging render errors requires manual log correlation
* Cannot report "AI message X caused render error Y" to error tracking
* Incident response is slower due to lack of traceability
* Cannot build "show me what the AI was doing when this broke" debugging tools

#### **What's Needed**

Propagate turn/message ID (and tool call ID) from AI responses through to surfaces/components and include them in errors/logs/callbacks.

#### **Workaround**

Enable verbose logging with configureGenUiLogging(level: Level.ALL), then manually correlate timestamps and surface IDs across log entries. Time-consuming and error-prone.

### **🟡 ENH-014: Automate Surface Cleanup**

#### **Developer Need**

When wizard flows progress, old surfaces should be cleaned up automatically rather than relying on AI to follow prompt instructions.

#### **Current Experience**

Surface cleanup is not policy-driven. In practice it often depends on the AI calling deleteSurface (prompted with rules like "delete the previous surface"). Apps can implement cleanup themselves by watching surface lifecycle events and deleting old surfaces, but this is manual wiring and not a built-in retention mode.

#### **Impact**

* Surface accumulation creates UI clutter
* Prompt engineering and/or app-side wiring required for cleanup
* No SDK-level cleanup policy (keep latest, max N, TTL)

#### **What's Needed**

Optional automatic surface cleanup for common patterns (e.g., "keep only latest surface", "auto-cleanup on new surface").

#### **Workaround**

Include explicit cleanup instructions in the system prompt, and/or implement app-side cleanup using surface lifecycle events (remove old surface IDs and issue deletions when appropriate).

### **🟡 ENH-015: Consolidate Fallback Visibility in Debug Mode**

#### **Developer Need**

When widgets fall back to defaults, developers need consistent visibility across all fallback types to catch issues during development.

#### **Current Experience**

GenUI's "don't crash" fallbacks are a strength, but fallback visibility is inconsistent:

* Unknown widget IDs → visible Placeholder \+ severe log ✓
* Unknown widget types → empty Container \+ severe log
* Unknown icon names → Icons.broken\_image (visual only)
* Missing data paths → null with no warning
* Missing image URLs → SizedBox.shrink() with a warning log (no visual indicator)

Some fallbacks are visible (Placeholder with error text), others render silently. This makes debugging inconsistent.

#### **Impact**

* Some bugs are hidden — UI renders but with missing/wrong content
* Debugging requires knowing which fallbacks log and which don't
* Easy to miss issues that fall into the "silent" category

#### **What's Needed**

A consistent, opt-in debug-mode visibility strategy across fallback types (e.g., standardize logging and/or show visual indicators in debug builds).

#### **Workaround**

Enable verbose logging in dev builds and add debug-only placeholders/assertions for silent fallbacks (unknown widget types, missing paths).

### **🟡 ENH-016: Handle Concurrent Requests Safely**

#### **Developer Need**

Apps need built-in protection against concurrent AI requests that can corrupt state or produce interleaved responses.

#### **Current Experience**

Multiple concurrent sendRequest() calls can execute simultaneously. GenUiConversation auto-forwards every onSubmit event without checking if a request is already in progress. This makes it easy to trigger overlapping requests from rapid user actions or multiple surfaces.

#### **Impact**

* Rapid UI interactions can trigger overlapping requests
* Multiple responses interleave and corrupt DataModel state
* isProcessing can become unreliable during overlaps (false negatives while a request is still running)
* Conversation history updates can race (lost/overwritten messages)

#### **What's Needed**

Built-in concurrency handling with clear semantics (reject, queue, or replace), ideally configurable per conversation (and applied to auto-forwarded UI events too).

#### **Workaround**

Gate UI interactions while processing (disable/absorb taps) and check isProcessing before calling sendRequest() directly. Still requires careful app-side wiring.

### **🟡 ENH-017: Close Modals Programmatically**

#### **Developer Need**

AI should be able to close modals after completing actions, enabling "confirm → close" patterns.

#### **Current Experience**

showModal action opens a modal, but there's no action/message that can dismiss it programmatically. Dismissal is user-driven (gesture or UI that calls Navigator.pop()).

#### **Impact**

* Cannot implement "close modal on success" patterns
* Common confirm/close flows require workarounds

#### **What's Needed**

Programmatic modal dismissal via actions (so AI can close modals after completing tasks).

#### **Workaround**

Put a close button inside modal content that calls Navigator.pop() directly.

### **🟡 ENH-018: Navigate Tabs Programmatically**

#### **Developer Need**

AI should be able to navigate to specific tabs, and apps should be able to restore tab state from deep links.

#### **Current Experience**

Tabs widget has no activeTab or initialIndex property. Unlike CheckBox and MultipleChoice, there's no DataModel binding for tab selection.

#### **Impact**

* AI cannot say "navigate to Settings tab"
* Cannot restore tab state from deep links
* Tabs always start at index 0

#### **What's Needed**

Tabs support programmatic selection and state restoration with DataModel binding.

#### **Workaround**

Create custom CatalogItem with exposed TabController.

### **🟡 ENH-019: Control What Data Goes to AI on Actions**

#### **Developer Need**

When an action fires, apps need to control which DataModel fields are sent to AI — some fields should stay local.

#### **Current Experience**

When an action fires, all resolved values from the action's context definition are forwarded to the model. There's no supported way to mark a context path as local-only or redacted.

#### **Impact**

* Cannot keep sensitive fields (passwords, tokens) out of AI context
* All paths in the action's context definition are resolved and sent — no local-only marker

#### **What's Needed**

Documentation explaining that action context paths \= data sent to AI, and potentially a way to mark paths as local-only.

#### **Workaround**

Store sensitive data outside DataModel, or use tool callbacks to filter/redact sensitive paths before AI receives them.

### **🟡 ENH-020: Inspect and Manage Tool Registration**

#### **Developer Need**

Apps may need to inspect registered tools for debugging, or hide tools from the LLM entirely based on context (not just guard at invoke time).

#### **Current Experience**

Tool schemas are immutable after generator construction:

* additionalTools is final — tools cannot be added/removed after creation
* No tool registry API for inspecting what tools are registered
* No selective removal to hide tools from LLM based on context
* Generator recreation loses conversation history (no serialization layer)

**Note:** Dynamic runtime behavior *is* supported via DynamicAiTool closures, but inspection and selective removal are not.

#### **Impact**

* Debugging tool registration issues requires logging/inspection workarounds
* Tools that should disappear entirely require generator recreation (not just invoke-time guards)

#### **What's Needed**

* Tool inspection API for debugging (contentGenerator.getRegisteredTools())
* Conversation history serialization (ChatMessage.toJson()/fromJson())

#### **Workaround**

For tool inspection, add logging during generator setup. For selective removal, recreate the generator with an updated tools list.

### **🟡 ENH-021: Distinguish Error Types for Recovery Strategies**

#### **Developer Need**

When AI requests fail, apps need to know WHY to respond appropriately — retry on network failure, re-authenticate on auth error, back off on rate limits.

#### **Current Experience**

All errors arrive as generic ContentGeneratorError. Network failures, auth issues, rate limits, and malformed responses all look identical.

#### **Impact**

* Cannot implement "retry on network failure" logic
* Cannot show appropriate user-facing error messages
* Cannot implement exponential backoff for rate limits

#### **What's Needed**

A way to distinguish error categories so apps can implement appropriate recovery strategies.

#### **Workaround**

Access the raw ContentGeneratorError.error object and manually parse exception types or messages. This is fragile (message formats can change), implementation-specific (must rewrite for each ContentGenerator), and unreliable (no guarantee errors are typed consistently).

### **🟡 ENH-022: Handle Malformed AI Responses Gracefully**

#### **Developer Need**

When AI sends malformed component data, the app should degrade gracefully — show a placeholder, log the issue, continue running — not crash with a red screen.

#### **Current Experience**

Missing required properties can crash the entire surface at render time. The crash behavior is inconsistent:

* Some widgets guard against null values and show empty content
* Others throw TypeError when casting missing properties
* No pre-render validation against the Catalog schema
* A schema validation helper exists in test utilities but is not wired into the render path

#### **Impact**

* Malformed AI responses crash the entire surface
* Production apps must wrap GenUiSurface in error boundaries
* No consistent graceful degradation across core widgets

#### **What's Needed**

Either pre-render validation against the Catalog schema, or consistent graceful fallbacks when AI sends malformed components.

#### **Workaround**

Wrap GenUiSurface with a custom error boundary widget.

### **🟡 BUG-001: Clean Up DataModel Resources**

#### **Developer Need**

Long-running apps with many surface create/delete cycles need DataModel resources to be properly disposed to prevent memory leaks.

#### **Current Experience**

DataModel has no dispose() / clear() method. It caches ValueNotifiers created via subscribe() / subscribeToValue(), but there's no explicit API to release those subscriptions when a surface is no longer needed.

#### **Impact**

* Potential memory growth in apps with many dynamic surfaces/binding paths
* No explicit cleanup API for developers
* Violates Flutter's dispose pattern conventions

#### **What's Needed**

A dispose() method on DataModel that clears internal notifiers, called automatically when surfaces are deleted.

#### **Workaround**

Keep surface churn low, and recreate the A2uiMessageProcessor/conversation periodically in long-running sessions to release cached subscriptions.

### **🟡 BUG-002: Make TextField Validation Work**

#### **Developer Need**

TextField's validationRegexp property should actually validate input, or be removed to avoid confusion.

#### **Current Experience**

TextField schema and docs imply validationRegexp enables client-side validation, but the value is never used in the widget build. This is a silent no-op, and AI may emit validation patterns expecting them to work.

#### **Impact**

* Validation patterns have no effect
* Developers assume validation is happening when it's not
* Risk of shipping invalid input handling due to a false sense of validation

#### **What's Needed**

validationRegexp is enforced or explicitly documented as unsupported (no silent no-op).

#### **Workaround**

Implement validation manually in a custom CatalogItem.

### **🟡 BUG-003: Apply BeginRendering Styles for Design System Consistency**

#### **Developer Need**

Teams need AI-generated surfaces to follow the app design system (colors, typography, spacing). When the model sends BeginRendering.styles, developers expect those styles to affect the rendered surface or be clearly ignored.

#### **Current Experience**

BeginRendering parses styles, but the message processor drops them before they reach UiDefinition. The UiDefinition.styles field is marked "(Future)", so style payloads are effectively ignored.

#### **Impact**

* Style tokens have no effect
* Design system consistency cannot be enforced through BeginRendering.styles
* Developers spend time debugging why style payloads are ignored

#### **What's Needed**

Clear, supported behavior for BeginRendering.styles — apply styles to the surface theme or document the field as reserved and warn when it is sent.

#### **Workaround**

Ignore the styles field and apply styling through standard Flutter patterns — wrap GenUiSurface in a Theme widget or implement custom styling in catalog widgets.

## **🟡 Category 3: Documentation Gaps (P2)**

These require source code exploration but have clear paths forward.

### **🟡 DOC-001: Document Developer Patterns (Bindings, Custom Widgets, Wizard Flows)**

#### **Developer Need**

Developers need documented patterns for common GenUI development tasks: reactive data binding, custom widget creation, and wizard-style flows.

#### **Current Experience**

These patterns exist in the codebase but aren't surfaced to developers:

| Pattern | Gap | Status |
| :---- | :---- | :---- |
| **Reactive Bindings** | AI freely chooses between path (reactive) and literalString (static) bindings. When AI uses literals, dataModel.update() has no effect. No guidance on encouraging path usage. | Undocumented |
| **Custom Widgets** | Core widgets use extension type pattern for type safety, but developers receive untyped Object data. Schema/builder mismatches fail at runtime. | Pattern exists, undocumented |
| **Wizard Flows** | GenUI is designed for conversational chat. No documented pattern for wizard navigation, state persistence across steps, or "escape hatch" to bypass AI for final actions. | Undocumented |

#### **Impact**

* Reactive state sync fails silently when AI uses literal bindings instead of path bindings
* Custom widgets require trial-and-error with runtime crashes due to untyped data access
* Wizard implementations require reverse-engineering the architecture

#### **What's Needed**

* **Binding patterns guide**: When to use path vs literalString, system prompt examples for encouraging path usage
* **Custom widget guide**: Extension type pattern for type safety, schema/builder alignment practices
* **Wizard flow guide**: Escape hatch patterns using A2uiMessageProcessor.onSubmit, state extraction via dataModel.data, travel\_app as reference implementation

### **🟡 DOC-002: Document Core Concepts (DataModel, State Management, Surfaces)**

#### **Developer Need**

Developers need complete documentation of GenUI's core abstractions to make architectural decisions without source diving.

#### **Current Experience**

Core concepts are fragmented across README, DESIGN.md, and source code:

| Concept | Gap | Evidence |
| :---- | :---- | :---- |
| **DataModel Lifecycle** | When created/deleted, persistence behavior, post-deletion semantics undocumented | Created on BeginRendering, deleted on SurfaceDeletion, in-memory only |
| **AI Trigger Boundary** | update() vs dispatchEvent() distinction unclear — which triggers AI? | update() is local-only; dispatchEvent() emits to onSubmit → AI |
| **State Management** | No guidance on Provider/Bloc/Riverpod integration patterns | README focuses on AI-centric loop only |
| **Surface Updates** | Pre-render batching pattern exists but isn't documented | Components cached before BeginRendering, updates emitted after |

#### **Impact**

* Architectural decisions assume persistence that doesn't exist (state disappears on surface deletion)
* update() vs dispatchEvent() confusion causes silent failures or unintended AI calls
* Teams re-implement state bridging patterns inconsistently
* Visual flickering from suboptimal surface consumption patterns

#### **What's Needed**

* **DataModel guide**: Lifecycle, AI interaction boundary, API behaviors (root fallback, type permissiveness, subscriptions)
* **State management integration patterns**: Code samples for Provider/Bloc/Riverpod bridging
* **Surface consumption best practices**: Pre-rendering batching, per-surface ValueNotifier binding

### **🟡 DOC-003: Improve Reference Documentation and Discoverability**

#### **Developer Need**

Developers need to find accurate API documentation and relevant examples without reading source code.

#### **Current Experience**

Documentation is incomplete and partially outdated:

| Area | Gap | Evidence |
| :---- | :---- | :---- |
| **API Reference** | Key classes (A2uiSchemas, DataContext, dispatchEvent) documented only in source comments | No dartdoc site or API reference |
| **Example Index** | README links to examples without indexing by use case | Only travel\_app highlighted |
| **Documentation Accuracy** | Stale references, non-compiling samples, version drift | GenUiConfiguration removed but still in DESIGN.md; getTools() sample doesn't compile |

#### **Impact**

* Onboarding requires source spelunking to understand API surface
* Developers miss relevant examples for their use case
* Copy/paste samples fail on first run, eroding trust

#### **What's Needed**

* **API reference**: Core widgets table with schemas/examples, schema helpers guide, data binding patterns
* **Example index**: Table mapping example name → purpose → key concept demonstrated
* **Documentation hygiene**: Update stale references, verify samples compile, track latest version

### **🟡 DOC-004: Document Production Readiness (Testing, Backend, Theming, Accessibility)**

#### **Developer Need**

Production apps need guidance on testing, backend selection, theming, accessibility, and internationalization.

#### **Current Experience**

Production-critical topics are undocumented:

| Topic | Gap | Evidence |
| :---- | :---- | :---- |
| **Testing** | FakeContentGenerator exists but undocumented; no test builder helpers | Not surfaced in README/examples |
| **Backend Choice** | Minimal guidance on Firebase AI vs Google Generative AI trade-offs | "Not for production" warning but no comparison table |
| **Theming / design system** | BeginRendering.styles is parsed but unused; no guidance on design system or theme tokens | Styles field is present but marked as future/reserved; behavior not defined |
| **Accessibility** | No a11y checklist or guidance for AI-generated surfaces | README/DESIGN omit accessibility entirely |
| **Locale** | No guidance on passing locale context to AI | Client capabilities omit locale |

#### **Impact**

* Teams build ad-hoc test harnesses without guidance
* Backend choices made without understanding operational trade-offs
* Risk of shipping off-brand UI and inconsistent design system application
* Locale handling inconsistent across teams

#### **What's Needed**

* **Testing guide**: FakeContentGenerator usage, direct injection patterns, when to use each
* **Backend comparison table**: Latency, quotas, auth, security trade-offs
* **Theming guide**: Current capabilities (Material theme inheritance, catalog constraints) vs future styles support and design token usage
* **Accessibility checklist**: Screen reader compatibility, focus order, semantic labels
* **Locale patterns**: System prompt examples for locale-aware generation (lower priority)

### **🟡 DOC-005: Provide Adoption Decision Guidance (When GenUI Helps vs When JSON Is Enough)**

#### **Developer Need**

Teams need a short decision guide to evaluate whether GenUI is the right abstraction for their use case versus structured JSON outputs or traditional Flutter UI.

#### **Current Experience**

Docs show how to use GenUI, but there is no fit guide that spells out when the framework overhead is worth it or when simpler structured output patterns are a better choice.

#### **Impact**

* Teams over-invest in GenUI for simple workflows
* Others reject GenUI without seeing the collaboration/guided-flow advantages
* Adoption decisions rely on trial-and-error prototypes

#### **What's Needed**

* A decision guide with fit signals (conversation vs guided flow vs collaboration)
* Examples of "good fit" vs "not a fit"
* A short checklist for readiness (state sync, observability, prompt constraints)

## **⚪ Category 4: Minor Issues (P3)**

Nice to have improvements with low impact.

### **⚪ ENH-023: Guard Against Invalid Surface IDs**

#### **Developer Need**

Surface ID typos should be caught rather than silently creating new surfaces.

#### **Current Experience**

Any string is accepted — empty strings, special characters, case differences all create separate surfaces.

#### **Impact**

* Typos create orphaned surfaces and stale UI
* Hard to debug mismatched IDs across messages

#### **What's Needed**

Naming convention guidance and optional validation in debug mode.

#### **Workaround**

Centralize surface IDs as constants and assert/validate IDs in debug builds before sending messages.

### **⚪ ENH-024: Provide Action Registry Pattern**

#### **Developer Need**

Standard way to register and discover app-specific actions.

#### **Current Experience**

Every app must build custom action registry patterns.

#### **Impact**

* Action names drift across teams and prompts
* No shared place to validate or route actions

#### **What's Needed**

A discoverable action registry or typed action mapping for app-level actions.

#### **Workaround**

Implement an app-side action registry (map of action name → handler) and generate tool schemas from it.

### **⚪ ENH-025: Simplify Multi-Field Reactive Binding**

#### **Developer Need**

Binding multiple reactive fields shouldn't require deeply nested builders.

#### **Current Experience**

3 bound fields \= 3 nested ValueListenableBuilder wrappers.

#### **Impact**

* Widget code becomes deeply nested and hard to read
* Boilerplate discourages richer bindings

#### **What's Needed**

Document OptionalValueBuilder and provide multi-listenable builder pattern.

#### **Workaround**

Create a small helper widget that listens to multiple ValueListenables and rebuilds once, instead of nesting builders.

### **⚪ ENH-026: Avoid Casting CatalogItemContext.data**

#### **Developer Need**

Widget builders shouldn't need explicit casts for data access.

#### **Current Experience**

CatalogItemContext.data is typed as Object, requiring as JsonMap cast in every builder.

#### **Impact**

* Repetitive casting in every custom widget
* Runtime cast errors when data shape shifts

#### **What's Needed**

Typed access to widget data (or a typed accessor) to avoid per-builder casting.

#### **Workaround**

Use the core widget pattern (typed wrapper/extension type around JsonMap) to centralize casts and improve runtime error messages.

### **⚪ ENH-027: Allow Logging Cleanup**

#### **Developer Need**

Ability to cancel logging subscriptions for tests and hot reload.

#### **Current Experience**

configureGenUiLogging() doesn't return subscription, cannot be cancelled, accumulates duplicate listeners.

#### **Impact**

* Duplicate logs across hot reloads/tests
* Hard to silence logging in teardown

#### **What's Needed**

Ability to unsubscribe from logging listeners.

#### **Workaround**

Guard configureGenUiLogging() behind a single-init flag and avoid calling it repeatedly in tests/hot reload paths.

### **⚪ ENH-028: Add Navigation Components to Core Catalog**

#### **Developer Need**

Core catalog should include common navigation widgets.

#### **Current Experience**

Drawer, NavigationRail, NavigationBar missing — require custom CatalogItems.

#### **Impact**

* App shell patterns require custom widgets
* Slower prototyping for conventional layouts

#### **What's Needed**

Navigation widgets in core catalog for conventional app layouts.

#### **Workaround**

Add app-shell navigation as custom CatalogItems (Drawer/NavBar/NavRail) and keep them out of AI control where needed.

### **⚪ ENH-029: Prevent Unbounded Surface Growth**

#### **Developer Need**

Long-running apps need protection against unbounded surface accumulation.

#### **Current Experience**

No limit on surface count. AI could create unlimited surfaces if prompts don't constrain.

#### **Impact**

* Memory usage grows without guardrails
* Mobile devices with limited memory are particularly affected

#### **What's Needed**

Configurable surface limit with warning callback.

#### **Workaround**

Enforce a surface cap in app code (keep latest N surfaces) and delete/ignore additional surfaces when the cap is hit.

### **⚪ ENH-030: Multi-Tool Operations Cause Cumulative UI Latency**

#### **Developer Need**

Multi-step AI operations (like wizard flows with delete → create → render sequences) should feel responsive rather than showing visible "stepping" through each tool call.

#### **Current Experience**

Tool calls are processed sequentially in a blocking loop. Each tool waits for the previous one to complete before starting. This means:

* 5 tools × 200ms each \= 1 second cumulative latency
* Users see visible "stepping" through surface operations (delete → create → render)
* Up to 40 tool cycles possible per request, compounding the delay

#### **Impact**

* Users perceive "slow AI" when the real bottleneck is sequential tool execution
* Surface operations show intermediate states (empty surface before new content)
* Multi-step workflows feel sluggish compared to single-tool responses
* No way to batch independent tool calls for parallel execution

#### **What's Needed**

A mechanism to reduce perceived latency for multi-tool operations. Options include:

* Parallel execution for independent tools (tools with no data dependencies)
* Batching surface operations (all surfaceUpdate calls before beginRendering)
* Performance profiling APIs so developers can identify slow tools
* Guidance on tool consolidation patterns (combine multiple actions into fewer tools)

#### **Workaround**

Minimize tool count through prompt engineering; combine multiple operations into single tools where possible.

### **⚪ BUG-004: Google Generator Emits Duplicate Errors**

#### **Developer Need**

Error listeners should receive each error exactly once to enable accurate error counting and display.

#### **Current Experience**

When service.generateContent() throws an error in the Google generator, the error is emitted to errorStream twice due to a catch-rethrow pattern. The inner catch adds the error, then rethrows to an outer catch which adds it again.

#### **Impact**

* Error listeners receive the same error twice
* UI may show duplicate error messages
* Error counting and metrics are incorrect

#### **What's Needed**

Error should be emitted only once, either in the inner or outer catch block.

#### **Workaround**

Deduplicate errors in app-level error handling.

## **🟢 Category 5: Positive Findings**

**Developer experience research** for the Google Flutter team What works well in GenUI SDK — patterns worth preserving Last Updated: 2026-01-09
This document captures what works well in GenUI, highlighting solid design decisions and good developer experience patterns that should be preserved as the SDK evolves.

### **Summary of Positive Findings**

| Category | Count | Description |
| :---- | :---- | :---- |
| Graceful Degradation | 4 | SDK handles errors without crashing |
| Architecture & Design | 4 | Clean patterns and logical structure |
| Developer Experience | 4 | Flutter-idiomatic, familiar patterns |
| Core Capabilities | 4 | Streaming, extensibility, tools protocol |

**Total: 16 positive findings**
**Overall Assessment:** GenUI has a strong foundation with clear attention to detail — particularly around graceful degradation, type safety, and Flutter-idiomatic patterns. The conversational pattern is well-served, and the tools-as-rendering-protocol architecture is elegant. These strengths should be preserved as the SDK evolves to support collaboration and guided flow patterns.

### **Graceful Degradation**

These patterns ensure production apps remain stable even when AI responses are unpredictable.

#### **🟢 GOOD-001: Handle Unknown Widgets Gracefully**

##### **What Works**

When AI emits an unknown widget type, the SDK returns an empty Container instead of crashing. The UI continues functioning even with partial AI errors.

##### **Why It Matters**

AI responses are inherently unpredictable. Apps can ship confidently knowing a hallucinated widget type won't crash production — the surface degrades gracefully rather than showing a red error screen.

##### **Developer Benefit**

* Production apps don't crash on AI hallucinations
* Debugging is easier (UI shows something vs red screen)
* No need for defensive error boundaries around every surface

#### **🟢 GOOD-002: Handle Missing Children Gracefully**

##### **What Works**

Layout widgets that use ComponentChildrenBuilder return SizedBox.shrink() when children data is missing, instead of crashing.

##### **Why It Matters**

AI responses can be partial or streaming; layout shells shouldn't blow up while children arrive.

##### **Developer Benefit**

* Partial UI frames render without red screens
* Streaming can fill in children progressively

#### **🟢 GOOD-003: Handle Invalid Child References Safely**

##### **What Works**

When a component references a child ID that doesn't exist, the SDK renders a Placeholder widget with an error message instead of crashing. This makes debugging easier — you see which reference failed.

##### **Why It Matters**

AI might hallucinate component IDs or reference deleted components. Instead of crashing the entire surface, you get a visual indicator of exactly which reference is broken.

##### **Developer Benefit**

* Broken references are visible, not hidden crashes
* Easier to debug AI output issues
* Parent components continue rendering despite child errors

#### **🟢 GOOD-004: Allow DataModel Value Type Changes**

##### **What Works**

DataModel gracefully handles type changes in values. If a path contains a string and you update it to an integer, the change succeeds without throwing exceptions.

##### **Why It Matters**

AI responses and user inputs may produce different types for the same path (e.g., "5" vs 5). The SDK's permissive type handling means developers don't need to worry about type casting edge cases.

##### **Developer Benefit**

* No runtime type errors on data updates
* Flexible schema evolution without migration concerns
* AI can send different types without breaking the UI

### **Architecture & Design**

These patterns demonstrate clean architecture and thoughtful design decisions.

#### **🟢 GOOD-006: Separate Core Layers Clearly**

##### **What Works**

The architecture follows a clear, understandable pattern:
GenUiConversation → A2uiMessageProcessor → GenUiSurface

This separation of concerns makes the codebase navigable and data flow predictable. Each layer has a single responsibility.

##### **Why It Matters**

When debugging issues or extending functionality, developers can quickly identify which layer to investigate. The predictable flow makes mental models accurate.

##### **Developer Benefit**

* Easy to trace data flow from AI → UI
* Clear extension points for customization
* Source code is navigable when docs are insufficient

#### **🟢 GOOD-007: Propagate UI Events Reliably**

##### **What Works**

The dispatchEvent → onSubmit flow works reliably for user interactions. Events are properly propagated and can be listened to by the application. Button clicks, form submissions, and custom actions all flow through this consistent mechanism.

##### **Why It Matters**

A reliable event system is foundational for building interactive AI UIs. Developers can trust that user actions will reach their handlers without needing to debug event propagation issues.

##### **Developer Benefit**

* Consistent pattern for all user interactions
* Events can be intercepted before reaching AI
* Easy to add logging, analytics, or validation

#### **🟢 GOOD-014: Batch Pre-Rendering for Atomic Surface Appearance**

##### **What Works**

GenUI intelligently batches component updates before rendering begins. Components sent via SurfaceUpdate are cached silently until BeginRendering is called, at which point the surface appears fully formed.

##### **Why It Matters**

This prevents the common "flash of incomplete content" problem. AI can send multiple components in sequence, and users see the complete surface rather than watching it build piece by piece.

##### **Developer Benefit**

* Surfaces appear atomically, not incrementally
* No visual flicker during initial surface construction
* AI can structure tool calls naturally without worrying about render timing
* Clear state machine: Pre-Rendering → Rendering → Deleted

#### **🟢 GOOD-015: Use Tools as a Rendering Protocol**

##### **What Works**

GenUI uses AI function calling (tools) as the abstraction layer between AI and UI. Three core rendering tools — surfaceUpdate, beginRendering, deleteSurface — form the backbone of a declarative rendering protocol that the AI can drive directly.

##### **Why It Matters**

This solves "how do we let AI build UI safely?" without requiring the model to generate widget code:

* Tools are the AI's native language — LLMs naturally speak in function calls, not widget code
* Schema-validated contracts ensure the AI can only request valid UI operations
* Clear separation: AI declares intent, framework handles implementation

##### **Developer Benefit**

Tools extend naturally via additionalTools parameter — add custom tools without changing core architecture.

### **Developer Experience**

These patterns make GenUI feel like natural Flutter development.

#### **🟢 GOOD-005: Onboard Quickly with Getting-Started Steps**

##### **What Works**

Getting-started docs walk through setup with concrete steps and code snippets for wiring GenUI into an app.

##### **Why It Matters**

Clear steps reduce onboarding ambiguity and help evaluators reach a running baseline faster.

##### **Developer Benefit**

* Copy/paste friendly setup steps
* Less guesswork during first-time evaluation
* Faster path to a working prototype

#### **🟢 GOOD-008: Test Surfaces Deterministically with handleMessage()**

##### **What Works**

Direct handleMessage() calls provide a clean, deterministic way to test GenUI surfaces without requiring a real AI backend. You can inject A2uiMessage objects and verify the resulting UI.

##### **Why It Matters**

Testing AI-dependent UIs is notoriously difficult due to non-deterministic responses. The ability to bypass the AI and inject known messages makes thorough testing practical.

##### **Developer Benefit**

* Unit tests are fast (no AI latency)
* Tests are deterministic (no AI variability)
* Full control over edge cases and error conditions

#### **🟢 GOOD-009: Keep Schemas and Messages Typed in Dart**

##### **What Works**

Schema definitions, tool declarations, and message structures are all strongly typed in Dart. Typos and type mismatches are caught at compile time rather than runtime.

##### **Why It Matters**

AI integrations often involve complex nested data structures that are prone to subtle bugs. Dart's type system catches errors early, before they reach production.

##### **Developer Benefit**

* Compile-time errors vs runtime crashes
* IDE autocomplete for schema properties
* Refactoring tools work across the codebase

#### **🟢 GOOD-010: Compose Surfaces as Standard Widgets (Hot Reload Works)**

##### **What Works**

GenUI surfaces are standard Flutter widgets (StatefulWidget/StatelessWidget) with no custom render pipeline.

##### **Why It Matters**

Hot reload and DevTools behave as expected when iterating on catalog widgets.

##### **Developer Benefit**

* Iteration feels like normal Flutter development
* No special debugging tools required
* Faster tweaks to custom CatalogItems

### **Core Capabilities**

These capabilities enable the core value proposition of GenUI.

#### **🟢 GOOD-011: Show Progressive UI Updates During Tool Execution**

##### **What Works**

GenUI surfaces update reactively as tool calls execute (e.g., surfaceUpdate, beginRendering). Components can appear incrementally, and ValueNotifier triggers rebuilds as surface definitions change.

##### **Why It Matters**

Progressive updates create a responsive feel even when AI requests take several seconds. Users see progress per tool invocation rather than waiting for a single final response.

##### **Developer Benefit**

* No additional code needed for reactive updates
* Users see progress immediately
* Reduces perceived latency for long responses

#### **🟢 GOOD-012: Build Catalog Items with Standard Flutter Widgets**

##### **What Works**

Core catalog widgets wrap standard Flutter widgets (e.g., ElevatedButton, Column, MarkdownBody) using normal build patterns.

##### **Why It Matters**

Developers don't need to learn a new UI framework. Existing Flutter knowledge transfers directly to GenUI development, including theming and debugging.

##### **Developer Benefit**

* Familiar widget lifecycle and patterns
* DevTools work as expected
* Existing styling and theming knowledge applies

#### **🟢 GOOD-013: Extend Catalogs via copyWith()**

##### **What Works**

Catalog.copyWith() makes it straightforward to extend an existing catalog with custom widgets, replacing duplicates by name.

##### **Why It Matters**

Real apps need domain-specific widgets. The extensibility pattern ensures developers aren't limited to built-in components; they can create anything their app needs.

##### **Developer Benefit**

* Clear pattern for custom components
* Schema and builder are co-located
* Custom widgets integrate well with core widgets

#### **🟢 GOOD-016: Add Custom Tools via DynamicAiTool**

##### **What Works**

DynamicAiTool combined with additionalTools enables developers to create custom application tools that integrate directly with GenUI's rendering system — navigation, data-fetching, validation, or domain-specific capabilities.

##### **Why It Matters**

Production apps need more than UI rendering. Custom tools run alongside GenUI's built-in rendering tools — the AI sees them as equals, with no distinction between "framework" and "app" tools.

##### **Developer Benefit**

* Extend beyond built-in UI tools without framework modifications
* Tools are just Dart objects — use DI, testing mocks, composition
* Factory functions can configure tools for specific contexts