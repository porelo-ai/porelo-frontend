import 'dart:async';

import 'package:flutter/material.dart';

import '../app/agent_sign_in.dart';
import '../app/commands.dart';
import 'tokens.dart';

/// What a sign-in of an agent on a machine stands at, with *Sign in* and *End the sign-in*, each with its reason
/// where it cannot run now. Shared by the start form, the start of several agents and a refused start.
///
/// The login runs in its own task on the machine: the person follows its link and pastes its code in that task's
/// terminal, never into this program.
class SignInPanel extends StatelessWidget {
  /// Constructor taking the sign-in, why *Sign in* waits on something else ([busy]), and what opens a shut vault.
  const SignInPanel({required this.signingIn, this.busy, this.onOpenTheVault, this.keyed = 'start', super.key});

  /// The sign-in shown.
  final SigningIn signingIn;

  /// Why *Sign in* cannot run while something else is out, or null.
  final String? busy;

  /// Opens a shut vault with this device, then asks again; null where this device cannot.
  final Future<void> Function()? onOpenTheVault;

  /// What its controls' keys begin with, so two panels on one screen are told apart.
  final String keyed;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: signingIn,
    builder: (context, _) {
      final signIn = signInCommand(signingIn, busy: busy);
      final end = endTheSignInCommand(signingIn);
      final offersSignIn = !signingIn.signedIn || signingIn.heldByCanStart;
      final scheme = Theme.of(context).colorScheme;
      return Container(
        key: Key('$keyed-sign-in-panel'),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: Space.normal),
        padding: const EdgeInsets.all(Space.normal),
        decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(Radii.small)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: Space.small,
          children: <Widget>[
            if (signingIn.asking)
              Text('Asking ${signingIn.machine} whether ${signingIn.who} is signed in there…')
            else if (signingIn.starting)
              Text('Starting the sign-in to ${signingIn.who} on ${signingIn.machine}…'),
            if (signingIn.words case final words?) Text(words, key: Key('$keyed-sign-in-words')),
            if (signingIn.heldByCanStart && signingIn.state == 'SIGNED_IN' && !signingIn.waiting)
              Text(
                '${signingIn.machine} still says what ${signingIn.who} signs in with is missing for this start, '
                'so it does not start yet.',
              ),
            if (signingIn.waiting) const LinearProgressIndicator(),
            Wrap(
              spacing: Space.small,
              runSpacing: Space.small,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                if (offersSignIn)
                  Tooltip(
                    message: signIn.unavailable ?? '',
                    child: FilledButton.icon(
                      key: Key('$keyed-sign-in-button'),
                      onPressed: signIn.available ? signIn.run : null,
                      icon: const Icon(Icons.login, size: Sizes.rowIcon),
                      label: Text(signIn.label),
                    ),
                  ),
                if (signingIn.running || signingIn.ending)
                  Tooltip(
                    message: end.unavailable ?? '',
                    child: OutlinedButton.icon(
                      key: Key('$keyed-end-sign-in'),
                      onPressed: end.available ? end.run : null,
                      icon: const Icon(Icons.stop_circle_outlined, size: Sizes.rowIcon),
                      label: Text(end.label),
                    ),
                  ),
                if (signingIn.state == 'VAULT_SHUT' && onOpenTheVault != null)
                  TextButton.icon(
                    key: Key('$keyed-sign-in-open-the-vault'),
                    onPressed: () => unawaited(onOpenTheVault!()),
                    icon: const Icon(Icons.lock_open_outlined, size: Sizes.rowIcon),
                    label: const Text('Open the vault'),
                  ),
              ],
            ),
            // Listed with its reason, never only greyed out.
            if (offersSignIn && !signIn.available && !signingIn.asking && !signingIn.starting)
              Text('Sign in: not now, ${signIn.unavailable}.', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
    },
  );
}
