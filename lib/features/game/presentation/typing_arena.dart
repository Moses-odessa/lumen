import 'package:flutter/material.dart';

import '../../../domain/entities/circle_question.dart';

/// Режим «Набор»: поле ввода вместо круга.
///
/// Единственный режим, где ответ не выбирают, а производят целиком — потому
/// он и стоит выше всех по множителю. Артикль вводить не обязательно: он
/// проверяется, но его отсутствие не считается ошибкой (см.
/// [CircleQuestion.isCorrectInput]).
class TypingArena extends StatefulWidget {
  const TypingArena({
    super.key,
    required this.question,
    required this.onAnswer,
    this.enabled = true,
  });

  final CircleQuestion question;

  /// Введённый текст и время от появления круга до отправки.
  final void Function(String input, Duration latency) onAnswer;

  final bool enabled;

  @override
  State<TypingArena> createState() => _TypingArenaState();
}

class _TypingArenaState extends State<TypingArena> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  late DateTime _shownAt;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _shownAt = DateTime.now();
    // Клавиатура открывается сразу: лишний тап здесь — это потерянная
    // секунда в забеге, который весь длится минуту.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void didUpdateWidget(TypingArena oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question != widget.question) {
      _controller.clear();
      _shownAt = DateTime.now();
      _submitted = false;
      _focus.requestFocus();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    if (!widget.enabled || _submitted) return;
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    setState(() => _submitted = true);
    widget.onAnswer(text, DateTime.now().difference(_shownAt));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final question = widget.question;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              question.prompt,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            if (question.promptHint != null) ...[
              const SizedBox(height: 8),
              Text(
                question.promptHint!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 32),
            TextField(
              controller: _controller,
              focusNode: _focus,
              enabled: widget.enabled && !_submitted,
              textAlign: TextAlign.center,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              style: theme.textTheme.headlineSmall,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: widget.enabled && !_submitted ? _submit : null,
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }
}
