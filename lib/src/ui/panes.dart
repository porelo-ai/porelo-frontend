import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart';

import '../app/builds.dart';
import '../app/hand_in.dart';
import '../app/work_held.dart';
import 'how_long.dart';
import 'tokens.dart';

/// The heading over a pane, so a pane is identifiable when it is the only one on screen.
class PaneHeader extends StatelessWidget {
  /// Constructor taking what the pane is called and anything to show beside it.
  const PaneHeader({required this.title, this.trailing, this.leading, super.key});

  /// What the pane is.
  final String title;

  /// Shown at the end of the header, usually a count.
  final Widget? trailing;

  /// Shown before the title, usually a way back on a narrow window.
  final Widget? leading;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(leading == null ? Space.normal : Space.tight, Space.small, Space.normal, Space.small),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
    ),
    child: Row(
      children: <Widget>[
        ?leading,
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall)),
        ?trailing,
      ],
    ),
  );
}

/// One piece of work, opened over the frame.
class WorkDetail extends StatelessWidget {
  /// Constructor taking the work and how to close it.
  const WorkDetail({
    required this.task,
    required this.held,
    required this.onClose,
    this.repository,
    this.handing,
    this.handIns,
    super.key,
  });

  /// A file being handed to work, or the last one, where this frame hands files in.
  final HandingIn? handing;

  /// What work of this name has been handed, asked when this opened.
  final HandInRecord? handIns;

  /// What is open.
  final Task task;

  /// The repository it works in, or null where its machine names none.
  final String? repository;

  /// What it holds that never reached the gate, asked when this opened.
  final WorkHeld held;

  /// Closes it, leaving the selection where it was.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge(<Listenable?>[held, handing, handIns]),
    builder: (context, _) => _detail(context),
  );

  Widget _detail(BuildContext context) {
    // A container that is up with no helpers has lost its gate or its clearance watcher, and is
    // not the same thing as a healthy task. It is the one reading worth calling out here.
    final ungated = task.running && task.helpers == 0;

    return Column(
      children: <Widget>[
        PaneHeader(
          title: task.label.isEmpty ? task.name : task.label,
          trailing: IconButton(icon: const Icon(Icons.close), tooltip: 'Close (Esc)', onPressed: onClose),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(Space.wide),
            children: <Widget>[
              // Only when a caption is standing in front of it: the heading is the name when
              // there is no caption, and repeating it would be noise. When there is one, the
              // identity has to be somewhere — it is what every other call takes.
              if (task.label.isNotEmpty) _Field(name: 'Its name', value: task.name),
              _Field(name: 'Project', value: task.project.isEmpty ? '—' : task.project),
              if (repository != null) _Field(name: 'Repository', value: repository!),
              _Field(name: 'Security class', value: task.securityClass.isEmpty ? '—' : task.securityClass),
              _Field(name: 'Agent', value: task.agent.isEmpty ? '—' : task.agent),
              // Where its model traffic went, from the task's own record: what a person asks
              // afterwards, and the machine answers once rather than this end guessing.
              _Field(name: 'Provider', value: task.provider.isEmpty ? '—' : task.provider),
              _Field(name: 'Mode', value: task.mode.label),
              _Field(name: 'Branch', value: task.branch.isEmpty ? '—' : task.branch),
              // **Answered by the task, never joined.** `Task.name` is a container name and a
              // pending push carries a task name, and several containers over time share one
              // ref — so a client lining the two up would be right for at most one of them.
              //
              // An `online` task answers `0` and that is not a smaller number: nothing is ever
              // reviewed there, so it is a question the class does not have, and saying *nothing
              // is waiting* would imply somebody could be.
              _Field(name: 'At the gate', value: task.atTheGate),
              // **The other half of the same question, and it costs a call.** What is waiting at
              // the gate comes free with the task; what never reached it runs git inside the
              // container, so it is asked when this opens and never while drawing a list.
              //
              // Three answers rather than two: *holds nothing* and *nobody could look* are
              // different, and only one of them makes it safe to remove a task without asking.
              if (held.words(task.name).isNotEmpty) _Field(name: 'Never pushed', value: held.words(task.name)),
              _Field(name: 'Doing', value: task.activity.label),
              // Absent from a machine without hand-in, rather than *nothing*: it cannot say.
              if (task.files != null || _sending(task) != null)
                _Field(
                  key: const Key('handed-in'),
                  name: 'Handed in',
                  value: <String>[
                    ?_sending(task),
                    if (task.files case final files?)
                      if (files.isEmpty)
                        'nothing, under /porelo/files'
                      else
                        for (final file in files) '${file.name}, ${HandingIn.inWords(file.bytes)}, by ${file.from}',
                  ].join('\n'),
                ),
              if (BuildsSaid.inTheDetail(task) case final lines when lines.isNotEmpty)
                _Field(key: const Key('builds'), name: 'Builds', value: lines.join('\n')),
              if (handIns?.lines(task.name) case final lines? when lines.isNotEmpty)
                _Field(key: const Key('hand-in-record'), name: 'Hand-in record', value: lines.join('\n')),
              if (task.takenDownByARestart) _Field(name: 'Why it is down', value: task.startDetail),
              // By name and destination, as the machine keeps them: never a token.
              if (task.credentials.isNotEmpty)
                _Field(
                  name: 'Credentials',
                  value: <String>[
                    for (final given in task.credentials.entries)
                      '${given.key} for ${given.value}, as PORELO_TOKEN_${Credential.variableOf(given.key)}'
                          '${_grantedBy(task.grants[given.key])}',
                  ].join('\n'),
                ),
              _Field(
                name: 'Egress',
                value: switch (task.clearance) {
                  'off' => 'nothing is enforcing it',
                  'prompt' => 'asks before letting anything new through',
                  'allow' => 'lets anything new through',
                  'deny' => 'refuses anything new without asking',
                  _ => 'not recorded',
                },
              ),
              if (task.activity == Activity.waiting && task.waitingFor.isNotEmpty)
                _Field(name: 'Waiting on', value: task.waitingFor),
              _Field(name: 'For', value: howLong(task) ?? 'not recorded'),
              _Field(name: 'Runtime says', value: task.state),
              _Field(name: 'Helpers alive', value: '${task.helpers}'),
              if (task.prompt.isNotEmpty) _Field(name: 'Asked to', value: task.prompt),
              // **Where somebody asks what this agent was told, and the honest answer is "not
              // here".** Standing instructions live in the repository, checked in or not, and
              // Porelo does not know what they are called — `CLAUDE.md`, `AGENTS.md`, whatever an
              // agent invents next year — nor how a given agent combines several of them.
              //
              // A screen that guessed a set of filenames would answer *"no instructions"* with
              // confidence for a task that had them, which is worse than saying nothing.
              const _Field(name: 'Standing instructions', value: 'in the repository — nothing here has a view of them'),
              if (ungated) ...<Widget>[
                const SizedBox(height: Space.wide),
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: const Padding(
                    padding: EdgeInsets.all(Space.normal),
                    child: Text(
                      'This container is up with no helpers alive: its gate or its clearance '
                      'watcher is gone.',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

extension on WorkDetail {
  /// The file on its way to [task], as a line, or null when none is.
  String? _sending(Task task) {
    final going = handing;
    if (going == null || !going.busy || going.task != task.name) return null;
    return 'sending ${going.name}: ${HandingIn.inWords(going.received)} of '
        '${HandingIn.inWords(going.bytes)}';
  }
}

/// Who the task acts as for one credential, where a person granted it: as it stood at its start.
String _grantedBy(Authorization? grant) => grant == null
    ? ''
    : ', granted by ${grant.grantedBy.isEmpty ? 'an account not recorded' : grant.grantedBy}'
          '${grant.grantedAt.isEmpty ? '' : ' at ${grant.grantedAt}'}';

class _Field extends StatelessWidget {
  const _Field({required this.name, required this.value, super.key});

  final String name;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Space.tight),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: Sizes.fieldName,
          child: Text(name, style: Theme.of(context).textTheme.labelLarge),
        ),
        Expanded(child: SelectableText(value)),
      ],
    ),
  );
}

/// What the work is doing, in the space of a dot.
///
/// **`UNKNOWN` gets its own mark and is never drawn as idle.** It is the normal answer for a task
/// somebody attached a terminal to, and a state that is silently wrong is worse than one that
/// says it cannot see.
class ActivityMark extends StatelessWidget {
  /// Constructor taking what the work is doing and whether the container is up.
  const ActivityMark({required this.activity, required this.running, super.key});

  /// What the work is doing.
  final Activity activity;

  /// Whether the runtime says the container is up.
  final bool running;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (IconData icon, Color color) = switch (activity) {
      Activity.waiting => (Icons.pan_tool_outlined, scheme.error),
      Activity.working => (Icons.play_circle_outline, scheme.primary),
      Activity.idle => (Icons.pause_circle_outline, scheme.outline),
      Activity.dead => (Icons.stop_circle_outlined, scheme.outlineVariant),
      Activity.unknown => (Icons.help_outline, scheme.outline),
      // A value from a later release, or a task older than these fields. Fall back to the one
      // thing that has always been there rather than picking a meaning.
      _ => (running ? Icons.play_circle_outline : Icons.stop_circle_outlined, scheme.outlineVariant),
    };
    return Tooltip(
      message: activity.label,
      child: Icon(icon, size: Sizes.mark, color: color),
    );
  }
}

/// Asks what a piece of work should read as.
///
/// **A caption, never a rename.** The container name is the identity — what every other call
/// takes, and what the gate ref, the workspace and the log files are built from — so it is shown
/// here rather than edited, and emptying the box takes the caption away rather than storing
/// nothing under a name.
Future<String?> askWhatItReadsAs(BuildContext context, {required Task task}) => showDialog<String>(
  context: context,
  builder: (context) => _WhatItReadsAs(task: task),
);

class _WhatItReadsAs extends StatefulWidget {
  const _WhatItReadsAs({required this.task});

  final Task task;

  @override
  State<_WhatItReadsAs> createState() => _WhatItReadsAsState();
}

class _WhatItReadsAsState extends State<_WhatItReadsAs> {
  late final TextEditingController _caption = TextEditingController(text: widget.task.label);

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('What should this read as?'),
    content: SizedBox(
      width: Sizes.dialogSmall,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Its name stays ${widget.task.name}. That is what every other action takes, and '
            'what you would type on the machine — a caption sits in front of it in lists, '
            'never in place of it.',
            key: const Key('name-does-not-move'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: Space.normal),
          TextField(
            key: const Key('what-it-reads-as'),
            controller: _caption,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Reads as',
              hintText: 'schema migration, second attempt',
              helperText: 'Leave it empty to take the caption away.',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (typed) => Navigator.of(context).pop(typed.trim()),
          ),
        ],
      ),
    ),
    actions: <Widget>[
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Leave it')),
      FilledButton(
        key: const Key('name-it'),
        onPressed: () => Navigator.of(context).pop(_caption.text.trim()),
        child: const Text('Use it'),
      ),
    ],
  );
}
