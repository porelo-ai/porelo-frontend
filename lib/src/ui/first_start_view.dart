import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart';

import 'dialog_scroll.dart';
import 'tokens.dart';

/// Asks a person the first start's question in a checkout, or for [repository] in default with none here; true on a
/// yes, anything else leaves it as it is.
Future<bool?> askFirstStart(BuildContext context, {required FirstStart first, String? repository}) => showDialog<bool>(
  context: context,
  builder: (_) => FirstStartDialog(first: first, repository: repository),
);

/// The question a first start in a terminal asks: what was found, what it opens, and the file.
class FirstStartDialog extends StatelessWidget {
  /// Constructor taking what the machine answered.
  const FirstStartDialog({required this.first, this.repository, super.key});

  /// What the machine answered.
  final FirstStart first;

  /// The repository in default it is asked for when there is no checkout here; null for a checkout.
  final String? repository;

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
    final from = finding.source.isEmpty ? what : '$what  (${finding.source})';
    return finding.note.isEmpty ? from : '$from: ${finding.note}';
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
      title: Text(
        repository != null
            ? 'Keep these settings for $repository on this machine?'
            : isNew
            ? 'Write ${first.fileWords} for this checkout?'
            : 'Use the ${first.fileWords} in this checkout?',
      ),
      content: SizedBox(
        width: Sizes.dialog,
        child: DialogScroll(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SelectableText(
                repository != null
                    ? 'A yes keeps these settings for $repository on this machine only, never in the repository, '
                          'allows them, and work starts in ${first.project}. A no starts with Porelo\u2019s own '
                          'settings, keeps nothing, and the next first task asks again.'
                    : isNew
                    ? 'A yes writes it into the checkout, for you to commit, and work starts in ${first.project}. '
                          'A no starts as it would without one, keeps nothing, and the next start asks again.'
                    : 'This machine has not approved this file. A yes approves this text, and work starts in '
                          '${first.project}. A no starts as it would without one, keeps nothing, and the next start '
                          'asks again.',
                key: const Key('first-start-explained'),
              ),
              if (first.notes.isNotEmpty) ...<Widget>[
                heading('What the plugins say'),
                for (final (at, note) in first.notes.indexed)
                  SelectableText(note, key: ValueKey<String>('first-start-note $at')),
              ],
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
