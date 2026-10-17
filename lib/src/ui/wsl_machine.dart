import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/machines.dart';
import '../app/wsl.dart';
import '../app/wsl_setup.dart';
import 'choice_field.dart';
import 'tokens.dart';
import 'terminal_look.dart';

/// The WSL way to a machine, on Windows: the distributions of this Windows user, the checks before
/// one is connected to, and the offer to set Porelo up in one that lacks it.
///
/// **Nothing runs as root but lines a person read and said yes to**, and a distribution is started
/// only by the restart for systemd, after a question of its own whose answer is no until changed.
class WslSteps extends StatefulWidget {
  const WslSteps({required this.onReady, this.wsl, this.setupFor, this.record, super.key});

  /// Told the machine to watch once every check passed, or null while not.
  final ValueChanged<Machine?> onReady;

  /// How the distributions are read; null for `wsl.exe` itself.
  final Wsl? wsl;

  /// Makes the checks for a distribution; null for the real ones.
  final WslSetup Function(String distribution)? setupFor;

  /// Records a line that ran in a distribution, and what it answered.
  final void Function(String distribution, String line, String said)? record;

  @override
  State<WslSteps> createState() => _WslStepsState();
}

class _WslStepsState extends State<WslSteps> {
  late final Wsl _wsl = widget.wsl ?? Wsl();
  List<WslDistribution>? _distributions;
  String? _chosen;
  WslSetup? _setup;
  String _user = '';
  bool _showLines = false;
  bool _restart = false;

  @override
  void initState() {
    super.initState();
    unawaited(_read());
  }

  @override
  void dispose() {
    _setup?.removeListener(_changed);
    super.dispose();
  }

  Future<void> _read() async {
    final found = await _wsl.distributions();
    if (mounted) setState(() => _distributions = found);
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    final setup = _setup;
    widget.onReady(setup != null && setup.ready ? setup.machine : null);
  }

  void _choose(String? name) {
    _setup?.removeListener(_changed);
    setState(() {
      _chosen = name;
      _showLines = false;
      _restart = false;
      _setup =
          name == null
                ? null
                : (widget.setupFor?.call(name) ??
                      WslSetup(
                        distribution: name,
                        operatingSystemVersion: Platform.operatingSystemVersion,
                        wsl: _wsl,
                        answers: _answers,
                        record: (line, said) => widget.record?.call(name, line, said),
                      ))
            ?..addListener(_changed);
    });
    widget.onReady(null);
  }

  static Future<bool> _answers(Machine machine) async {
    try {
      final connection = await Machines.backendFor(machine).open();
      await connection.call('org.varlink.service.GetInfo').timeout(const Duration(seconds: 10));
      connection.close();
      return true;
    } on Object {
      return false;
    }
  }

  Future<void> _check() async {
    final setup = _setup;
    if (setup == null) return;
    await setup.check();
    if (setup.offersTheSetup) {
      final user = await setup.user();
      if (mounted) setState(() => _user = user);
    }
  }

  @override
  Widget build(BuildContext context) {
    final found = _distributions;
    if (found == null) return const Text('Asking WSL which distributions there are…', key: Key('wsl-reading'));
    if (found.isEmpty) {
      return const SelectableText(
        'WSL answers with no distribution. Install WSL and a distribution Porelo supports from a terminal, '
        'for example: wsl --install -d Ubuntu-26.04 — then open this again.',
        key: Key('wsl-none'),
      );
    }
    final setup = _setup;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ChoiceField<String>(
          id: 'wsl-distribution',
          label: 'The WSL distribution',
          value: _chosen,
          onChanged: _choose,
          choices: <Choice<String>>[
            for (final each in found)
              Choice(
                each.name,
                '${each.name} — ${each.running ? 'running' : 'stopped'}, WSL${each.version == 0 ? '?' : each.version}',
                id: 'wsl-${each.name}',
                means: each.running
                    ? 'Reached through wsl.exe, with no ssh and no open port.'
                    : 'Stopped. The interface does not start it: start it yourself, then check it.',
              ),
          ],
        ),
        if (setup != null) ...<Widget>[
          const SizedBox(height: Space.normal),
          OutlinedButton.icon(
            key: const Key('wsl-check'),
            onPressed: setup.busy ? null : _check,
            icon: const Icon(Icons.fact_check_outlined, size: Sizes.rowIcon),
            label: Text(setup.findings.isEmpty ? 'Check it' : 'Check it again'),
          ),
          const SizedBox(height: Space.small),
          for (final finding in setup.findings) _finding(context, finding),
          if (setup.asksForSystemd) ..._systemd(context, setup),
          if (setup.offersTheSetup) ..._offer(context, setup),
        ],
      ],
    );
  }

  Widget _finding(BuildContext context, WslFinding finding) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.tight),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            finding.passed ? Icons.check_circle_outline : Icons.error_outline,
            size: Sizes.rowIcon,
            color: finding.passed ? scheme.primary : scheme.error,
          ),
          const SizedBox(width: Space.small),
          Expanded(
            child: SelectableText(
              finding.words.isEmpty ? finding.check.title : '${finding.check.title}: ${finding.words}',
              key: Key('wsl-finding-${finding.check.name}'),
            ),
          ),
        ],
      ),
    );
  }

  /// The question of its own: systemd on, and the distribution restarted, ending what runs in it.
  List<Widget> _systemd(BuildContext context, WslSetup setup) => <Widget>[
    const SizedBox(height: Space.normal),
    Text(
      'Turning systemd on means restarting ${setup.distribution}. Everything running in it ends: '
      'its shells, its services, and any Porelo task running there.',
      key: const Key('wsl-systemd-cost'),
    ),
    const SizedBox(height: Space.tight),
    SelectableText(WslSetup.turnSystemdOn.shown, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
    SelectableText(
      'wsl.exe --terminate ${setup.distribution}',
      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
    ),
    SwitchListTile(
      key: const Key('wsl-restart-yes'),
      contentPadding: EdgeInsets.zero,
      title: Text('Restart ${setup.distribution} to turn systemd on'),
      value: _restart,
      onChanged: setup.busy ? null : (yes) => setState(() => _restart = yes),
    ),
    FilledButton(
      key: const Key('wsl-restart'),
      onPressed: _restart && !setup.busy
          ? () async {
              await setup.turnOnSystemdAndRestart(wslExe: (arguments) async => (await Wsl.runWslExe(arguments)).code);
              if (setup.stopped == null) await _check();
            }
          : null,
      child: const Text('Turn systemd on and restart it'),
    ),
    if (setup.stopped case final why?) SelectableText(why, key: const Key('wsl-stopped')),
  ];

  /// The offer to set Porelo up: the agents to choose, then every line shown, run only after a yes.
  List<Widget> _offer(BuildContext context, WslSetup setup) {
    final lines = setup.setupLines(_user.isEmpty ? '<user>' : _user);
    return <Widget>[
      const SizedBox(height: Space.normal),
      Text('Set Porelo up in ${setup.distribution}?', style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: Space.tight),
      const Text('Which agents? None is chosen for you.'),
      for (final agent in poreloAgents)
        CheckboxListTile(
          key: Key('wsl-agent-${agent.package}'),
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(agent.name),
          value: setup.agents.contains(agent.package),
          onChanged: setup.busy
              ? null
              : (yes) =>
                    setState(() => yes == true ? setup.agents.add(agent.package) : setup.agents.remove(agent.package)),
        ),
      const SizedBox(height: Space.tight),
      Text(
        'These lines run in ${setup.distribution}, those with sudo as root through wsl.exe -u root, '
        "which asks no password of the distribution's owner. The key is checked against "
        '$poreloKeyFingerprint before anything is written.',
      ),
      const SizedBox(height: Space.tight),
      Container(
        key: const Key('wsl-lines'),
        width: double.infinity,
        padding: const EdgeInsets.all(Space.small),
        color: TerminalLook.background,
        child: SelectableText(
          lines.map((each) => each.shown).join('\n'),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: TerminalLook.foreground),
        ),
      ),
      const SizedBox(height: Space.small),
      Wrap(
        spacing: Space.small,
        children: <Widget>[
          FilledButton(
            key: const Key('wsl-run-setup'),
            onPressed: setup.busy || _user.isEmpty
                ? null
                : () async {
                    await setup.runSetup(lines);
                    if (setup.stopped == null) await _check();
                  },
            child: const Text('Yes, run these lines'),
          ),
          TextButton(
            key: const Key('wsl-copy-lines'),
            onPressed: () {
              unawaited(Clipboard.setData(ClipboardData(text: lines.map((each) => each.shown).join('\n'))));
              setState(() => _showLines = true);
            },
            child: const Text('No, I run them myself'),
          ),
        ],
      ),
      if (_showLines) const Text('Copied. Run them in the distribution, then check it again.'),
      if (setup.said.isNotEmpty) ...<Widget>[
        const SizedBox(height: Space.small),
        SelectableText(
          setup.said.join('\n'),
          key: const Key('wsl-said'),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      ],
      if (setup.stopped case final why?) SelectableText(why, key: const Key('wsl-stopped')),
    ];
  }
}
