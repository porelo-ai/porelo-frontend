import 'package:flutter/material.dart';
import 'package:porelo_planning/porelo_planning.dart' show PlanningTaskOrder;

import '../client/porelo_client.dart' show AgentsOnTheMachine;
import 'planning_embedding.dart' show DiscussionChoice;
import 'start_work_view.dart' show StartAgentChoice;
import 'tokens.dart' show Sizes, Space;

/// Start's form for a discussion of an idea the planner ordered: the project fixed, every repository of it read only,
/// the agent and the model the person's to choose, the order's own offered first.
///
/// Closes with the choice, or with null where the person turns it away.
class DiscussionStartDialog extends StatefulWidget {
  /// Asks [agents] for what [machine] can start, for [task] of [project].
  const DiscussionStartDialog({
    required this.machine,
    required this.project,
    required this.task,
    required this.agents,
    super.key,
  });

  /// The name of the machine the discussion runs on.
  final String machine;

  /// The project whose repositories the agent reads.
  final String project;

  /// The planner's order.
  final PlanningTaskOrder task;

  /// The agents the machine can start.
  final Future<AgentsOnTheMachine> Function() agents;

  @override
  State<DiscussionStartDialog> createState() => _DiscussionStartDialogState();
}

class _DiscussionStartDialogState extends State<DiscussionStartDialog> {
  late final _model = TextEditingController(text: widget.task.model)..addListener(() => setState(() {}));
  AgentsOnTheMachine? _listed;
  Object? _problem;
  String? _agent;

  @override
  void initState() {
    super.initState();
    widget.agents().then(
      (listed) {
        if (!mounted) return;
        final names = listed.agents.map((agent) => agent.name);
        setState(() {
          _listed = listed;
          // The order's agent first where the machine has it.
          _agent = names.contains(widget.task.agent) ? widget.task.agent : names.firstOrNull;
        });
      },
      onError: (Object error) {
        if (mounted) setState(() => _problem = error);
      },
    );
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Discuss an idea in ${widget.project}'),
    content: SizedBox(
      width: Sizes.dialog,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'On ${widget.machine}, every repository of the project, read only: the agent changes nothing and pushes '
            'nothing. You lead the talk; once you agree, it writes ${widget.task.result ?? 'its result'}.',
          ),
          const SizedBox(height: Space.normal),
          ...switch ((_problem, _listed)) {
            (final problem?, _) => [Text('The agents of ${widget.machine} could not be read: $problem')],
            (_, final listed?) => _choices(context, listed),
            _ => const [LinearProgressIndicator()],
          },
          const SizedBox(height: Space.normal),
          TextField(
            key: const Key('discussion-model'),
            controller: _model,
            decoration: const InputDecoration(labelText: 'Model', border: OutlineInputBorder()),
          ),
        ],
      ),
    ),
    actions: <Widget>[
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(
        key: const Key('discussion-start'),
        onPressed: switch ((_agent, _model.text.trim())) {
          // Read as pressed, so the last letter typed is never lost.
          (final agent?, final model) when model.isNotEmpty => () => Navigator.pop<DiscussionChoice>(context, (
            agent: agent,
            model: _model.text.trim(),
          )),
          _ => null,
        },
        child: const Text('Start'),
      ),
    ],
  );

  List<Widget> _choices(BuildContext context, AgentsOnTheMachine listed) => [
    if (listed.agents.isEmpty)
      const Text('No agent is installed on this machine; nothing can be started until one is.')
    else
      DropdownButtonFormField<String>(
        key: const Key('discussion-agent'),
        initialValue: _agent,
        isExpanded: true,
        itemHeight: null,
        decoration: const InputDecoration(labelText: 'Agent', border: OutlineInputBorder()),
        items: <DropdownMenuItem<String>>[
          for (final agent in listed.agents)
            DropdownMenuItem<String>(
              value: agent.name,
              child: StartAgentChoice(agent: agent),
            ),
        ],
        onChanged: (agent) => setState(() => _agent = agent),
      ),
    // Shown, never dropped: an agent missing from a list looks exactly like one that was never installed.
    for (final failure in listed.failures.entries)
      Padding(
        padding: const EdgeInsets.only(top: Space.tight),
        child: Text('${failure.key} could not be read: ${failure.value}', style: Theme.of(context).textTheme.bodySmall),
      ),
  ];
}
