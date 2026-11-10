import 'dart:async';

import 'package:flutter/material.dart';
import 'package:performance_list_view/performance_list_view.dart';

import 'data.dart';

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.fromUser,
    this.text = '',
    this.stream,
  });
  final int id;
  final bool fromUser;
  final String text;
  final StreamingTextController? stream;
}

/// An AI chat: replies stream token by token, the view stays pinned to the
/// bottom, and a pill jumps back down while you read history.
class ChatDemo extends StatefulWidget {
  const ChatDemo({
    super.key,
    this.tokenInterval = const Duration(milliseconds: 35),
    this.autoPrompt,
  });
  final Duration tokenInterval;

  /// Sends this prompt right away (screenshots).
  final String? autoPrompt;

  @override
  State<ChatDemo> createState() => _ChatDemoState();
}

class _ChatDemoState extends State<ChatDemo> {
  final _messages = PerformanceListController<ChatMessage>(
    initialItems: _history(),
  );
  final _typing = ValueNotifier(false);
  final _input = TextEditingController();
  final List<StreamingTextController> _streams = [];
  Timer? _thinking;
  int _nextId = 1000;

  static List<ChatMessage> _history() {
    const lines = [
      (true, 'Can a list stay smooth with 10,000 items?'),
      (
        false,
        'Yes. Only the items on screen are built, and each one is cached until it changes.',
      ),
      (true, 'What about loading more?'),
      (
        false,
        'Pages load once per scroll, also when the first page is short, and never twice at the same time.',
      ),
      (true, 'And if the network fails?'),
      (false, 'You get a retry button instead of an endless spinner.'),
    ];
    final out = <ChatMessage>[];
    for (var round = 0; round < 3; round++) {
      for (final (user, text) in lines) {
        out.add(ChatMessage(id: out.length, fromUser: user, text: text));
      }
    }
    return out.reversed.toList(); // newest first
  }

  @override
  void initState() {
    super.initState();
    if (widget.autoPrompt != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _send(widget.autoPrompt!),
      );
    }
  }

  @override
  void dispose() {
    _thinking?.cancel();
    for (final s in _streams) {
      s.dispose();
    }
    _messages.dispose();
    _typing.dispose();
    _input.dispose();
    super.dispose();
  }

  void _send(String text) {
    final prompt = text.trim();
    if (prompt.isEmpty || _typing.value) return;
    _input.clear();
    _messages.prepend(ChatMessage(id: _nextId++, fromUser: true, text: prompt));
    _typing.value = true;
    _thinking = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      _typing.value = false;
      final stream = StreamingTextController();
      _streams.add(stream);
      _messages.prepend(
        ChatMessage(id: _nextId++, fromUser: false, stream: stream),
      );
      stream.bind(
        tokenStream(
          assistantReplies[prompt] ?? fallbackReply,
          every: widget.tokenInterval,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Column(
          children: [
            Expanded(
              child: PerformanceChatView<ChatMessage>(
                controller: _messages,
                typing: _typing,
                itemKey: (m) => m.id,
                itemBuilder: (context, m, _) {
                  final stream = m.stream;
                  return ChatBubble(
                    isUser: m.fromUser,
                    header: m.fromUser
                        ? null
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome_rounded,
                                size: 14,
                                color: cs.primary,
                              ),
                              const SizedBox(width: 4),
                              const Text('Assistant'),
                            ],
                          ),
                    child: stream == null
                        ? Text(m.text)
                        : StreamingText(controller: stream),
                  );
                },
              ),
            ),
            _Composer(controller: _input, onSend: _send),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});
  final TextEditingController controller;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final prompt in assistantReplies.keys)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: ActionChip(
                        avatar: Icon(
                          Icons.bolt_rounded,
                          size: 16,
                          color: cs.primary,
                        ),
                        label: Text(prompt),
                        onPressed: () => onSend(prompt),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Material(
              color: cs.surfaceContainerHigh,
              shape: const StadiumBorder(),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 4, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        onSubmitted: onSend,
                        textInputAction: TextInputAction.send,
                        decoration: const InputDecoration(
                          hintText: 'Ask anything',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton.filled(
                      tooltip: 'Send',
                      onPressed: () => onSend(controller.text),
                      icon: const Icon(Icons.arrow_upward_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
