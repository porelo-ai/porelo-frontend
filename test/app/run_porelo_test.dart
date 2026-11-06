import 'dart:convert';
import 'dart:io' show systemEncoding;

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/desk.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';
import 'package:porelo_frontend/src/app/porelo_organization_source.dart';
import 'package:porelo_frontend/src/app/run_here.dart';
import 'package:porelo_frontend/src/app/run_porelo.dart';

// Guards a person's organization change, token or key sent nowhere on Windows, or to a distribution they do not watch,
// and a Windows path handed to Linux as it is.
void main() {
  late Desk previous;
  setUp(() => previous = desk);
  tearDown(() => desk = previous);
  void windows() => desk = Desk.of('windows', const <String, String>{'SystemRoot': r'D:\Windows'});

  final ran = <String>[];
  final inputs = <String?>[];
  final encodings = <Encoding>[];
  setUp(() {
    ran.clear();
    inputs.clear();
    encodings.clear();
  });

  Future<Ran> fake(
    String program,
    List<String> arguments, {
    String? inDirectory,
    Map<String, String> environment = const <String, String>{},
    String? input,
    Encoding encoding = systemEncoding,
  }) async {
    final line = [program, ...arguments].join(' ');
    ran.add(line);
    inputs.add(input);
    encodings.add(encoding);
    if (line.startsWith(r'wsl.exe -d Ubuntu --exec wslpath -a C:\')) {
      return (code: 0, out: '/mnt/c/Users/p/keys.kdbx\n', err: '');
    }
    if (line.contains('wslpath')) return (code: 1, out: '', err: 'wslpath: no such path');
    return (code: 0, out: '{}', err: '');
  }

  test('on Windows Porelo runs in the distribution that is this computer, with its input, read as UTF-8', () async {
    windows();
    final run = poreloRunner(run: fake, distribution: () => 'Ubuntu');
    await run('porelo', const ['org', 'show', '--json'], input: 'token');

    expect(ran, ['wsl.exe -d Ubuntu --exec porelo org show --json']);
    expect(inputs, ['token']);
    expect(encodings, [utf8]);
  });

  test('a Windows path goes as the distribution names it, and one it cannot name runs nothing', () async {
    windows();
    final run = poreloRunner(run: fake, distribution: () => 'Ubuntu');
    await run('porelo', const ['identity', 'rotate', '--keepassxc', r'C:\Users\p\keys.kdbx']);
    expect(ran, [
      r'wsl.exe -d Ubuntu --exec wslpath -a C:\Users\p\keys.kdbx',
      'wsl.exe -d Ubuntu --exec porelo identity rotate --keepassxc /mnt/c/Users/p/keys.kdbx',
    ]);

    ran.clear();
    await expectLater(
      run('porelo', const ['identity', 'backup-key', '--out', r'\\server\share\key']),
      throwsA(isA<WorkspaceRefused>()),
    );
    expect(ran.where((each) => each.contains('--exec porelo')), isEmpty);
  });

  test('a forge address is no path, and the distribution is this computer by default', () async {
    windows();
    Machine.thisComputersDistribution = 'Debian';
    addTearDown(() => Machine.thisComputersDistribution = null);
    await poreloRunner(run: fake)('porelo', const ['org', 'create', 'g:/owner/repository.git']);
    expect(ran, ['wsl.exe -d Debian --exec porelo org create g:/owner/repository.git']);
  });

  test('a refusal before the start is an answer: the organization keeps no change waiting for one', () async {
    windows();
    final source = PoreloOrganizationSource(
      run: poreloRunner(run: fake, distribution: () => null),
    );
    await expectLater(
      source.read(),
      throwsA(isA<OrganizationRefused>().having((refused) => refused.answered, 'answered', isTrue)),
    );
  });

  test('on Windows with no distribution nothing runs, and the refusal says where to add one', () async {
    windows();
    final run = poreloRunner(run: fake, distribution: () => null);
    await expectLater(
      run('porelo', const ['org', 'show', '--json']),
      throwsA(isA<WorkspaceRefused>().having((refused) => refused.words, 'words', contains('Add a machine'))),
    );
    expect(ran, isEmpty);
  });

  test('on Linux Porelo runs here as it is', () async {
    final run = poreloRunner(run: fake, distribution: () => 'Ubuntu');
    await run('porelo', const ['org', 'show', r'C:\not-a-path-here']);
    expect(ran, [r'porelo org show C:\not-a-path-here']);
  });
}
