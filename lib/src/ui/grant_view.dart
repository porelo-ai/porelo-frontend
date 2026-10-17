import 'dart:async';

import 'package:flutter/material.dart';

import 'package:porelo_frontend/client.dart';

import '../app/fleet_model.dart';
import '../app/granting.dart';
import '../app/links.dart';
import '../app/machines.dart';
import 'dialog_scroll.dart';
import 'tokens.dart';

/// Asks the machine for an authorization and shows where it stands until it is settled.
Future<void> showGranting(BuildContext context, Granting granting) async {
  granting.start();
  await showDialog<void>(
    context: context,
    builder: (_) => GrantDialog(granting: granting),
  );
  granting.dispose();
}

/// Granting an authorization once, in a browser, for the account's later tasks.
///
/// **The link is shown whole and selectable**, as the machine sent it, and stays after it is opened:
/// the browser may be on another device. **The wait says it ends elsewhere**; nothing here spins
/// as though this interface were doing the work.
class GrantDialog extends StatelessWidget {
  /// Constructor taking what is being granted.
  const GrantDialog({required this.granting, super.key});

  /// What granting the authorization knows and does.
  final Granting granting;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: granting,
    builder: (context, _) {
      final text = Theme.of(context).textTheme;
      final scheme = Theme.of(context).colorScheme;
      return AlertDialog(
        key: const Key('grant-dialog'),
        title: Text('Grant ${granting.entry}'),
        content: SizedBox(
          width: Sizes.dialog,
          child: DialogScroll(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Granted once, it is kept in the vault on ${granting.machine.name}, and later tasks '
                  'use it without holding it or asking again.',
                  style: text.bodySmall,
                ),
                const SizedBox(height: Space.small),
                if (granting.problem != null)
                  Text(
                    granting.problem!,
                    key: const Key('grant-problem'),
                    style: TextStyle(color: scheme.error),
                  ),
                if (granting.state.isEmpty && granting.problem == null)
                  const Text('Asking the machine for the page to decide on…'),
                if (granting.link.isNotEmpty) ...<Widget>[
                  Text('Decide on this page, in any browser:', style: text.labelMedium),
                  const SizedBox(height: Space.tight),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(Space.small),
                    decoration: BoxDecoration(
                      border: Border.all(color: scheme.outlineVariant),
                      borderRadius: BorderRadius.circular(Radii.small),
                    ),
                    // Whole, as it came: never shortened, never assembled here.
                    child: SelectableText(
                      granting.link,
                      key: const Key('grant-link'),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                ],
                if (granting.code.isNotEmpty) ...<Widget>[
                  const SizedBox(height: Space.small),
                  Text('If the page asks for a code, it is:', style: text.labelMedium),
                  SelectableText(
                    granting.code,
                    key: const Key('grant-code'),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 18, letterSpacing: 2),
                  ),
                ],
                if (granting.port > 0 && granting.waiting) ...<Widget>[
                  const SizedBox(height: Space.small),
                  Text(
                    granting.forwarded
                        ? 'The page answers to port ${granting.port} on ${granting.machine.name}; that '
                              'port is forwarded from here while this is open, so open it in a browser on '
                              'this computer.'
                        : granting.forwardProblem ??
                              'Forwarding port ${granting.port} to ${granting.machine.name} first, so the '
                                  "page's answer can reach it…",
                    key: const Key('grant-forward'),
                    style: granting.forwardProblem == null ? text.bodySmall : TextStyle(color: scheme.error),
                  ),
                ],
                if (granting.waiting) ...<Widget>[
                  const SizedBox(height: Space.small),
                  Text(
                    'Waiting for the decision in the browser. It is made there, not here: '
                    '${granting.machine.name} hears the answer from the service, and this says what it '
                    'heard.${_expiry(granting.expiresAt)}',
                    key: const Key('grant-waiting'),
                  ),
                ],
                if (granting.settled) ...<Widget>[
                  const SizedBox(height: Space.small),
                  Text(
                    _settled(granting),
                    key: const Key('grant-settled'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: <Widget>[
          if (granting.waiting && granting.address != null)
            FilledButton(
              key: const Key('grant-open'),
              onPressed: granting.canOpen ? () => unawaited(granting.open(openLink)) : null,
              child: const Text('Open it in the browser here'),
            ),
          TextButton(
            key: const Key('grant-close'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(granting.waiting ? 'Stop waiting' : 'Done'),
          ),
        ],
      );
    },
  );

  static String _expiry(DateTime? at) {
    if (at == null) return '';
    String two(int value) => value.toString().padLeft(2, '0');
    final local = at.toLocal();
    return ' The question expires at ${two(local.hour)}:${two(local.minute)}.';
  }

  static String _settled(Granting granting) {
    final why = granting.detail.isEmpty ? '' : ': ${granting.detail}';
    return switch (granting.state) {
      // With the machine's own words where it says more: a token that never expires, say, which
      // removing it from the vault cannot end at the service.
      'granted' =>
        'Granted. It is kept in the vault on ${granting.machine.name}, and the next task uses it.'
            '${granting.detail.isEmpty ? '' : ' ${granting.detail}.'}',
      // Refused with a reason is the machine refusing what the service gave, not the person in the
      // browser: said as that.
      'refused' when granting.detail.isNotEmpty =>
        '${granting.machine.name} did not keep what the service granted$why. Nothing was granted.',
      'refused' => 'Refused in the browser. Nothing was granted.',
      'expired' => 'The question expired before anybody decided. Nothing was granted; ask again to get a new page.',
      'failed' => 'It failed$why.',
      _ => 'The machine answered ${granting.state}$why.',
    };
  }
}

/// An authorization somebody has to grant before work can use it, as a row in *Needs you*.
///
/// Raised by the machine, not by whoever happens to be starting work: a start refused for want of a
/// grant, or a grant the service ended, reaches the person who can answer it.
class AuthorizationRow extends StatelessWidget {
  /// Constructor taking the machine, its model and the question.
  const AuthorizationRow({required this.machine, required this.fleet, required this.needed, super.key});

  /// The machine the work runs on.
  final Machine machine;

  /// What the machine says about its work.
  final FleetModel fleet;

  /// The authorization the work waits for.
  final AuthorizationNeeded needed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      key: ValueKey<String>('authorization ${machine.name}/${needed.credential}'),
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(Space.normal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(headline(needed, machine.name), style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: Space.tight),
            Text(standing(needed.state)),
            if (needed.at.isNotEmpty) Text('Since ${needed.at}.', style: text.bodySmall),
            const SizedBox(height: Space.small),
            OutlinedButton.icon(
              key: ValueKey<String>('grant-needed ${needed.credential}'),
              onPressed: () => unawaited(showGranting(context, Granting(fleet.backend, machine, needed.credential))),
              icon: const Icon(Icons.verified_user_outlined, size: Sizes.rowIcon),
              label: const Text('Grant it'),
            ),
          ],
        ),
      ),
    );
  }

  /// Which credential, for which work, on which machine.
  static String headline(AuthorizationNeeded needed, String machine) {
    final forWhat = needed.task.isNotEmpty
        ? ' for ${needed.task}'
        : needed.project.isNotEmpty
        ? ' for work in ${needed.project}'
        : '';
    return '${needed.credential} needs a grant$forWhat, on $machine';
  }

  /// Never granted, or granted and then ended at the service: two different stories.
  static String standing(String state) => switch (state) {
    'never' =>
      'Nobody has granted it yet, so work that uses it cannot start unattended. It is granted '
          'once, in a browser, and later work uses it.',
    'ended' =>
      'It was granted, and the service has ended the grant: revoked, or expired. It needs '
          'granting again.',
    _ => 'The machine says: $state.',
  };
}
