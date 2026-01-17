// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'package:genui/genui.dart';

typedef UserPromptBuilder =
    Widget Function(BuildContext context, ChatMessage message);

typedef UserUiInteractionBuilder =
    Widget Function(BuildContext context, ChatMessage message);

class Conversation extends StatelessWidget {
  const Conversation({
    super.key,
    required this.messages,
    required this.manager,
    this.userPromptBuilder,
    this.userUiInteractionBuilder,
    this.showInternalMessages = false,
    this.scrollController,
  });

  final List<ChatMessage> messages;
  final A2uiMessageProcessor manager;
  final UserPromptBuilder? userPromptBuilder;
  final UserUiInteractionBuilder? userUiInteractionBuilder;
  final bool showInternalMessages;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final List<ChatMessage> renderedMessages = messages.where((message) {
      if (showInternalMessages) {
        return true;
      }
      return message.role != ChatMessageRole.system && !message.hasToolResults;
    }).toList();

    return ListView.builder(
      controller: scrollController,
      itemCount: renderedMessages.length,
      itemBuilder: (context, index) {
        final ChatMessage message = renderedMessages[index];

        if (message.role == ChatMessageRole.user) {
          if (message.parts.whereType<UiInteractionPart>().isNotEmpty) {
            return userUiInteractionBuilder != null
                ? userUiInteractionBuilder!(context, message)
                : const SizedBox.shrink();
          } else {
            return userPromptBuilder != null
                ? userPromptBuilder!(context, message)
                : ChatMessageView(
                    text: message.text,
                    icon: Icons.person,
                    alignment: MainAxisAlignment.end,
                  );
          }
        } else if (message.role == ChatMessageRole.model) {
          final uiPart = message.parts.whereType<UiPart>().firstOrNull;
          if (uiPart != null) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: GenUiSurface(
                key: ValueKey('${message.hashCode}_ui'),
                host: manager,
                surfaceId: uiPart.surfaceId,
              ),
            );
          } else {
            final String text = message.text;
            if (text.trim().isEmpty) {
              return const SizedBox.shrink();
            }
            return ChatMessageView(
              text: text,
              icon: Icons.smart_toy_outlined,
              alignment: MainAxisAlignment.start,
            );
          }
        } else if (message.role == ChatMessageRole.system) {
          return InternalMessageView(content: message.text);
        } else if (message.hasToolResults) {
          return InternalMessageView(content: message.toolResults.toString());
        }

        return const SizedBox.shrink();
      },
    );
  }
}
