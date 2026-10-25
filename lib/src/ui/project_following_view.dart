import 'dart:async';

import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart';

import '../app/project_following.dart';
import 'choice_field.dart';
import 'tokens.dart';
import 'dialog_scroll.dart';

/// Follows a project's repository — the only way a project comes to a machine.
///
/// **How its commits are checked is chosen, never defaulted.** Pinning a key means only commits
/// signed with it are taken; following unverified means whoever can push to the repository decides
/// what this machine runs, and that is said beside the choice rather than after it.
///
/// **A rewritten history is a second decision, never a retry.** A properly signed commit that does
/// not descend from the one in force is either its owner rebasing or somebody re-serving an older
/// signed configuration to put back a rule that was taken away, and nothing here can tell which.
class ProjectFollowingPanel extends StatelessWidget {
  /// Constructor taking the answers and what each button does.
  const ProjectFollowingPanel({
    required this.following,
    required this.onFollow,
    required this.onDone,
    this.onUnlockHere,
    this.onSetUpItsConnection,
    this.onStoreInATerminal,
    this.onShowItsConnection,
    this.onFromARepository,
    super.key,
  });

  /// Following a project from its repository, step by step.
  final ProjectFollowing following;

  /// Follows it; with `true`, a person's answer to a rewritten history.
  final Future<void> Function({bool acceptRewrite}) onFollow;

  /// Puts it away, saying whether the project is now on the machine.
  final void Function(bool taken) onDone;

  /// Opens the machine's vault by its passphrase, for a credential that is in it.
  final VoidCallback? onUnlockHere;

  /// Sets up a connection for the repository's address, in the machine's connections.
  final VoidCallback? onSetUpItsConnection;

  /// Stores the missing value by the command the check named, typed into a terminal there.
  final VoidCallback? onStoreInATerminal;

  /// Opens the machine's connections, where a value that is not there is sent, replaced or forgotten.
  final VoidCallback? onShowItsConnection;

  /// Goes the way that needs nothing typed: a repository the person has on a forge, picked.
  final VoidCallback? onFromARepository;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: following,
    builder: (context, _) {
      final scheme = Theme.of(context).colorScheme;
      final answer = following.answer;
      return Align(
        alignment: Alignment.topCenter,
        child: AlertDialog(
          title: Text(following.taken ? 'Following' : 'Follow a project'),
          content: SizedBox(
            width: Sizes.dialog,
            child: DialogScroll(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (onFromARepository != null && !following.taken && following.answer == null) ...<Widget>[
                    Text(
                      'Is it on GitHub? Pick it from your repositories instead: nothing to type, and '
                      'the machine is given keys of its own there to work on it.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    TextButton(
                      key: const Key('follow-from-a-repository'),
                      onPressed: onFromARepository,
                      child: const Text('Pick one of your repositories'),
                    ),
                    const SizedBox(height: Space.small),
                  ],
                  if (following.held)
                    _Block(
                      color: scheme.surfaceContainerLow,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(following.checkWords, key: const Key('follow-check-says')),
                          if (following.check!.detail.isNotEmpty)
                            Text(following.check!.detail, style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: Space.small),
                          Wrap(
                            spacing: Space.small,
                            children: <Widget>[
                              if (following.check!.outcome == 'VAULT_LOCKED' && onUnlockHere != null)
                                OutlinedButton(
                                  key: const Key('follow-unlock'),
                                  onPressed: onUnlockHere,
                                  child: const Text('Open the vault'),
                                ),
                              if (following.check!.outcome == 'NO_CREDENTIAL' && onSetUpItsConnection != null)
                                OutlinedButton(
                                  key: const Key('follow-set-up-connection'),
                                  onPressed: onSetUpItsConnection,
                                  child: const Text('Set up its connection'),
                                ),
                              if (following.check!.storeCommand.isNotEmpty &&
                                  following.check!.storeStdin.isEmpty &&
                                  onStoreInATerminal != null)
                                OutlinedButton(
                                  key: const Key('follow-store-value'),
                                  onPressed: onStoreInATerminal,
                                  child: const Text('Store its value in a terminal'),
                                )
                              // A key is sent from its connection, and a file there is replaced there.
                              else if (const <String>{
                                    'MISSING_VALUE',
                                    'UNUSABLE_VALUE',
                                    'EXPIRED',
                                  }.contains(following.check!.outcome) &&
                                  onShowItsConnection != null)
                                OutlinedButton(
                                  key: const Key('follow-show-connection'),
                                  onPressed: onShowItsConnection,
                                  child: const Text('Show its connection'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  if (following.problem != null)
                    _Block(
                      color: scheme.surfaceContainerLow,
                      child: Text(following.problem!, key: const Key('follow-problem')),
                    )
                  else if (answer != null)
                    _Block(
                      color: following.taken ? scheme.surfaceContainerHighest : scheme.surfaceContainerLow,
                      child: _WhatCameOfIt(
                        answer: answer,
                        onShowConnections: onShowItsConnection,
                        onTrust: (fingerprint) => unawaited(following.trustAndFollowAgain(fingerprint)),
                        trustRefused: following.hostKeyRefused,
                        busy: following.busy,
                      ),
                    ),
                  if (!following.taken) ...<Widget>[
                    const Text(
                      'Name the project and where its repository is. The machine reads the '
                      'project from there — its project.yml and the repositories it names — '
                      'and says what is wrong with it. Work then starts in any of those '
                      'repositories.',
                    ),
                    const SizedBox(height: Space.small),
                    _Field(
                      id: 'follow-name',
                      label: 'What the project is called — the name in its project.yml',
                      value: following.name,
                      onChanged: (typed) => following.answerWith(() => following.name = typed),
                    ),
                    _Field(
                      id: 'follow-url',
                      label: "Where the project's own repository is — a URL, or a directory on that machine",
                      value: following.url,
                      onChanged: (typed) => following.answerWith(() => following.url = typed),
                    ),
                    ChoiceField<Checking>(
                      id: 'follow-checking',
                      label: 'How its commits are checked',
                      value: following.checking,
                      onChanged: (chosen) => following.answerWith(() => following.checking = chosen),
                      choices: const <Choice<Checking>>[
                        Choice(Checking.pinned, 'Only commits signed with this key', id: 'follow-pinned'),
                        Choice(
                          Checking.unverified,
                          'Unverified',
                          id: 'follow-unverified',
                          means:
                              'Anybody who can push to the repository decides what this '
                              'machine runs. Shown as unverified wherever the project is.',
                        ),
                      ],
                    ),
                    if (following.checking == Checking.pinned)
                      _Field(
                        id: 'follow-key',
                        // Its fingerprint works too — the string a refused signature shows.
                        label: 'The public key, or its fingerprint (SHA256:…)',
                        value: following.key,
                        onChanged: (typed) => following.answerWith(() => following.key = typed),
                      ),
                  ],
                ],
              ),
            ),
          ),
          actions: <Widget>[
            if (following.taken)
              FilledButton(key: const Key('follow-done'), onPressed: () => onDone(true), child: const Text('Go to it'))
            else ...<Widget>[
              TextButton(key: const Key('follow-leave'), onPressed: () => onDone(false), child: const Text('Leave it')),
              if (following.rewritten)
                OutlinedButton(
                  key: const Key('follow-accept-rewrite'),
                  onPressed: following.busy ? null : () => onFollow(acceptRewrite: true),
                  child: const Text('Take the rewritten history'),
                ),
              // While a host key is the question, following again only asks it again: the way on
              // is trusting a key, beside the keys, or changing what was typed.
              if (!following.waitsOnAHostKey)
                FilledButton(
                  key: const Key('follow-it'),
                  onPressed: following.ready && !following.busy ? () => onFollow() : null,
                  child: const Text('Follow it'),
                ),
            ],
          ],
        ),
      );
    },
  );
}

/// What the machine made of it, in the same words the project's header uses.
class _WhatCameOfIt extends StatelessWidget {
  const _WhatCameOfIt({
    required this.answer,
    this.onShowConnections,
    this.onTrust,
    this.trustRefused,
    this.busy = false,
  });

  final Followed answer;

  /// Trusts the key with this fingerprint of the host the answer names, and follows again.
  final ValueChanged<String>? onTrust;

  /// Why trusting recorded nothing, or null.
  final String? trustRefused;

  final bool busy;

  /// Opens the machine's connections: a repository that turned the machine away is answered there.
  final VoidCallback? onShowConnections;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(answer.words, key: const Key('follow-says')),
        if (answer.signer.isNotEmpty) SelectableText('Signed by ${answer.signer}', style: text.bodySmall),
        if (answer.detail.isNotEmpty) Text(answer.detail, style: text.bodySmall),
        if (answer.outcome == 'REWRITTEN')
          Text(
            'This is its owner rebasing, or somebody serving an older signed configuration to put '
            'back a rule that was taken away. Nothing here can tell which.',
            key: const Key('follow-rewrite-cost'),
            style: text.bodySmall,
          ),
        if (answer.hostKeys.isNotEmpty)
          _HostKeysOffered(
            answer: answer,
            // A key that changed is never offered to be trusted instead: it may be somebody in between.
            onTrust: answer.outcome == 'UNKNOWN_HOST_KEY' && answer.host.isNotEmpty && !busy ? onTrust : null,
            refused: trustRefused,
          ),
        if (const <String>{'UNREACHABLE', 'NO_CREDENTIAL'}.contains(answer.outcome) && onShowConnections != null)
          Padding(
            padding: const EdgeInsets.only(top: Space.small),
            child: OutlinedButton(
              key: const Key('follow-show-connections'),
              onPressed: onShowConnections,
              child: const Text('Show the connections'),
            ),
          ),
      ],
    );
  }
}

/// What a host offers, for a person to compare with what they were told, and to trust one of.
///
/// **The comparison is the point, not the screen**: a fingerprint shown here is what somebody in
/// the middle would also be showing, so the sentence sends the person to the host's own published
/// fingerprints. Nothing is chosen for them, and leaving it is the default.
class _HostKeysOffered extends StatefulWidget {
  const _HostKeysOffered({required this.answer, this.onTrust, this.refused});

  final Followed answer;
  final ValueChanged<String>? onTrust;
  final String? refused;

  @override
  State<_HostKeysOffered> createState() => _HostKeysOfferedState();
}

class _HostKeysOfferedState extends State<_HostKeysOffered> {
  String? _chosen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final answer = widget.answer;
    final host = answer.host.isEmpty ? 'the host' : answer.host;
    final trust = widget.onTrust;
    return Padding(
      padding: const EdgeInsets.only(top: Space.small),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: Space.small,
        children: <Widget>[
          Text('$host offers these keys right now:', style: text.bodyMedium),
          for (final key in answer.hostKeys)
            SelectableText(
              '${key.type}  ${key.fingerprint}',
              key: ValueKey<String>('host-key ${key.fingerprint}'),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          Text(
            answer.outcome == 'HOST_KEY_CHANGED'
                ? 'None of them is the key this machine remembers for $host. That is what somebody '
                      'in between looks like, so nothing is offered to trust here: find out at $host '
                      'why its key changed.'
                : 'Compare one with what you were told — the fingerprints $host publishes itself — '
                      'not with what this screen says, which is what somebody in the middle would also '
                      'be showing you.',
            key: const Key('host-key-compare'),
            style: text.bodySmall?.copyWith(color: answer.outcome == 'HOST_KEY_CHANGED' ? scheme.error : null),
          ),
          if (trust != null) ...<Widget>[
            ChoiceField<String>(
              id: 'host-key-choice',
              label: 'The key you compared',
              hint: 'Choose the one you compared',
              value: _chosen,
              onChanged: (chosen) => setState(() => _chosen = chosen),
              choices: <Choice<String>>[
                for (final key in answer.hostKeys)
                  Choice(key.fingerprint, '${key.type}  ${key.fingerprint}', id: 'host-key-${key.fingerprint}'),
              ],
            ),
            OutlinedButton(
              key: const Key('follow-trust-host-key'),
              onPressed: _chosen == null ? null : () => trust(_chosen!),
              child: const Text('Trust this key and follow again'),
            ),
          ],
          if (widget.refused != null)
            Text(
              widget.refused!,
              key: const Key('host-key-refused'),
              style: TextStyle(color: scheme.error),
            ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.id, required this.label, required this.value, required this.onChanged});

  final String id;
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Space.small),
    child: TextFormField(
      key: Key(id),
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      onChanged: onChanged,
    ),
  );
}

class _Block extends StatelessWidget {
  const _Block({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: Space.normal),
    padding: const EdgeInsets.all(Space.normal),
    decoration: BoxDecoration(
      color: color,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: Sizes.divider),
      borderRadius: BorderRadius.circular(Radii.small),
    ),
    child: child,
  );
}
