import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/access_developers.dart';
import 'package:porelo_frontend/src/app/project_developers.dart';
import 'package:porelo_host/porelo_host.dart';

class SyncRemote implements Remote {
  String response = '';
  int code = 0;
  String errors = '';
  final calls = <({String host, String user, String command, String? input})>[];
  @override
  Future<RemoteResult> run(
    String host,
    String user,
    String command, {
    String? input,
    void Function(String)? onLine,
  }) async {
    calls.add((host: host, user: user, command: command, input: input));
    for (final line in const LineSplitter().convert(response)) {
      onLine?.call(line);
    }
    return RemoteResult(code, errors);
  }

  @override
  Future<RemoteResult> copy(String host, String user, String from, String to) =>
      throw StateError('Sync uploads no files.');
}

void main() {
  final listed = parseAccessDevelopers(
    'host: {network: 10.77.0.0/24, ssh_host_key: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"}\ndevelopers: {}\n',
  );
  late SyncRemote remote;
  setUp(() {
    remote = SyncRemote()
      ..response = jsonEncode({
        'project': 'demo',
        'commit': 'a' * 40,
        'access_commit': 'b' * 40,
        'added': ['developer'],
        'dropped': <String>[],
        'unchanged': false,
        'laptops_added': ['developer/l1'],
        'laptops_dropped': <String>[],
      });
  });

  // Harm: admission must not run in root's SSH account or call a different privileged helper.
  test('the project admin sync uses the host network and exact checked helper', () async {
    final answer = await DeveloperHostSync(remote: remote, account: 'admin').call('demo', listed);
    expect(remote.calls, hasLength(1));
    final call = remote.calls.single;
    expect(call.host, '10.77.0.1');
    expect(call.user, 'admin');
    expect(
      call.command,
      inTheLoginShell('/usr/bin/sudo -n /usr/local/sbin/porelo-host-person sync ${quoteForAShell('demo')}'),
    );
    expect(call.input, isNull, reason: 'public admission reads the signed file, not keys or secrets on stdin');
    expect(answer.added, ['developer']);
    expect(answer.laptopsAdded, ['developer/l1']);
  });

  // Harm: root or shell/path input can perform the wrong privileged action.
  test('unsafe account and project names are refused before a remote command', () async {
    for (final account in ['root', 'admin; id', '../admin']) {
      await expectLater(
        DeveloperHostSync(remote: remote, account: account).call('demo', listed),
        throwsFormatException,
      );
    }
    await expectLater(
      DeveloperHostSync(remote: remote, account: 'admin').call('../demo', listed),
      throwsA(isA<HostFilesRefused>()),
    );
    expect(remote.calls, isEmpty);
  });

  // Harm: a refused helper must not be reported as successful admission.
  test('a host refusal keeps the helper reason', () async {
    remote.code = 1;
    remote.errors = 'The account is not this project’s admin.';
    await expectLater(
      DeveloperHostSync(remote: remote, account: 'admin').call('demo', listed),
      throwsA(isA<HostAdminRefused>().having((e) => e.words, 'helper reason', remote.errors)),
    );
  });

  // Harm: startup noise or another project's reply must never confirm this project's access.
  test('the host must answer once and identify the selected project', () async {
    final good = remote.response;
    for (final reply in ['', '$good\n$good', good.replaceFirst('"demo"', '"other"'), 'not JSON']) {
      remote.response = reply;
      await expectLater(
        DeveloperHostSync(remote: remote, account: 'admin').call('demo', listed),
        throwsFormatException,
      );
    }
  });
}
