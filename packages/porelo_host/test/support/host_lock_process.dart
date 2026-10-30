import 'dart:async';
import 'dart:io';

import 'package:porelo_host/porelo_host.dart';

Future<void> main(List<String> arguments) async {
  final [directory, name, command, project, hold] = arguments;
  final run = HostRun(
    provider: _Provider(directory, name, hold == 'hold'),
    remote: _Remote(directory, name),
    emit: (step) => writeHostStep(step, output: stdout, errors: stderr),
    hostKeys: () async => ('fixture-private', 'ssh-ed25519 AAAA'),
  );
  final plan = HostPlan(project: project, account: 'worker', publicKey: '', recoveryOnly: true);
  exitCode = command == 'up' ? await run.up(plan) : await run.down(plan, giveBackAnyway: true);
}

class _Provider implements HostProvider {
  _Provider(this.directory, this.name, this.hold);
  final String directory;
  final String name;
  final bool hold;

  @override
  Future<RentedHost?> find(String tag) async {
    await File('$directory/$name-find').writeAsString(tag);
    if (hold) {
      await (() async {
        while (!await File('$directory/release').exists()) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      })().timeout(const Duration(minutes: 2));
    }
    return null;
  }

  @override
  Future<RentedHost> create(HostRequest request) async {
    await File('$directory/creates').writeAsString('$name\n', mode: FileMode.append);
    return const RentedHost(id: 'fixture', address: '192.0.2.1', hostKey: 'ssh-ed25519 AAAA', ready: true);
  }

  @override
  Future<RentedHost> state(String id) => throw StateError('The fixture host is already ready');

  @override
  Future<void> release(String id) => throw StateError('The fixture has no host to release');
}

class _Remote implements Remote {
  _Remote(this.directory, this.name);
  final String directory;
  final String name;

  @override
  Future<RemoteResult> run(
    String host,
    String user,
    String command, {
    String? input,
    void Function(String line)? onLine,
  }) async {
    await File('$directory/$name-ssh').writeAsString(command, mode: FileMode.append);
    if (command == 'id -u') onLine?.call('1007');
    return const RemoteResult(0, '');
  }

  @override
  Future<RemoteResult> copy(String host, String user, String from, String to) async => run(host, user, 'copy');
}
