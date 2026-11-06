import 'dart:async';

import 'package:flutter/material.dart';

import 'tokens.dart';

/// A button that asks a machine something and waits for it.
///
/// From the press to the answer it is disabled and says what it waits for beside a small ring, so a second press
/// sends nothing; its answer, done or refused, then stands under it until the next press, where the person looks.
/// Every action that waits on a machine uses it, so a new one cannot leave a press unanswered.
class AskingButton extends StatefulWidget {
  /// Constructor taking the button's key, its label, what it waits for, and what it asks.
  const AskingButton({
    required this.buttonKey,
    required this.label,
    required this.waiting,
    required this.onAsk,
    this.filled = false,
    this.answerKey,
    this.first,
    super.key,
  });

  /// The pressed button's key, for a walk or a test to press it by.
  final Key buttonKey;

  /// What the button says.
  final Widget label;

  /// What it waits for while it asks, such as "Fetching from rehearsal…".
  final String waiting;

  /// Asks, answering what to say afterwards, or null for nothing; null where it cannot be pressed now.
  final Future<String?> Function()? onAsk;

  /// Whether it is the page's main action, drawn filled.
  final bool filled;

  /// The answer's key.
  final Key? answerKey;

  /// What the person decides before anything is asked, such as which project, answering whether to go on: it is no
  /// wait on a machine, so nothing turns while it is open.
  final Future<bool> Function()? first;

  @override
  State<AskingButton> createState() => _AskingButtonState();
}

class _AskingButtonState extends State<AskingButton> {
  bool _asking = false;
  String? _answer;

  Future<void> _press() async {
    if (_asking) return;
    if (widget.first case final first? when !await first()) return;
    if (!mounted) return;
    setState(() {
      _asking = true;
      _answer = null;
    });
    String? answer;
    try {
      answer = await widget.onAsk!();
    } finally {
      if (mounted) {
        setState(() {
          _asking = false;
          _answer = answer;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final onPressed = _asking || widget.onAsk == null ? null : () => unawaited(_press());
    final button = widget.filled
        ? FilledButton(key: widget.buttonKey, onPressed: onPressed, child: widget.label)
        : OutlinedButton(key: widget.buttonKey, onPressed: onPressed, child: widget.label);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        button,
        if (_asking)
          Padding(
            padding: const EdgeInsets.only(top: Space.tight),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox.square(
                  dimension: Sizes.mark,
                  child: CircularProgressIndicator(strokeWidth: Sizes.spinnerStroke),
                ),
                const SizedBox(width: Space.small),
                Flexible(child: Text(widget.waiting)),
              ],
            ),
          )
        else if (_answer case final answer?)
          Padding(
            padding: const EdgeInsets.only(top: Space.tight),
            child: Text(answer, key: widget.answerKey),
          ),
      ],
    );
  }
}
