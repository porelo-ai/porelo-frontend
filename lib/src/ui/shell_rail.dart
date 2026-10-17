import 'package:flutter/material.dart';

import '../app/shell_model.dart';
import 'machine_tree.dart';
import 'tokens.dart';

/// The left of the window: the daily work first - what runs, and what needs a person - and setting
/// up apart under it, machines and projects, which are rarely needed once they are set up.
/// The refresh and the stop for every machine stay at its foot.
class ShellRail extends StatelessWidget {
  /// Constructor taking where the window is, the counts it shows, and what choosing does.
  const ShellRail({
    required this.section,
    required this.running,
    this.work,
    required this.needing,
    required this.machines,
    required this.projects,
    this.forges = 0,
    required this.width,
    required this.onGo,
    required this.onRefresh,
    required this.onStopEverywhere,
    super.key,
  });

  /// Where the window is. One machine's page belongs to setting up machines.
  final Section section;

  /// How much work runs on every machine.
  final int running;

  /// How much work there is on every machine, running or not; null counts only what runs.
  final int? work;

  /// How many things need a person.
  final int needing;

  /// How many machines are watched.
  final int machines;

  /// How many projects there are on them.
  final int projects;

  /// How many forges are set up on this computer.
  final int forges;

  /// How wide it is.
  final double width;

  /// Goes to a place.
  final void Function(Section section) onGo;

  /// Asks every machine again.
  final VoidCallback onRefresh;

  /// Stops everything on every machine; null where nothing answers.
  final VoidCallback? onStopEverywhere;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final here = switch (section) {
      Section.machine => Section.machines,
      Section.project => Section.projects,
      Section.forge => Section.forges,
      _ => section,
    };
    Widget entry(Section place, IconData icon, IconData selectedIcon, Widget trailing) {
      final selected = here == place;
      return ListTile(
        key: ValueKey<String>('rail ${place.name}'),
        selected: selected,
        leading: Icon(selected ? selectedIcon : icon),
        title: Text(place.label),
        trailing: trailing,
        onTap: () => onGo(place),
      );
    }

    return SizedBox(
      width: width,
      child: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              key: const Key('shell-rail'),
              children: <Widget>[
                // All the work there is, as Machines and Projects count theirs; what runs is in the tip
                // (walk 10: two stopped tasks read as "0").
                entry(
                  Section.work,
                  Icons.play_circle_outline,
                  Icons.play_circle,
                  Tooltip(
                    message: '$running running',
                    child: Text('${work ?? running}', key: const Key('rail-work-count')),
                  ),
                ),
                entry(
                  Section.attention,
                  Icons.notifications_active_outlined,
                  Icons.notifications_active,
                  Badge(key: const Key('needing-count-badge'), isLabelVisible: needing > 0, label: Text('$needing')),
                ),
                const Divider(height: Sizes.divider),
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.normal, Space.small, Space.normal, Space.tight),
                  child: Text('Set up', style: text.labelMedium),
                ),
                entry(Section.machines, Icons.dns_outlined, Icons.dns, Text('$machines')),
                entry(Section.forges, Icons.hub_outlined, Icons.hub, Text('$forges')),
                entry(Section.projects, Icons.folder_outlined, Icons.folder, Text('$projects')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Space.small),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Tooltip(
                  message: 'Ask every machine again, now',
                  child: TextButton.icon(
                    key: const Key('refresh-all'),
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh, size: Sizes.rowIcon),
                    label: const Text('Refresh'),
                  ),
                ),
                StopEverywhere(onPressed: onStopEverywhere),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
