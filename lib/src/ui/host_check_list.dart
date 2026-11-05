import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:porelo_host/porelo_host.dart' show HostCheckAnswer, HostCheckFinding, HostCheckState;

import 'tokens.dart';

/// What the check answered: every finding at once, what stands in the way first, or that it did not answer.
class HostCheckList extends StatelessWidget {
  /// Shows [answer] as it is.
  const HostCheckList({required this.answer, super.key});

  /// The check's answer.
  final HostCheckAnswer answer;

  static const _order = [HostCheckState.fail, HostCheckState.warn, HostCheckState.unknown, HostCheckState.pass];

  String get _head {
    if (!answer.answered) return 'The check did not answer. This says nothing of the machine. ${answer.said}';
    if (answer.passed) return 'This machine passes the check. Being checked changed nothing on it.';
    if (!answer.complete) return 'The check did not run to its end, so this list is not whole. It changed nothing.';
    return 'This machine does not pass the check yet. Being checked changed nothing on it.';
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Space.small),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: Space.small,
      children: [
        SelectableText(_head, key: const Key('host-check-head')),
        for (final state in _order)
          for (final finding in answer.findings.where((each) => each.state == state)) _FindingRow(finding),
      ],
    ),
  );
}

class _FindingRow extends StatelessWidget {
  const _FindingRow(this.finding);

  final HostCheckFinding finding;

  String get _word => switch (finding.state) {
    HostCheckState.pass => 'Passed',
    HostCheckState.fail => 'Fails',
    HostCheckState.warn => 'Warning',
    HostCheckState.unknown => 'Cannot be known beforehand',
  };

  /// A JSON value in words: the unit follows a measure, and a list or an object stands as it came.
  static String _value(Object? value, String? unit) {
    final text = switch (value) {
      final String words => words,
      final bool yes => yes ? 'yes' : 'no',
      final num number => '$number',
      _ => jsonEncode(value),
    };
    return unit == null || unit.isEmpty || value is! num ? text : '$text $unit';
  }

  @override
  Widget build(BuildContext context) {
    final fails = finding.state == HostCheckState.fail;
    return Column(
      key: ValueKey('host-check-finding-${finding.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${finding.id}: $_word',
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(color: fails ? Theme.of(context).colorScheme.error : null),
        ),
        if (finding.found != null) SelectableText('Found: ${_value(finding.found, finding.unit)}'),
        if (finding.asked != null) SelectableText('Asked: ${_value(finding.asked, finding.unit)}'),
        if (finding.plainWords case final words?)
          SelectableText(words)
        else if (finding.todo case final todo? when todo.isNotEmpty)
          SelectableText('What to do: $todo'),
      ],
    );
  }
}
