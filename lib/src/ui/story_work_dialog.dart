import 'dart:async';

import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart';

import '../app/commands.dart';
import '../app/planning_board.dart';
import '../app/story_work.dart';
import 'tokens.dart';
import 'start_work_view.dart' show StartAgentChoice, StartModelField;
import 'window_size.dart';

/// The proposed work and explicit choices, read from the chosen machine.
class StoryWorkDialog extends StatefulWidget {
  /// Uses a form owned by the caller until the dialog closes.
  const StoryWorkDialog(this.work, {super.key});

  /// The current proposal, source, choices and refusal.
  final StoryWork work;
  @override
  State<StoryWorkDialog> createState() => _StoryWorkDialogState();
}

class _StoryWorkDialogState extends State<StoryWorkDialog> {
  StoryWork get work => widget.work;
  late final VoidCallback _stopFollowing;
  @override
  void initState() {
    super.initState();
    _stopFollowing = work.follow(_changed);
    unawaited(work.load());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _stopFollowing();
    super.dispose();
  }

  String _said(String text) => text.isEmpty ? 'not reported' : text;

  @override
  Widget build(BuildContext context) {
    final proposal = work.proposal;
    final enabled = work.current && !work.busy;
    return PopScope(
      canPop: !work.busy || proposal == null,
      child: AlertDialog(
        key: const Key('story-work-dialog'),
        title: const Text('Start work'),
        content: SizedBox(
          width: Sizes.dialog,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${work.story.id} — ${_said(work.story.title)}'),
                Text('${_said(work.story.state)} → ${work.to}'),
                DropdownButtonFormField<PlanningBoard>(
                  key: const Key('story-work-machine'),
                  initialValue: work.board,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Machine'),
                  items: [
                    for (final source in work.machines.entries)
                      DropdownMenuItem(
                        value: source.key,
                        enabled:
                            !source.key.isDisposed &&
                            source.key.live &&
                            source.key.snapshot?.complete == true &&
                            source.key.snapshot!.revision.isNotEmpty,
                        child: Text(
                          source.key.live && source.key.snapshot?.complete == true
                              ? source.value
                              : '${source.value} — planning not live',
                        ),
                      ),
                    for (final machine in work.unavailableMachines)
                      DropdownMenuItem<PlanningBoard>(
                        enabled: false,
                        child: Text('$machine — project planning not reported'),
                      ),
                  ],
                  onChanged: work.starting || work.result != null
                      ? null
                      : (source) {
                          if (source != null) work.changeMachine(source);
                        },
                ),
                DropdownButtonFormField<String>(
                  key: const Key('story-work-target'),
                  initialValue: work.to,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Working state'),
                  items: [
                    for (final state in {
                      work.to,
                      ...work.board.states.where((state) => state.kind == 'WORKING').map((state) => state.name),
                    })
                      DropdownMenuItem(value: state, child: Text(state)),
                  ],
                  onChanged: !work.sourceCurrent || work.busy
                      ? null
                      : (value) {
                          if (value != null) work.changeTarget(value);
                        },
                ),
                if (work.busy) const Text('Waiting for the machine’s answer…'),
                if (!work.current)
                  const Text('The board changed or is no longer live. Cancel and open Start work again.'),
                if (work.problem case final problem?) ...[
                  Text(problem, key: const Key('story-work-error')),
                  TextButton(
                    key: const Key('story-work-retry'),
                    onPressed: work.busy ? null : () => unawaited(work.load()),
                    child: const Text('Retry proposal'),
                  ),
                ],
                if (proposal != null)
                  KeyedSubtree(key: ObjectKey(proposal), child: _proposal(context, proposal, enabled)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            key: const Key('story-work-cancel'),
            onPressed: work.busy && proposal != null
                ? null
                : planningCommand(
                    id: 'story-work.cancel',
                    label: 'Cancel',
                    run: () => Navigator.pop(context, false),
                  ).run,
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('story-work-start'),
            onPressed: !work.canStart
                ? null
                : planningCommand(
                    id: 'story-work.start',
                    label: work.startLabel,
                    run: () async {
                      final started = await work.start();
                      if (context.mounted && started) Navigator.pop(context, true);
                    },
                  ).run,
            child: Text(work.startLabel),
          ),
        ],
      ),
    );
  }

  Widget _proposal(BuildContext context, StoryWorkProposal proposal, bool enabled) {
    final modes = proposal.modes.where((mode) => ['UNATTENDED', 'AGENT'].contains(mode)).toSet();
    final cards = [for (final mode in modes) _mode(context, proposal, mode, enabled)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Space.normal),
        const Text('How to work'),
        if (cards.isEmpty) const Text('The machine offered no supported modes.'),
        if (WindowSize.fromContext(context) == WindowSize.compact)
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: cards)
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final card in cards) Expanded(child: card)],
          ),
        const SizedBox(height: Space.normal),
        const Text('Tasks to start'),
        const Text('Name and repository come from the story and its issues; nothing to type.'),
        for (final repo in proposal.repositories) ...[
          const SizedBox(height: Space.normal),
          Text(
            '${repo.task} · ${repo.repository}',
            key: Key('story-work-task ${repo.repository}'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(
            'Issues: ${repo.issues.isEmpty ? 'none' : repo.issues.join(', ')}',
            key: Key('story-work-issues ${repo.repository}'),
          ),
          _agentPicker(
            key: Key('story-work-main-agent ${repo.repository}'),
            value: work.repositories[repo.repository]!.agent,
            enabled: enabled,
            proposed: repo.agent,
            choose: (agent) => work.chooseMain(repo.repository, agent: agent),
          ),
          StartModelField(
            fieldKey: Key('story-work-main-model ${repo.repository}'),
            initialValue: work.repositories[repo.repository]!.model,
            help: _said(repo.modelHint),
            hint: 'not reported',
            enabled: enabled,
            onChanged: (value) => work.chooseMain(repo.repository, model: value),
          ),
          for (final sub in repo.subAgents) _sub(repo.repository, sub, enabled),
          ExpansionTile(
            title: Text('The work order for ${repo.task}'),
            children: [SelectableText(_said(repo.workOrder), key: Key('story-work-order ${repo.repository}'))],
          ),
        ],
        if (proposal.coordinator case final coordinator?) ...[
          const SizedBox(height: Space.normal),
          Text('Coordinator · ${_said(coordinator.agent)} · ${_said(coordinator.model)}'),
          Text(_said(coordinator.sentence), key: const Key('story-work-coordinator')),
        ],
        ExpansionTile(
          title: const Text('The work order the agent gets'),
          children: [
            SelectableText(
              _said(proposal.modeDetails.where((each) => each.mode == work.mode).firstOrNull?.workOrder ?? ''),
              key: const Key('story-work-order'),
            ),
          ],
        ),
        const SizedBox(height: Space.normal),
        TextFormField(
          key: const Key('story-work-comment'),
          initialValue: work.comment,
          maxLines: null,
          enabled: enabled,
          decoration: InputDecoration(
            labelText: 'Comment',
            helperText: work.needsComment ? 'Required when a sub-agent is changed or dropped.' : 'Optional',
          ),
          onChanged: work.setComment,
        ),
        TextFormField(
          key: const Key('story-work-rounds'),
          initialValue: work.rounds,
          keyboardType: TextInputType.number,
          enabled: enabled,
          decoration: const InputDecoration(labelText: 'Most reading rounds', helperText: 'A whole number, 1 or more.'),
          onChanged: (value) => work.setRounds(value),
        ),
        if (proposal.issues.isNotEmpty)
          ExpansionTile(
            title: const Text('Per issue'),
            children: [
              for (final issue in proposal.issues)
                TextFormField(
                  key: Key('story-work-rounds ${issue.id}'),
                  initialValue: work.issueRounds[issue.id],
                  keyboardType: TextInputType.number,
                  enabled: enabled,
                  decoration: InputDecoration(labelText: '${issue.id} · ${issue.repository}', hintText: work.rounds),
                  onChanged: (value) => work.setRounds(value, issue.id),
                ),
            ],
          ),
      ],
    );
  }

  Widget _mode(BuildContext context, StoryWorkProposal proposal, String mode, bool enabled) => Card(
    key: Key('story-work-mode $mode'),
    color: work.mode == mode ? Theme.of(context).colorScheme.primaryContainer : null,
    child: InkWell(
      onTap: !enabled ? null : () => work.chooseMode(mode),
      child: Padding(
        padding: const EdgeInsets.all(Space.normal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(work.mode == mode ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                const SizedBox(width: Space.small),
                Flexible(child: Text(mode == 'UNATTENDED' ? 'Unattended' : 'With you')),
              ],
            ),
            Text(_said(proposal.modeDetails.where((each) => each.mode == mode).firstOrNull?.words ?? '')),
          ],
        ),
      ),
    ),
  );

  Widget _agentItem(String name) {
    final agent = work.agents.where((agent) => agent.name == name).firstOrNull;
    return agent == null ? Text(name) : StartAgentChoice(agent: agent);
  }

  Widget _agentPicker({
    required Key key,
    required String value,
    required String proposed,
    required bool enabled,
    required ValueChanged<String> choose,
  }) {
    final names = {
      if (proposed.isNotEmpty) proposed,
      ...work.agents.map((agent) => agent.name),
      if (value.isNotEmpty) value,
    };
    return DropdownButtonFormField<String>(
      key: key,
      initialValue: value.isEmpty ? null : value,
      isExpanded: true,
      itemHeight: null,
      decoration: const InputDecoration(labelText: 'Agent', hintText: 'not reported', border: OutlineInputBorder()),
      items: [for (final name in names) DropdownMenuItem(value: name, child: _agentItem(name))],
      onChanged: !enabled
          ? null
          : (value) {
              if (value != null) choose(value);
            },
    );
  }

  Widget _sub(String repository, StoryWorkSubAgent sub, bool enabled) {
    final chosen = work.choices[(repository, sub.name)]!;
    return Padding(
      key: Key('story-work-sub $repository ${sub.name}'),
      padding: const EdgeInsets.only(top: Space.small),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${_said(sub.name)} · ${_said(sub.role)} · ${_said(sub.agent)} · ${_said(sub.model)}'),
          if (sub.brief.isNotEmpty) Text(sub.brief),
          Wrap(
            spacing: Space.small,
            children: [
              for (final choice in ['KEEP', 'CHANGE', 'DROP'])
                ChoiceChip(
                  key: Key('story-work-choice $repository ${sub.name} $choice'),
                  label: Text(switch (choice) {
                    'KEEP' => 'Keep',
                    'CHANGE' => 'Change',
                    _ => 'Drop',
                  }),
                  selected: chosen.choice == choice,
                  onSelected: !enabled ? null : (_) => work.choose(repository, sub, choice),
                ),
            ],
          ),
          if (chosen.choice == 'CHANGE') ...[
            _agentPicker(
              key: Key('story-work-agent $repository ${sub.name}'),
              value: chosen.agent ?? '',
              proposed: sub.agent,
              enabled: enabled,
              choose: (value) => work.choose(repository, sub, 'CHANGE', agent: value),
            ),
            StartModelField(
              fieldKey: Key('story-work-model $repository ${sub.name}'),
              initialValue: chosen.model,
              enabled: enabled,
              hint: 'Choose a model',
              onChanged: (value) => work.choose(repository, sub, 'CHANGE', model: value),
            ),
          ],
        ],
      ),
    );
  }
}
