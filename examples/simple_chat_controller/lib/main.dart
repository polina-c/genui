// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:dartantic_ai/dartantic_ai.dart' as dartantic;
import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:logging/logging.dart';

import 'api_key/io_get_api_key.dart'
    if (dart.library.html) 'api_key/web_get_api_key.dart';
import 'message.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureGenUiLogging(level: Level.ALL);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple Chat Controller',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final List<MessageController> _messages = [];
  final ScrollController _scrollController = ScrollController();

  late final GenUiController _genUiController;
  late final A2uiMessageProcessor _processor;
  late final dartantic.GoogleProvider _provider;
  late final dartantic.Agent _agent;
  final List<dartantic.ChatMessage> _chatHistory = [];
  final ValueNotifier<bool> _isProcessing = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    final Catalog catalog = CoreCatalogItems.asCatalog();

    // Initialize GenUiController
    // Initialize GenUiController
    _processor = A2uiMessageProcessor(catalogs: [catalog]);
    _genUiController = GenUiController(messageProcessor: _processor);

    // Listen to UI state updates from the controller
    _genUiController.stateStream.listen((update) {
      if (update is SurfaceAdded) {
        if (!mounted) return;
        // Check if we already have a message with this surfaceId
        final bool exists = _messages.any(
          (m) => m.surfaceId == update.surfaceId,
        );

        if (!exists) {
          setState(() {
            _messages.add(
              MessageController(
                isUser: false,
                text: null,
                surfaceId: update.surfaceId,
              ),
            );
          });
          _scrollToBottom();
        }
      }
    });

    // Listen to client events (interactions) from the UI
    _genUiController.onClientEvent.listen(_handleChatMessage);

    final String a2uiSchema = A2uiMessage.a2uiMessageSchema(
      catalog,
    ).toJson(indent: '  ');

    final systemInstruction =
        '''You are a helpful assistant who chats with a user.
Your responses should contain acknowledgment of the user message.

IMPORTANT: When you generate UI in a response, you MUST always create
a new surface with a unique `surfaceId`. Do NOT reuse or update
existing `surfaceId`s. Each UI response must be in its own new surface.

<a2ui_schema>
$a2uiSchema
</a2ui_schema>

${StandardCatalogEmbed.standardCatalogRules}

${GenUiPromptFragments.basicChat}''';

    // Initialize Dartantic Provider and Agent
    final String apiKey = getApiKey();

    _provider = dartantic.GoogleProvider(apiKey: apiKey);

    _agent = dartantic.Agent.forProvider(
      _provider,
      chatModelName: 'gemini-3-flash-preview',
    );

    // Add system instruction to history
    _chatHistory.add(dartantic.ChatMessage.system(systemInstruction));
  }

  void _handleChatMessage(ChatMessage event) {
    genUiLogger.info('Received chat message: ${event.toJson()}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat (Controller + Dartantic)')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final MessageController message = _messages[index];
                  // Pass the processor as the host.
                  return ListTile(
                    title: MessageView(message, _processor),
                    tileColor: message.isUser
                        ? Colors.blue.withValues(alpha: 0.1)
                        : null,
                  );
                },
              ),
            ),

            ValueListenableBuilder(
              valueListenable: _isProcessing,
              builder: (_, isProcessing, _) {
                if (!isProcessing) return Container();
                return const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                );
              },
            ),

            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: const InputDecoration(
                        hintText: 'Type your message...',
                      ),
                      enabled: !_isProcessing.value,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _isProcessing.value ? null : _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final String text = _textController.text;
    if (text.isEmpty) return;
    _textController.clear();

    setState(() {
      _messages.add(MessageController(isUser: true, text: 'You: $text'));
    });
    _scrollToBottom();
    _isProcessing.value = true;

    try {
      _chatHistory.add(dartantic.ChatMessage.user(text));

      var fullResponseText = '';

      // Create a message controller for the AI response
      final aiMessageController = MessageController(
        isUser: false,
        text: 'AI: ',
      );
      setState(() {
        _messages.add(aiMessageController);
      });
      _scrollToBottom();

      // Listen for text updates from the controller to update the UI
      final StreamSubscription<String> subscription = _genUiController
          .textStream
          .listen((chunk) {
            if (!mounted) return;
            aiMessageController.text = (aiMessageController.text ?? '') + chunk;
            setState(() {});
            _scrollToBottom();
          });

      // Use sendStream() to receive chunks of the response.
      final Stream<dartantic.ChatResult<String>> stream = _agent.sendStream(
        text,
        history: List.of(_chatHistory),
      );

      await for (final result in stream) {
        final String chunk = result.output;
        if (chunk.isNotEmpty) {
          fullResponseText += chunk;
          _genUiController.addChunk(chunk);
        }
      }

      // Wait a bit to ensure the textStream processes the chunk
      await Future<void>.delayed(Duration.zero);

      await subscription.cancel();

      _chatHistory.add(dartantic.ChatMessage.model(fullResponseText));
    } catch (e, st) {
      genUiLogger.severe('Error generating content', e, st);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        _isProcessing.value = false;
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _genUiController.close();
    super.dispose();
  }
}
