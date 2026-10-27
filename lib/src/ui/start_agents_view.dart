import 'dart:async';

import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart';

import '../app/start_agents.dart';
import 'tokens.dart';
import 'wizard.dart';

/// Starts an agent for each of a project's repositories that names one: which repositories, the
/// sign-ins they need, a summary, and then the starts one after another.
///
/// [onLogIn] runs an agent's own login in a terminal on the machine; null where nothing here reaches it.
Future<void> openStartAgents(
  BuildContext context, {
  required StartAgents starting,
  Future<void> Function(Agent agent)? onLogIn,
}) async {
  try {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StartAgentsWizard(starting: starting, onLogIn: onLogIn),
    );
  } finally {
    // Closed however it is left: what is not sent yet is never sent, and no answer lands in a later opening.
    starting.close();
  }
}

/// The wizard itself, separated so it can be built directly in a test.
class StartAgentsWizard extends StatelessWidget {
  /// Constructor taking the model and the sign-in.
  const StartAgentsWizard({required this.starting, this.onLogIn, super.key});

  /// What is being started.
  final StartAgents starting;

  /// Runs an agent's own login on the machine, then asks again; null where not offered.
  final Future<void> Function(Agent agent)? onLogIn;

  @override
  Widget build(BuildContext context) => Wizard(
    title: 'Start an agent for each repository of ${starting.project?.name ?? ''}',
    changes: starting,
    action: 'Start them',
    actionKey: const Key('start-it'),
    reviewWords: 'Each agent starts attended, with its session and a shell for you, one after another.',
    steps: <WizardStep>[
      WizardStep(
        title: 'Which repositories',
        words:
            'Every repository whose project.yml names an agent is started with that agent. Uncheck one to leave '
            'it out; one that names no agent is listed but not offered.',
        panel: (context) => _Repositories(starting: starting),
        check: () {
          if (starting.busy) return 'Wait until the machine has said which agents and tasks it has.';
          if (starting.problem case final problem?) return problem;
          if (starting.toStart.isEmpty) return 'Nothing is left to start.';
          return null;
        },
        summary: () => <String>[for (final row in starting.rows) row.plan],
      ),
      WizardStep(
        title: 'Sign-ins',
        words:
            'An agent with nothing to sign in with on this machine is signed in first, with its own login in a '
            'terminal there. What it gives is kept in the vault, never by this program.',
        panel: (context) => _SignIns(starting: starting, onLogIn: onLogIn),
        check: () {
          if (!starting.asked) return 'Wait until the machine has said whether each agent can start.';
          if (starting.askProblem case final problem?) return problem;
          final missing = starting.signInsNeeded;
          if (missing.isNotEmpty) return 'Sign in to ${missing.map(_labelOf).join(', ')} first.';
          if (starting.held.isNotEmpty) return 'The machine says not every agent can start yet.';
          return null;
        },
        summary: () => <String>[
          for (final row in starting.toStart)
            row.readiness == null
                ? '${row.who}: this machine cannot say beforehand whether it can start'
                : '${row.who} can start here',
        ],
      ),
    ],
    actionSteps: <WizardActionStep>[
      WizardActionStep(
        title: 'Starting',
        words: 'Each task starts once the one before it exists; a refused one keeps its answer here.',
        panel: (context) => _Outcomes(starting: starting),
        run: starting.startAll,
        state: () => starting.starting || !starting.answered ? WizardActionState.running : WizardActionState.done,
      ),
    ],
  );
}

String _labelOf(Agent agent) => agent.label.isEmpty ? agent.name : agent.label;

class _Repositories extends StatelessWidget {
  const _Repositories({required this.starting});

  final StartAgents starting;

  @override
  Widget build(BuildContext context) {
    if (starting.busy) return const LinearProgressIndicator();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final row in starting.rows)
          if (!row.namesAnAgent || row.cannot != null || row.runs)
            ListTile(
              key: ValueKey<String>('start-agents-row ${row.repository}'),
              contentPadding: EdgeInsets.zero,
              leading: Icon(row.runs ? Icons.play_circle_outline : Icons.block_outlined, size: Sizes.rowIcon),
              title: Text(row.namesAnAgent ? row.who : row.repository),
              subtitle: Text(row.plan),
            )
          else
            CheckboxListTile(
              key: ValueKey<String>('start-agents-row ${row.repository}'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: row.chosen,
              onChanged: (chosen) => starting.choose(row.repository, chosen: chosen ?? false),
              title: Text(row.who),
              subtitle: Text(row.chosen ? row.plan : '${row.repository} is left out'),
            ),
      ],
    );
  }
}

class _SignIns extends StatelessWidget {
  const _SignIns({required this.starting, required this.onLogIn});

  final StartAgents starting;
  final Future<void> Function(Agent agent)? onLogIn;

  @override
  Widget build(BuildContext context) {
    if (!starting.asked) return const LinearProgressIndicator();
    final missing = starting.signInsNeeded;
    final held = starting.held.toList();
    final problem = starting.askProblem;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: Space.small,
      children: <Widget>[
        if (missing.isEmpty && held.isEmpty && problem == null)
          const Text('The machine says every agent to start can start.'),
        if (problem != null) Text(problem),
        for (final row in held) Text('${row.who} in ${row.repository}: ${row.held}'),
        for (final agent in missing)
          Wrap(
            spacing: Space.small,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text('Nothing is stored for ${_labelOf(agent)} on this machine yet.'),
              if (agent.canLogIn && onLogIn != null)
                FilledButton.icon(
                  key: ValueKey<String>('start-agents-sign-in ${agent.name}'),
                  onPressed: () => unawaited(onLogIn!(agent)),
                  icon: const Icon(Icons.login, size: Sizes.rowIcon),
                  label: Text('Sign in to ${_labelOf(agent)}'),
                )
              else
                Text('Sign in to ${_labelOf(agent)} on the machine itself, then ask again here.'),
            ],
          ),
        TextButton.icon(
          key: const Key('start-agents-ask-again'),
          onPressed: () => unawaited(starting.askAgain()),
          icon: const Icon(Icons.refresh, size: Sizes.rowIcon),
          label: const Text('Ask again'),
        ),
      ],
    );
  }
}

class _Outcomes extends StatelessWidget {
  const _Outcomes({required this.starting});

  final StartAgents starting;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: Space.small,
    children: <Widget>[
      for (final row in starting.rows)
        if (row.state != AgentStart.waiting)
          ListTile(
            key: ValueKey<String>('start-agents-outcome ${row.repository}'),
            contentPadding: EdgeInsets.zero,
            leading: switch (row.state) {
              AgentStart.starting => const SizedBox.square(
                dimension: Sizes.rowIcon,
                child: CircularProgressIndicator(strokeWidth: Sizes.spinnerStroke),
              ),
              AgentStart.started => const Icon(Icons.check_circle_outline, size: Sizes.rowIcon),
              _ => const Icon(Icons.error_outline, size: Sizes.rowIcon),
            },
            title: Text(switch (row.state) {
              AgentStart.starting => '${row.who} is starting',
              AgentStart.started => row.continues ? '${row.who} continues' : '${row.who} started',
              _ => '${row.who} was not started',
            }),
            subtitle: row.refusal == null ? null : Text(row.refusal!),
          ),
    ],
  );
}
