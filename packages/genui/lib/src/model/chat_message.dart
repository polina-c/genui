// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// @docImport 'package:genai_primitives/genai_primitives.dart';
library;

import 'package:genai_primitives/genai_primitives.dart';

// Export the primitives so that users of genui don't need to import
// genai_primitives directly
export 'package:genai_primitives/genai_primitives.dart';

// Export local parts
export 'parts/image.dart';
export 'parts/thinking.dart';
export 'parts/ui.dart';

/// Legacy alias for [Part].
@Deprecated('Use Part instead')
typedef MessagePart = Part;

/// Legacy alias for [ChatMessage].
///
/// Note: The hierarchy has changed. `UserMessage`, `AiTextMessage`, etc. are
/// now factories or just [ChatMessage] with specific roles.
@Deprecated('Use ChatMessage instead')
typedef BaseChatMessage = ChatMessage;
