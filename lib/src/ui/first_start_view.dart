import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart';

import 'dialog_scroll.dart';
import 'tokens.dart';

/// Asks a person the first start's question in a checkout; true on a yes, anything else leaves it as it is.
Future<bool?> askFirstStart(BuildContext context, {required FirstStart first}) => showDialog<bool>(
  context: context,
  builder: (_) => FirstStartDialog(first: first),
);

/// The question a first start in a terminal asks: what was found, what it opens, and the file.
class FirstStartDialog extends StatelessWidget {
  /// Constructor taking what the machine answered.
  const FirstStartDialog({required this.first, super.key});

  /// What the machine answered.
  final FirstStart first;

  static const _unknown = 'unknown: ';

  String _findingWords(Finding finding) {
    final said = finding.value.startsWith(_unknown)
        ? 'could not be read: ${finding.value.substring(_unknown.length)}'
        : finding.value;
    // A real machine says `package.maven` with the value `maven`, and a setting it found with no value.
    final kind = finding.what.startsWith('package.') ? 'package' : finding.what;
    final what = kind.isEmpty
        ? said
        : said.isEmpty
        ? kind
        : '$kind: $said';
    return finding.source.isEmpty ? what : '$what  (${finding.source})';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isNew = first.outcome == FirstStart.askNew;
    // A host only the checkout names is the repository's own word: a yes is not what happens by a key's press.
    final yesIsTheDefault = first.marked.isEmpty;
    Widget heading(String words) => Padding(
      padding: const EdgeInsets.only(top: Space.small, bottom: Space.tight),
      child: Text(words, style: text.titleSmall),
    );
    return AlertDialog(
      key: const Key('first-start'),
      title: Text(isNew ? 'Write a project.yml for this checkout?' : 'Use the project.yml in this checkout?'),
      content: SizedBox(
        width: Sizes.dialog,
        child: DialogScroll(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SelectableText(
                isNew
                    ? 'A yes writes it into the checkout, for you to commit, and work starts in ${first.project}. '
                          'A no starts as it would without one, keeps nothing, and the next start asks again.'
                    : 'This machine has not approved this file. A yes approves this text, and work starts in '
                          '${first.project}. A no starts as it would without one, keeps nothing, and the next start '
                          'asks again.',
                key: const Key('first-start-explained'),
              ),
              if (first.found.isNotEmpty) heading('Found'),
              for (final finding in first.found) SelectableText(_findingWords(finding)),
              heading('The network it opens'),
              if (first.hosts.isEmpty) const Text('Nothing beyond what the agent needs.'),
              for (final host in first.hosts)
                if (first.marked.contains(host))
                  SelectableText(
                    '$host  only this checkout names it',
                    key: ValueKey<String>('first-start-marked $host'),
                    style: TextStyle(color: scheme.error),
                  )
                else
                  SelectableText(host),
              heading(isNew ? 'The file' : 'The files'),
              SelectableText(
                first.file,
                key: const Key('first-start-file'),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          key: const Key('first-start-no'),
          autofocus: !yesIsTheDefault,
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('No, start without it'),
        ),
        FilledButton(
          key: const Key('first-start-yes'),
          autofocus: yesIsTheDefault,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(isNew ? 'Yes, write it and start' : 'Yes, use it and start'),
        ),
      ],
    );
  }
}
