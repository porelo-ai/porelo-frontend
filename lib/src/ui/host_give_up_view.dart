import 'dart:async';

import 'package:flutter/material.dart';

import '../app/host_give_up.dart';
import '../app/machines.dart';
import '../app/run_porelo.dart';
import '../app/session.dart' show OpenTerminal;
import 'tokens.dart';
import 'unlock_terminal.dart';

/// Asks whether [host] is to be given up for good; Cancel holds the focus first.
Future<bool> confirmGiveUp(BuildContext context, String host) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) {
        final error = Theme.of(context).colorScheme.error;
        return AlertDialog(
          title: Text('Give $host up for good?'),
          content: SizedBox(
            width: Sizes.dialogSmall,
            child: Text(
              "Porelo removes $host's keys from the central forge, with your token for it, and then deletes its "
              'identity from your Porelo-Vault. A server set up again under the name $host gets new keys. This '
              'cannot be undone.',
            ),
          ),
          actions: [
            TextButton(autofocus: true, onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            // Read by its label alone, as the button it is: its own text would be read after it again.
            Semantics(
              label: 'Give $host up for good, removing its keys and its identity',
              button: true,
              excludeSemantics: true,
              onTap: () => Navigator.pop(context, true),
              child: TextButton(
                style: TextButton.styleFrom(foregroundColor: error),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Give it up for good'),
              ),
            ),
          ],
        );
      },
    ) ??
    false;

/// What came of a give-up: its words, each key removed, and each key kept with why and where to remove it by hand.
class GiveUpResult extends StatelessWidget {
  /// Takes the outcome, the organization's central forge read afresh, and how a link is opened.
  const GiveUpResult({required this.outcome, required this.centralForge, required this.openLink, super.key});

  /// What came of it.
  final GiveUpOutcome outcome;

  /// The organization's central forge as read just now; a link elsewhere is never a button.
  final String? centralForge;

  /// Opens a link the person chose, in their browser.
  final ValueChanged<Uri> openLink;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    spacing: Space.small,
    children: [
      Text(outcome.words, key: const Key('give-up-words')),
      for (final row in outcome.removed) Text('Removed: ${row.named}'),
      for (final row in outcome.kept) ...[
        Text('Kept: ${row.named}: ${row.why ?? 'not said why'}'),
        if (offeredLink(row.link, centralForge) case final link?)
          Semantics(
            label: 'Open where ${row.named} is removed by hand',
            button: true,
            excludeSemantics: true,
            onTap: () => openLink(link),
            child: TextButton(onPressed: () => openLink(link), child: Text('Remove it there: $link')),
          )
        else if (row.link case final link?)
          // Not on the organization's own forge: said, never offered as a button.
          SelectableText(link),
      ],
    ],
  );
}

/// The hosts whose identity this computer's vault keeps, each with its give-up, on the Vault page: also a host given
/// back already, whose keys are still at the forge.
class KeptHostIdentities extends StatelessWidget {
  /// Takes the hosts, or why they could not be read, and give-up with why it cannot run.
  const KeptHostIdentities({
    required this.hosts,
    required this.whyNot,
    required this.onGiveUp,
    this.problem,
    super.key,
  });

  /// The hosts, or null where they could not be read.
  final List<String>? hosts;

  /// Why they could not be read.
  final String? problem;

  /// Why [String] cannot be given up now, or null.
  final String? Function(String host) whyNot;

  /// Gives a host up, after asking.
  final ValueChanged<String> onGiveUp;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    final small = Theme.of(context).textTheme.bodySmall;
    return Column(
      key: const Key('kept-host-identities'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Hosts whose identity your Porelo-Vault keeps', style: Theme.of(context).textTheme.titleSmall),
        if (hosts == null)
          Text('They cannot be listed: ${problem ?? 'not read yet'}.', style: small)
        else if (hosts!.isEmpty)
          Text('None.', style: small)
        else
          for (final host in hosts!)
            Row(
              children: [
                Expanded(child: Text(host)),
                if (whyNot(host) case final why?) Flexible(child: Text(why, style: small)),
                Semantics(
                  label: 'Give $host up for good',
                  button: true,
                  enabled: whyNot(host) == null,
                  excludeSemantics: true,
                  onTap: whyNot(host) == null ? () => onGiveUp(host) : null,
                  child: TextButton(
                    key: ValueKey('give-up $host'),
                    style: TextButton.styleFrom(foregroundColor: error),
                    onPressed: whyNot(host) == null ? () => onGiveUp(host) : null,
                    child: const Text('Give this host up for good…'),
                  ),
                ),
              ],
            ),
      ],
    );
  }
}

/// The organization's central forge for [outcome]'s links, read afresh by [centralForge]: only where a kept key has a
/// link, and for at most [limit]. Null where it is not read, or not in time: each link is then shown as text.
Future<String?> centralForLinks(
  GiveUpOutcome outcome,
  Future<String?> Function() centralForge, {
  Duration limit = const Duration(seconds: 10),
}) async {
  if (!outcome.kept.any((row) => row.link != null)) return null;
  try {
    // Widened first: a reader typed to answer a String alone would refuse the null of a read that took too long.
    return await centralForge().then<String?>((read) => read).timeout(limit, onTimeout: () => null);
  } on Exception {
    return null;
  }
}

/// Gives [host] up for good: asks, runs `porelo host give-up` in a terminal on this computer, where a token not in the
/// vault is typed with no echo, and says what came of it with each key. The window never reads or pipes a token.
///
/// [centralForge] reads the organization's central forge afresh for the links. [begin] marks it running once the person
/// confirmed, and refuses where it runs already; [done] is told how it ended, before its result shows.
Future<void> giveHostUp(
  BuildContext context, {
  required String host,
  required Future<String?> Function() centralForge,
  required ValueChanged<Uri> openLink,
  OpenTerminal? open,
  bool Function()? begin,
  Future<void> Function(GiveUpOutcome outcome)? done,
}) async {
  if (!await confirmGiveUp(context, host) || !context.mounted) return;
  if (!(begin?.call() ?? true)) return;
  GiveUpOutcome outcome = GiveUpOutcome('Give-up of $host did not start: nothing was removed.');
  String? central;
  try {
    outcome = await _giveUp(context, host, open);
    central = await centralForLinks(outcome, centralForge);
  } finally {
    await done?.call(outcome);
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(outcome.allGone ? '$host is given up' : 'Give-up of $host'),
      content: SizedBox(
        width: Sizes.dialog,
        child: SingleChildScrollView(
          child: GiveUpResult(outcome: outcome, centralForge: central, openLink: openLink),
        ),
      ),
      actions: [TextButton(autofocus: true, onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    ),
  );
}

Future<GiveUpOutcome> _giveUp(BuildContext context, String host, OpenTerminal? open) async {
  GiveUpOutcome outcome;
  try {
    final command = await poreloCommandHere(giveUpCommand(host));
    if (!context.mounted) return GiveUpOutcome('Give-up of $host did not start: nothing was removed.');
    String? answer;
    var last = '';
    final end = await runInATerminal(
      context,
      title: 'Give $host up for good',
      explanation:
          "Porelo removes $host's keys from the central forge with the token your Porelo-Vault keeps for it. Where it "
          'keeps none, type the token here when asked: it is not shown, goes straight to Porelo, and nothing here '
          'keeps it.',
      machine: Machine.local(),
      command: command,
      open: open,
      cancel: 'Stop giving it up',
      stillWorking: 'Removing the keys at the central forge.',
      lastLine: (line) => last = line,
      jsonAnswer: (read) => answer = read,
      jsonHolding: const ['removed', 'kept'],
    );
    outcome = giveUpOutcome(host: host, started: end.started, code: end.code, answer: answer, lastLine: last);
  } on PoreloNotStarted catch (refused) {
    outcome = GiveUpOutcome('Give-up of $host did not start: ${refused.words} Nothing was removed.');
  }
  return outcome;
}
