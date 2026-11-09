import 'dart:async';

import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart';

import '../app/planning_board.dart';
import 'tokens.dart';

final _planningLeaveDialogs = Expando<bool>();

/// Asks before leaving unsaved work; a save in flight must finish first.
Future<bool> confirmPlanningLeave(BuildContext context, Iterable<PlanningBoard> boards, {bool quitting = false}) async {
  final watched = boards.toList();
  final navigator = Navigator.of(context);
  if (_planningLeaveDialogs[navigator] == true) return false;
  if (!watched.any((board) => board.pending.isNotEmpty || board.saving)) return true;
  _planningLeaveDialogs[navigator] = true;
  try {
    return await showDialog<bool>(
          context: context,
          builder: (context) => ListenableBuilder(
            listenable: Listenable.merge(watched),
            builder: (context, _) {
              final saving = watched.any((board) => board.saving);
              final pending = watched.any((board) => board.pending.isNotEmpty);
              return AlertDialog(
                title: Text(
                  saving
                      ? 'Planning is saving'
                      : pending
                      ? 'Unsaved planning moves'
                      : 'Planning saved',
                ),
                content: Text(
                  saving
                      ? 'Wait for the machine’s answer before leaving.'
                      : !pending
                      ? 'The planning changes are saved. You can continue.'
                      : quitting
                      ? 'Closing the window loses unsaved planning moves. Close anyway?'
                      : 'These planning moves have not been saved. Leave them pending and continue?',
                ),
                actions: [
                  TextButton(
                    key: const Key('planning-stay'),
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Keep editing'),
                  ),
                  if (!saving)
                    TextButton(
                      key: const Key('planning-leave'),
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(quitting ? 'Close anyway' : 'Leave with moves pending'),
                    ),
                ],
              );
            },
          ),
        ) ??
        false;
  } finally {
    _planningLeaveDialogs[navigator] = false;
  }
}

/// The planning board and its unsaved moves, supplied by watched machines.
class PlanningView extends StatelessWidget {
  /// Takes the boards retained by the shell.
  const PlanningView({required this.boards, required this.onNeedsYou, required this.onStartRequested, super.key});

  /// The projects and their planning providers.
  final PlanningBoards boards;

  /// Opens Needs you for an issue stopped in Reading.
  final VoidCallback onNeedsYou;

  /// Hands working-state drops to the shell that owns starting work.
  final void Function(PlanStory story, PlanState state) onStartRequested;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: boards,
    builder: (context, _) {
      final board = boards.selected;
      if (board == null) return const Center(child: Text('No project planning has been read from this machine.'));
      return _BoardView(
        key: ObjectKey(board),
        board: board,
        projects: boards.projects,
        select: boards.select,
        providerProblems: boards.providerProblems,
        onNeedsYou: onNeedsYou,
        onStartRequested: onStartRequested,
      );
    },
  );
}

class _BoardView extends StatefulWidget {
  const _BoardView({
    required this.board,
    required this.projects,
    required this.select,
    required this.providerProblems,
    required this.onNeedsYou,
    required this.onStartRequested,
    super.key,
  });
  final PlanningBoard board;
  final List<String> projects;
  final ValueChanged<String> select;
  final List<String> providerProblems;
  final VoidCallback onNeedsYou;

  /// Hands working-state drops to the shell that owns starting work.
  final void Function(PlanStory story, PlanState state) onStartRequested;
  @override
  State<_BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<_BoardView> {
  late final _search = TextEditingController(text: board.preferences.search);
  Key _project = UniqueKey();
  PlanningBoard get board => widget.board;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: board,
    builder: (context, _) {
      if (board.unsupported) {
        return Center(
          child: Text('${board.backend.label} does not offer planning.', key: const Key('planning-no-planning')),
        );
      }
      final theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.all(Space.wide),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Planning', style: theme.textTheme.headlineSmall),
            Text('The stories of project ${board.project} by state, the most important first.'),
            Text('From ${board.backend.label}', style: theme.textTheme.bodySmall),
            const SizedBox(height: Space.normal),
            Wrap(
              spacing: Space.normal,
              runSpacing: Space.small,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (widget.projects.length > 1)
                  SizedBox(
                    key: const Key('planning-project'),
                    width: Sizes.listFilter,
                    child: DropdownButtonFormField<String>(
                      key: _project,
                      initialValue: board.project,
                      decoration: const InputDecoration(labelText: 'Project'),
                      isExpanded: true,
                      items: [for (final name in widget.projects) DropdownMenuItem(value: name, child: Text(name))],
                      onChanged: board.saving
                          ? null
                          : (name) async {
                              if (name != null &&
                                  name != board.project &&
                                  await confirmPlanningLeave(context, [board]) &&
                                  mounted) {
                                widget.select(name);
                              } else if (mounted) {
                                setState(() => _project = UniqueKey());
                              }
                            },
                    ),
                  ),
                SizedBox(
                  width: Sizes.listFilter,
                  child: DropdownButtonFormField<PlanningPriority>(
                    key: const Key('planning-priority'),
                    initialValue: board.preferences.priority,
                    decoration: const InputDecoration(labelText: 'Priority'),
                    isExpanded: true,
                    items: [
                      for (final priority in PlanningPriority.values)
                        DropdownMenuItem(value: priority, child: Text(priority.label)),
                    ],
                    onChanged: (priority) {
                      if (priority != null) board.filter(priority);
                    },
                  ),
                ),
                SizedBox(
                  width: Sizes.listFilter,
                  child: TextField(
                    key: const Key('planning-search'),
                    controller: _search,
                    onChanged: board.search,
                    decoration: const InputDecoration(
                      labelText: 'Search',
                      hintText: 'Story ID or a word',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                FilterChip(
                  key: const Key('planning-show-closed'),
                  label: Text('Show Finished and Rejected (${board.closedCount ?? '?'})'),
                  selected: board.preferences.showClosed,
                  onSelected: (_) => board.toggleClosed(),
                ),
              ],
            ),
            for (final problem in widget.providerProblems)
              Text(problem, style: TextStyle(color: theme.colorScheme.error)),
            if (!board.live && board.snapshot != null && board.problem == null)
              const Text('Waiting for the machine’s planning answer.'),
            if (board.problem case final problem?)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.small),
                child: Text(
                  problem,
                  key: const Key('planning-error'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            if (board.snapshot != null && !board.snapshot!.complete)
              const Text('The machine did not report the complete planning workflow and story list.'),
            if (board.problem != null)
              TextButton.icon(
                key: const Key('planning-retry'),
                onPressed: () => unawaited(board.retry()),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry planning'),
              ),
            if (board.moveProblem case final problem?)
              Text(
                problem,
                key: const Key('planning-move-error'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            if (board.snapshot != null)
              TextButton.icon(
                key: const Key('planning-reload'),
                onPressed: board.saving ? null : () => unawaited(board.reload()),
                icon: const Icon(Icons.refresh),
                label: const Text('Reload planning'),
              ),
            if (board.pending.isNotEmpty) Flexible(child: _pending(context)),
            const SizedBox(height: Space.normal),
            if (board.snapshot == null && board.problem == null)
              const Text('Waiting for the machine’s planning answer.'),
            Expanded(
              child: board.snapshot == null
                  ? const SizedBox.shrink()
                  : SingleChildScrollView(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final phase in board.phases)
                              if (board.statesIn(phase).isNotEmpty) _phase(context, phase),
                            if (board.unplaced.isNotEmpty)
                              SizedBox(
                                width: PlanningStyle.column,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Stories outside the reported workflow'),
                                    for (final story in board.unplaced) ...[
                                      Text('State: ${story.state.isEmpty ? 'not reported' : story.state}'),
                                      _card(context, story),
                                    ],
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      );
    },
  );

  Widget _phase(BuildContext context, PlanPhase phase) {
    final folded = board.preferences.foldedPhases.contains(phase.name);
    final states = board.statesIn(phase);
    final count = states.fold<int>(0, (count, state) => count + board.cards(state.name).length);
    return Container(
      key: Key('planning-phase ${phase.name}'),
      width: folded ? PlanningStyle.foldedColumn : PlanningStyle.column,
      margin: const EdgeInsets.only(right: Space.normal),
      padding: const EdgeInsets.all(Space.small),
      decoration: BoxDecoration(
        color: PlanningStyle.phase(Theme.of(context).colorScheme),
        borderRadius: BorderRadius.circular(Radii.medium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(phase.name.toUpperCase(), style: Theme.of(context).textTheme.labelLarge)),
              Text('$count'),
              IconButton(
                key: Key('planning-fold-phase ${phase.name}'),
                tooltip: '${folded ? 'Unfold' : 'Fold'} ${phase.name}',
                onPressed: () => board.foldPhase(phase.name),
                icon: Icon(folded ? Icons.chevron_right : Icons.chevron_left),
              ),
            ],
          ),
          for (final state in states) _state(context, state, phaseFolded: folded),
        ],
      ),
    );
  }

  Widget _state(BuildContext context, PlanState state, {required bool phaseFolded}) {
    final cards = board.cards(state.name);
    final folded = phaseFolded || board.preferences.foldedStates.contains(state.name);
    final theme = Theme.of(context);
    return DragTarget<String>(
      key: Key('planning-state ${state.name}'),
      onWillAcceptWithDetails: (details) =>
          !board.saving &&
          board.live &&
          board.stories.any((story) => story.id == details.data && board.displayedState(story) != state.name),
      onAcceptWithDetails: (details) {
        final story = board.stories.where((story) => story.id == details.data).firstOrNull;
        if (story == null || board.displayedState(story) == state.name) return;
        if (state.kind == 'WORKING') {
          widget.onStartRequested(story, state);
        } else {
          board.move(details.data, state.name);
        }
      },
      builder: (context, candidates, rejected) => Container(
        padding: const EdgeInsets.all(Space.tight),
        margin: const EdgeInsets.only(bottom: Space.small),
        decoration: BoxDecoration(
          color: state.kind == 'WORKING' ? PlanningStyle.working(theme.colorScheme) : null,
          borderRadius: BorderRadius.circular(Radii.small),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (candidates.isNotEmpty) Text('Drop here for ${state.name}'),
            Row(
              children: [
                if (state.kind == 'WORKING')
                  const Padding(
                    padding: EdgeInsets.only(right: Space.tight),
                    child: Icon(Icons.schedule, size: Sizes.mark),
                  ),
                Expanded(child: Text(state.name, style: theme.textTheme.labelMedium)),
                Text('${cards.length}'),
                if (!phaseFolded)
                  IconButton(
                    key: Key('planning-fold-state ${state.name}'),
                    tooltip: '${folded ? 'Unfold' : 'Fold'} ${state.name}',
                    onPressed: () => board.foldState(state.name),
                    icon: Icon(folded ? Icons.chevron_right : Icons.expand_more, size: Sizes.rowIcon),
                  ),
              ],
            ),
            if (state.kind.isEmpty)
              const Text('State kind not reported')
            else if (!{'WAITING', 'WORKING', 'CLOSED'}.contains(state.kind))
              Text(state.kind),
            if (folded)
              Wrap(
                spacing: Space.tight,
                runSpacing: Space.tight,
                children: [
                  for (final story in cards)
                    _drag(
                      story,
                      Tooltip(
                        message: '${story.id} — ${story.title} (${story.priority})',
                        child: Container(
                          key: Key('planning-card ${story.id}'),
                          padding: const EdgeInsets.all(Space.tight),
                          child: Wrap(
                            spacing: Space.tight,
                            children: [
                              _priority(context, story.priority, mark: true),
                              Text(story.id),
                              if (board.pending[story.id] case final move? when move.problem == null)
                                const Text('moved'),
                              if (board.pending[story.id]?.problem case final problem?) Text(problem),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              )
            else
              for (final story in cards) _card(context, story),
          ],
        ),
      ),
    );
  }

  Widget _pending(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxHeight: PlanningStyle.column),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${board.pending.length} state change(s) not saved yet:'),
          for (final entry in board.pending.entries)
            Wrap(
              key: Key('planning-pending ${entry.key}'),
              spacing: Space.small,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${entry.key} ${entry.value.from.isEmpty ? 'not reported' : entry.value.from} → ${entry.value.to}',
                ),
                if (entry.value.problem != null) Text(entry.value.problem!),
                TextButton(
                  key: Key('planning-undo ${entry.key}'),
                  onPressed: board.saving ? null : () => board.undo(entry.key),
                  child: const Text('Undo'),
                ),
              ],
            ),
          Wrap(
            spacing: Space.small,
            children: [
              TextButton(
                key: const Key('planning-undo-all'),
                onPressed: board.saving ? null : board.undoAll,
                child: const Text('Undo all'),
              ),
              FilledButton(
                key: const Key('planning-save'),
                onPressed: board.saving || !board.live ? null : () => unawaited(board.save()),
                child: Text(board.saving ? 'Saving…' : 'Save'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _drag(PlanStory story, Widget child) => Draggable<String>(
    data: story.id,
    maxSimultaneousDrags: board.saving || !board.live ? 0 : 1,
    feedback: Material(
      elevation: Space.tight,
      child: Padding(padding: const EdgeInsets.all(Space.small), child: Text(story.id)),
    ),
    childWhenDragging: Opacity(opacity: Opacities.stale, child: child),
    child: child,
  );

  Widget _priority(BuildContext context, String priority, {bool mark = false}) {
    final colors = PlanningStyle.priority(priority, Theme.of(context).colorScheme);
    final label = mark
        ? switch (priority) {
            'Highest' => '▲▲',
            'High' => '▲',
            'Medium' => '▬',
            'Low' => '▼',
            _ => priority.isEmpty ? '?' : priority,
          }
        : priority.isEmpty
        ? 'Priority not reported'
        : priority;
    return Semantics(
      label: priority.isEmpty ? 'Priority not reported' : priority,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Space.tight),
        decoration: BoxDecoration(color: colors.background, borderRadius: BorderRadius.circular(Radii.small)),
        child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.foreground)),
      ),
    );
  }

  String? _work(PlanStory story) {
    final work = story.work;
    if (work == null) return board.state(story.state)?.kind == 'WORKING' ? 'Work not reported' : null;
    if (work.atWork == false) return 'nobody at work';
    return [
      if (work.atWork == null) 'Work status not reported',
      if (work.coordinator?.isNotEmpty ?? false) work.coordinator!,
      if (work.tasks.isNotEmpty) '${work.tasks.length} ${work.tasks.length == 1 ? 'task' : 'tasks'}',
      if (work.agent.isNotEmpty) work.agent,
      if (work.model.isNotEmpty) work.model,
      if (work.mode.isNotEmpty)
        switch (work.mode) {
          'UNATTENDED' => 'unattended',
          'AGENT' => 'shell with you',
          _ => work.mode,
        },
      if (work.since.isNotEmpty) 'since ${work.since}',
    ].join(' · ');
  }

  Widget _reading(PlanStory story) {
    final reading = story.issues.where((issue) => issue.state == 'Reading' || issue.state == 'Reworking');
    final stopped = story.issues.any((issue) => issue.readingStopped == true);
    final lines = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final issue in reading) Text('reading ${issue.rounds ?? '?'} of ${issue.roundsMost ?? '?'}'),
        if (stopped) const Text('stopped in Reading - needs you'),
      ],
    );
    final key = Key('planning-reading ${story.id}');
    return stopped
        ? TextButton(key: key, onPressed: widget.onNeedsYou, child: lines)
        : KeyedSubtree(key: key, child: lines);
  }

  Widget _card(BuildContext context, PlanStory story) {
    final theme = Theme.of(context);
    final open = board.preferences.expandedStories.contains(story.id);
    final work = _work(story);
    return _drag(
      story,
      Card(
        key: Key('planning-card ${story.id}'),
        margin: const EdgeInsets.only(bottom: Space.small),
        child: Padding(
          padding: const EdgeInsets.all(Space.normal),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: Space.small,
                children: [
                  Text(story.id, style: theme.textTheme.labelMedium),
                  _priority(context, story.priority),
                ],
              ),
              const SizedBox(height: Space.small),
              Text(story.title),
              if (board.pending[story.id] case final move? when move.problem == null) const Text('moved'),
              if (board.pending[story.id]?.problem case final problem?) Text(problem),
              if (work != null && work.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: Space.small),
                  child: Text(work, style: theme.textTheme.bodySmall),
                ),
              if (story.issues.any(
                (issue) => issue.state == 'Reading' || issue.state == 'Reworking' || issue.readingStopped == true,
              ))
                _reading(story),
              if (!story.issuesReported)
                const Text('Issues not reported')
              else
                TextButton(
                  key: Key('planning-issues ${story.id}'),
                  onPressed: story.issues.isEmpty ? null : () => board.expand(story.id),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  child: Row(
                    children: [
                      Icon(open ? Icons.expand_more : Icons.chevron_right, size: Sizes.mark),
                      Expanded(
                        child: Text(
                          story.issues.isEmpty
                              ? 'no issues yet'
                              : '${story.issues.length} ${story.issues.length == 1 ? 'issue' : 'issues'}',
                        ),
                      ),
                      if (story.issues.isNotEmpty && story.completedIssues != null) ...[
                        SizedBox(
                          width: PlanningStyle.progress,
                          child: LinearProgressIndicator(
                            value: story.completedIssues! / story.issues.length,
                            semanticsLabel: 'Issues in Review or Finished',
                          ),
                        ),
                        const SizedBox(width: Space.tight),
                        Text('${story.completedIssues}/${story.issues.length}'),
                      ],
                    ],
                  ),
                ),
              if (story.issuesReported && story.completedIssues == null) const Text('Issue progress not reported'),
              if (open)
                for (final issue in story.issues)
                  Padding(
                    key: Key('planning-issue ${story.id} ${issue.id}'),
                    padding: const EdgeInsets.only(top: Space.small),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${issue.id} · ${issue.repository}'),
                        if (issue.title.isNotEmpty) Text(issue.title),
                        Wrap(
                          spacing: Space.small,
                          children: [
                            if (issue.state.isNotEmpty) Text(issue.state),
                            if (issue.size.isNotEmpty) Text(issue.size),
                          ],
                        ),
                        if (issue.blockedBy.isNotEmpty) Text('Blocked by ${issue.blockedBy.join(', ')}'),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
