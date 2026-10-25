import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart';

import '../app/host_readiness.dart';
import 'panes.dart';
import 'tokens.dart';

/// Whether this machine can run anything, and what it is short of.
///
/// **What is not fine comes first, and everything else is below it.** Somebody opening this has a
/// question — *can this machine do the thing I am about to ask of it* — and a list of twelve
/// green lines with one red one in the middle answers it slowly.
class HostReadinessView extends StatelessWidget {
  /// Constructor taking what the machine said and how to ask again.
  const HostReadinessView({
    required this.readiness,
    required this.machine,
    required this.onCheckAgain,
    required this.onClose,
    super.key,
  });

  /// What the machine said about itself.
  final HostReadiness readiness;

  /// Which machine was asked, because the answer belongs to one.
  final String machine;

  /// Asks again. **Not polled** — it runs external programs and takes a moment.
  final VoidCallback onCheckAgain;

  /// Closes the view.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ready = readiness.ready;

    return Column(
      children: <Widget>[
        PaneHeader(
          title: 'What $machine can run',
          trailing: Row(
            children: <Widget>[
              TextButton.icon(
                key: const Key('check-again'),
                onPressed: readiness.busy ? null : onCheckAgain,
                icon: const Icon(Icons.refresh, size: Sizes.rowIcon),
                label: const Text('Check again'),
              ),
              IconButton(icon: const Icon(Icons.close), tooltip: 'Close (Esc)', onPressed: onClose),
            ],
          ),
        ),
        if (readiness.problem != null)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              border: Border.all(color: scheme.outlineVariant, width: Sizes.divider),
            ),
            padding: const EdgeInsets.all(Space.normal),
            child: Text(readiness.problem!, key: const Key('readiness-problem')),
          )
        else if (ready != null)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: ready ? scheme.surfaceContainerHighest : scheme.surfaceContainerLow,
              border: Border.all(color: scheme.outlineVariant, width: Sizes.divider),
            ),
            padding: const EdgeInsets.all(Space.normal),
            child: Text(
              readiness.verdict,
              key: const Key('readiness-verdict'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: Space.small),
            children: <Widget>[
              if (readiness.busy && ready == null)
                const Padding(padding: EdgeInsets.all(Space.normal), child: Text('Asking the machine…')),
              if (readiness.worthReading.isNotEmpty) ...<Widget>[
                const _Heading(words: 'What is wrong'),
                for (final probe in readiness.worthReading) _ProbeRow(probe: probe),
              ],
              if (readiness.probes.isNotEmpty) ...<Widget>[
                const _Heading(words: 'Everything that was checked'),
                for (final probe in readiness.probes) _ProbeRow(probe: probe),
              ],
              if (ready != null) ...<Widget>[
                const SizedBox(height: Space.wide),
                // **Said rather than left as a missing button.** Preparing a machine means
                // installing packages and writing under `/etc`, which is root on the node — and a
                // machine that is not ready usually has no daemon to ask in the first place, so a
                // check delivered over this socket could never have reached the case worth fixing.
                Padding(
                  padding: const EdgeInsets.all(Space.normal),
                  child: Text(
                    'Nothing here installs or configures anything. Each line above names the one '
                    'thing to do, and it is done on the machine itself.',
                    key: const Key('nothing-is-fixed-here'),
                    style: Theme.of(context).textTheme.bodySmall,
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

/// One thing that was checked.
class _ProbeRow extends StatelessWidget {
  const _ProbeRow({required this.probe});

  final Probe probe;

  @override
  Widget build(BuildContext context) {
    final (icon, colour) = probeLook(probe.state, Theme.of(context).colorScheme);

    return ListTile(
      dense: true,
      leading: Icon(icon, size: Sizes.mark, color: colour),
      title: Text('${probe.name} · ${probe.label}', key: const Key('probe')),
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
                style: TextStyle(color: colour, fontFamily: 'monospace', fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.words});

  final String words;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Space.normal, Space.wide, Space.normal, Space.small),
    child: Text(words, style: Theme.of(context).textTheme.labelLarge),
  );
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
