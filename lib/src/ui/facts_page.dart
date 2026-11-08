import 'package:flutter/material.dart';

import '../app/commands.dart';
import '../app/settings.dart';
import 'page_explanation.dart';
import 'machine_view.dart';
import 'command_menu.dart';
import 'tokens.dart';
import 'window_size.dart';

/// A named observation; unknown values include their reason rather than implying an empty result.
typedef PageFact = ({String label, String value, bool known});

/// The shared page for a place whose children already appear in the navigation tree.
class FactsPage extends StatelessWidget {
  /// Presents observations and commands without repeating the child list.
  const FactsPage({
    required this.title,
    required this.facts,
    required this.commands,
    this.path = const [],
    this.waiting = const [],
    this.warnings = const [],
    this.menuCommands = const [],
    this.busy = false,
    this.primary,
    this.highlight,
    this.tools,
    this.identity,
    this.settings,
    this.explanationId,
    this.explanation = const [],
    super.key,
  });

  /// The place's full title, wrapping on a desktop or tablet.
  final String title;

  /// The ancestors linking back to their facts pages.
  final List<({String label, VoidCallback go})> path;

  /// Last observed facts, with explicit unknown values.
  final List<PageFact> facts;

  /// Existing commands and their unavailability reasons.
  final List<Command> commands;

  /// Less frequent commands retained in the machine's existing menu.
  final List<Command> menuCommands;

  /// Actions whose commands have not been served yet.
  final List<String> waiting;

  /// Refusals and cached-state warnings stay visible above the observations.
  final List<String> warnings;

  /// Whether fresh observations are being read.
  final bool busy;

  /// The action called for by the state.
  final String? primary;

  /// The action revealed by the command finder.
  final String? highlight;

  /// Existing machine controls retained beside its facts.
  final Widget? tools;

  /// The machine's connection identity, retained independently of its vault read.
  final Widget? identity;

  /// Where this page's explanation is kept across a restart.
  final Settings? settings;

  /// The shared explanation identity of this place.
  final String? explanationId;

  /// What this place is for, shown once and available through its information button.
  final List<({String title, String words})> explanation;

  bool _danger(Command command) =>
      command.danger ||
      command.id.contains('panic') ||
      command.id.contains('takeDown') ||
      command.id.contains('clear') ||
      command.id.contains('remove');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final phone = WindowSize.fromContext(context) == WindowSize.compact;
    final actions = [
      ...commands.where((command) => command.visible && !_danger(command)),
      ...commands.where((command) => command.visible && _danger(command)),
    ];
    Widget action(Command command) {
      final danger = _danger(command);
      final press = command.available ? command.run : null;
      return Highlight(
        active: highlight == command.id,
        child: Tooltip(
          message: command.unavailable ?? command.label,
          child: command.id == primary && !danger
              ? FilledButton(key: Key(command.id), onPressed: press, child: Text(command.label))
              : OutlinedButton(
                  key: Key(command.id),
                  onPressed: press,
                  style: danger
                      ? OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                          side: BorderSide(color: theme.colorScheme.error),
                        )
                      : null,
                  child: Text(command.label),
                ),
        ),
      );
    }

    final buttons = <Widget>[
      for (final command in actions) action(command),
      for (final label in waiting)
        CustomPaint(
          painter: _DashedOutline(theme.colorScheme.outline),
          child: OutlinedButton(
            key: Key('waiting $label'),
            onPressed: null,
            style: OutlinedButton.styleFrom(side: BorderSide.none),
            child: Text('$label — waits for a command'),
          ),
        ),
    ];
    return ListView(
      key: const Key('facts-page'),
      padding: const EdgeInsets.all(Space.normal),
      children: [
        if (path.isNotEmpty)
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final step in path) ...[TextButton(onPressed: step.go, child: Text(step.label)), const Text(' › ')],
              Text(title),
            ],
          ),
        if (!phone || settings != null && explanationId != null)
          Row(
            children: [
              if (!phone) Expanded(child: Text(title, style: theme.textTheme.headlineSmall)),
              if (settings != null && explanationId != null)
                PageExplanationButton(id: explanationId!, settings: settings!),
            ],
          ),
        if (settings != null && explanationId != null && explanation.isNotEmpty)
          PageExplanation(
            key: ValueKey('explanation $explanationId'),
            id: explanationId!,
            settings: settings!,
            parts: explanation,
          ),
        ?identity,
        if (menuCommands.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: CommandMenu(
              key: const Key('machine-menu'),
              commands: menuCommands,
              tooltip: 'What $title can be told to do',
              highlight: highlight,
            ),
          ),
        ?tools,
        if (busy) const LinearProgressIndicator(minHeight: Sizes.progressBar),
        const SizedBox(height: Space.normal),
        for (final warning in warnings)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.small),
            child: Text(warning, style: TextStyle(color: theme.colorScheme.error)),
          ),
        if (facts.isEmpty) const Text('None yet'),
        for (final fact in facts)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.small),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!fact.known)
                  Padding(
                    padding: const EdgeInsets.only(right: Space.small),
                    child: Icon(
                      Icons.pending_outlined,
                      size: Sizes.mark,
                      color: StateColours.of(theme.colorScheme).waiting,
                    ),
                  ),
                Expanded(
                  child: Text(
                    '${fact.label}: ${fact.value}',
                    style: fact.known ? null : TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: Space.normal),
        if (phone)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final button in buttons)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.small),
                  child: button,
                ),
            ],
          )
        else
          Wrap(spacing: Space.small, runSpacing: Space.small, children: buttons),
        for (final command in actions)
          if (command.unavailable case final reason?)
            Padding(
              padding: const EdgeInsets.only(top: Space.small),
              child: Text('${command.label}: $reason', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            ),
      ],
    );
  }
}

class _DashedOutline extends CustomPainter {
  _DashedOutline(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = Sizes.divider;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(Radii.small)));
    for (final metric in path.computeMetrics()) {
      for (double start = 0; start < metric.length; start += Space.small) {
        canvas.drawPath(metric.extractPath(start, start + Space.tight), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedOutline oldDelegate) => color != oldDelegate.color;
}
