import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart';

import '../app/host_readiness.dart';
import 'expandable_list_row.dart';
import 'filtered_list_section.dart';
import 'page_explanation.dart' show counted;
import 'tokens.dart';

/// Whether this machine can run anything, and what it is short of.
///
/// **What is not fine comes first, and everything else is below it.** Somebody opening this has a
/// question — *can this machine do the thing I am about to ask of it* — and a list of twelve
/// green lines with one red one in the middle answers it slowly.
class HostReadinessView extends StatelessWidget {
  /// Constructor taking what the machine said, how to ask again, and the page's head.
  const HostReadinessView({
    required this.readiness,
    required this.machine,
    required this.onCheckAgain,
    required this.head,
    super.key,
  });

  /// What the machine said about itself.
  final HostReadiness readiness;

  /// Which machine was asked, because the answer belongs to one.
  final String machine;

  /// Asks again. **Not polled** — it runs external programs and takes a moment.
  final VoidCallback onCheckAgain;

  /// Where the page sits and what its head says beside the checks' own words.
  final LeafHead head;

  @override
  Widget build(BuildContext context) {
    final health = readiness.health;
    final probes = readiness.probes;
    final notFine = probes.where((probe) => !probe.fine).length;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Space.normal),
      child: FilteredListSection(
        key: ValueKey<String>(head.id),
        storageId: head.id,
        title: 'Health',
        leaf: true,
        collapsible: false,
        path: head.path,
        pathKey: head.pathKey,
        search: head.filter,
        searchHint: 'Filter the checks',
        read: health != null,
        busy: readiness.busy,
        problem: readiness.problem,
        staleRows: head.stale,
        subtitle: health == null
            ? null
            : '${counted(probes.length, 'check', 'checks')} · ${notFine == 0 ? 'all fine' : '$notFine not fine'}',
        actions: <Widget>[
          FilledButton(
            key: const Key('check-again'),
            onPressed: readiness.busy ? null : onCheckAgain,
            child: const Text('Check whether this machine can run anything'),
          ),
        ],
        beforeRows: <Widget>[
          ...head.notices,
          if (readiness.ready != null && readiness.problem == null)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.small),
              child: Text(
                readiness.verdict,
                key: const Key('readiness-verdict'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
        ],
        emptyWords: 'The machine reported no check.',
        // What is not fine comes first.
        rows: <FilteredRow>[
          for (final probe in <Probe>[...probes.where((each) => !each.fine), ...probes.where((each) => each.fine)])
            (words: '${probe.name} ${probe.label} ${probe.detail}', child: _ProbeRow(probe: probe)),
        ],
        afterRows: <Widget>[
          if (readiness.ready != null)
            // **Said rather than left as a missing button.** Preparing a machine means
            // installing packages and writing under `/etc`, which is root on the node — and a
            // machine that is not ready usually has no daemon to ask in the first place, so a
            // check delivered over this socket could never have reached the case worth fixing.
            Padding(
              padding: const EdgeInsets.only(top: Space.wide),
              child: Text(
                'Nothing here installs or configures anything. Each line above names the one '
                'thing to do, and it is done on the machine itself.',
                key: const Key('nothing-is-fixed-here'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

/// One thing that was checked, its state as a chip.
class _ProbeRow extends StatelessWidget {
  const _ProbeRow({required this.probe});

  final Probe probe;

  @override
  Widget build(BuildContext context) {
    final (icon, colour) = probeLook(probe.state, Theme.of(context).colorScheme);
    return LeafListRow(
      key: ValueKey<String>('probe ${probe.name}'),
      leading: Icon(icon, size: Sizes.mark, color: colour),
      title: probe.name,
      titleKey: const Key('probe'),
      state: probe.label,
      toneWords: switch (probe.state) {
        'OK' => 'ok',
        'MISSING' => 'missing',
        _ => 'degraded',
      },
      subtitleMaxLines: null,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (probe.detail.isNotEmpty) Text(probe.detail),
          // Never empty on anything but OK, and the Porelo side refuses to construct one without
          // it — so this renders without checking whether there is something to render.
          if (probe.action.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Space.tight),
              child: Text(
                probe.action,
                key: const Key('what-to-do'),
                style: TextStyle(color: colour, fontFamily: 'monospace'),
              ),
            ),
        ],
      ),
    );
  }
}

/// How a probe's state is drawn, as `porelo doctor` colours it on a terminal: `OK` green, `DEGRADED`
/// and `UNKNOWN` yellow, `MISSING` red. Each with a shape of its own, so it reads without colour too,
/// and an unknown state never draws as the good case.
(IconData, Color) probeLook(String state, ColorScheme scheme) => switch (state) {
  'OK' => (Icons.check_circle_outline, StateColours.of(scheme).working),
  'MISSING' => (Icons.error_outline, scheme.error),
  'DEGRADED' => (Icons.warning_amber_outlined, StateColours.of(scheme).waiting),
  _ => (Icons.help_outline, StateColours.of(scheme).waiting),
};
