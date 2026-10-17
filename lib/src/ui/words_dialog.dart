import 'package:flutter/material.dart';

import 'tokens.dart';
import 'dialog_scroll.dart';

/// Asks for a person's own words before an act that hands them to a task's agent: why a push is
/// dropped, or anything a person wants to tell it. Answers the words, empty where they were left
/// out and [required] is false, or null when the person did not go on.
Future<String?> askForWords(
  BuildContext context, {
  required String title,
  required String explain,
  required String label,
  required String confirm,
  bool required = false,
}) => showDialog<String>(
  context: context,
  builder: (_) => WordsDialog(title: title, explain: explain, label: label, confirm: confirm, required: required),
);

/// The dialog [askForWords] shows.
class WordsDialog extends StatefulWidget {
  /// Constructor taking what it says.
  const WordsDialog({
    required this.title,
    required this.explain,
    required this.label,
    required this.confirm,
    this.required = false,
    super.key,
  });

  /// What the dialog is called.
  final String title;

  /// What the words are for, above the field.
  final String explain;

  /// The field's label.
  final String label;

  /// The confirming button's words.
  final String confirm;

  /// Whether going on needs words at all.
  final bool required;

  @override
  State<WordsDialog> createState() => _WordsDialogState();
}

class _WordsDialogState extends State<WordsDialog> {
  final _words = TextEditingController();

  @override
  void dispose() {
    _words.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const Key('words-dialog'),
    title: Text(widget.title),
    content: SizedBox(
      width: Sizes.dialog,
      child: DialogScroll(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(widget.explain, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: Space.small),
            TextField(
              key: const Key('words'),
              controller: _words,
              autofocus: true,
              minLines: 2,
              maxLines: 8,
              decoration: InputDecoration(labelText: widget.label),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
    ),
    actions: <Widget>[
      TextButton(
        key: const Key('words-cancel'),
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('words-confirm'),
        onPressed: widget.required && _words.text.trim().isEmpty
            ? null
            : () => Navigator.of(context).pop(_words.text.trim()),
        child: Text(widget.confirm),
      ),
    ],
  );
}
