// Build for a walk with: dart compile exe tool/host_standin.dart -o <walk>/porelo-host
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:porelo_host/porelo_host.dart';

Future<void> main(List<String> arguments) async {
  try {
    exitCode = await _run(arguments);
  } on FileSystemException {
    exitCode = _wrong('Cannot read or update host-standin.json in PORELO_WALK.');
  } on FormatException {
    exitCode = _wrong('host-standin.json must contain a valid situation and state.');
  }
}

int _wrong(String words) {
  stderr.writeln(words);
  return Exit.usage;
}

Future<int> _run(List<String> arguments) async {
  final folder = Platform.environment['PORELO_WALK'];
  if (folder == null || folder.isEmpty) return _wrong('Set PORELO_WALK to the walk folder.');
  final file = File('$folder/host-standin.json');
  final decoded = jsonDecode(await file.readAsString());
  if (decoded is! Map<String, dynamic>) throw const FormatException();
  final situation = decoded['situation'];
  final state = decoded['state'] ?? 'new';
  final pace = decoded['paceMilliseconds'] ?? 60000;
  if (!const {'clean', 'stop', 'refused', 'slow', 'down'}.contains(situation) ||
      !const {'new', 'waiting', 'done', 'down'}.contains(state) ||
      pace is! int ||
      pace < 0) {
    throw const FormatException();
  }
  if (arguments.isEmpty || !const {'up', 'down'}.contains(arguments.first)) {
    return _wrong('The host stand-in accepts up or down with host options.');
  }
  final verb = arguments.first;
  final options = <String, String>{};
  const valued = {
    '--project',
    '--account',
    '--public-key',
    '--identity',
    '--collection',
    '--collection-sha256',
    '--scaleway-project',
    '--tresor',
    '--vpn-peer-public-key',
    '--vpn-peer-address',
    '--zone',
    '--given',
    '--host-key',
    '--login-user',
    '--distribution',
  };
  for (var i = 1; i < arguments.length; i++) {
    final option = arguments[i];
    if (option == '--give-back-anyway' && verb == 'down') {
      continue;
    } else if (valued.contains(option) && i + 1 < arguments.length && !arguments[i + 1].startsWith('--')) {
      options[option] = arguments[++i];
    } else {
      return _wrong('Unsupported or incomplete host stand-in option.');
    }
  }
  if (const ['--project', '--account', '--public-key', '--identity'].any((key) => options[key]?.isNotEmpty != true) ||
      options.containsKey('--given') == options.containsKey('--scaleway-project') ||
      (options.containsKey('--given') && !options.containsKey('--host-key'))) {
    return _wrong('Give the project, account, key paths and one host provider.');
  }
  if (options.containsKey('--collection') != options.containsKey('--collection-sha256')) {
    return _wrong('--collection needs --collection-sha256 and vice versa.');
  }
  if (options['--collection'] case final String collection when verb == 'up') {
    final expected = options['--collection-sha256']!.toLowerCase();
    final actual = (await sha256.bind(File(collection).openRead()).single).toString();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(expected) || actual != expected) {
      return _wrong('Test collection SHA-256: expected $expected; got $actual.');
    }
  }

  Future<void> remember(String next) => file.writeAsString(
    jsonEncode({
      'situation': situation,
      'state': next,
      if (decoded.containsKey('paceMilliseconds')) 'paceMilliseconds': pace,
    }),
  );

  if (verb == 'down') {
    _emit(const Step('plan', StepState.plan, steps: HostRun.downSteps));
    _emit(const Step('give-back', StepState.started));
    _emit(const Step('give-back', StepState.done, address: '192.0.2.10'));
    await remember('down');
    return Exit.done;
  }
  if (situation == 'down') return _wrong('The down situation needs the down command.');
  _emit(const Step('plan', StepState.plan, steps: _ownSteps));
  if (situation == 'refused') {
    _emit(const Step('rent', StepState.started));
    _emit(const Step('rent', StepState.refused, fix: 'Choose a host the provider can supply.'));
    return Exit.refused;
  }
  if (situation == 'slow') {
    _emit(
      Step(
        'plan',
        StepState.plan,
        steps: [
          ..._ownSteps,
          PlannedStep('play', 'Prepare the server', seconds: (pace / 1000).ceil()),
        ],
      ),
    );
    _emit(Step('play', StepState.started, text: 'Prepare the server', seconds: (pace / 1000).ceil()));
    await Future<void>.delayed(Duration(milliseconds: pace));
    _emit(const Step('play', StepState.done));
  } else {
    for (final name in ['rent', 'ssh', 'copy', 'ansible']) {
      _emit(Step(name, StepState.started));
      _emit(Step(name, StepState.done));
    }
    _emit(const Step('plan', StepState.plan, steps: [..._ownSteps, ..._collectionSteps]));
    _emit(const Step('play', StepState.started));
    _emit(const Step('play', StepState.done));
    if (situation == 'stop' && state == 'new') {
      _emit(
        Step(
          'person',
          StepState.waiting,
          text: 'Sign in to the drive and initialize the vault',
          needs: const ['drive', 'vault-new'],
          address: '192.0.2.10',
          account: options['--account'],
        ),
      );
      await remember('waiting');
      return Exit.waiting;
    }
    for (final name in ['drive', 'vault']) {
      _emit(Step(name, StepState.started));
      _emit(Step(name, StepState.done));
    }
  }
  _emit(
    Step(
      'up',
      StepState.done,
      address: '192.0.2.10',
      account: options['--account'],
      socket: '/run/user/1000/porelo/porelod.sock',
    ),
  );
  await remember('done');
  return Exit.done;
}

const _ownSteps = HostRun.upSteps;
const _collectionSteps = [
  PlannedStep('play', 'Prepare the server', seconds: 120),
  PlannedStep('drive', 'Sync the project drive', seconds: 60, when: true),
  PlannedStep('vault', 'Prepare the project vault', seconds: 30),
];

void _emit(Step step) {
  final planned = [
    ..._ownSteps,
    ..._collectionSteps,
    ...HostRun.downSteps,
  ].where((each) => each.task == step.step).firstOrNull;
  final line = jsonDecode(step.toLine()) as Map<String, dynamic>;
  if (planned != null) {
    line['text'] = step.text ?? planned.text;
    line['seconds'] = step.seconds ?? planned.seconds;
  }
  stdout.writeln(jsonEncode(line));
  if (step.state != StepState.plan) {
    stderr.writeln(step.fix ?? step.words ?? step.text ?? planned?.text ?? '${step.step}: ${step.state.name}');
  }
}
