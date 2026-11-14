import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/wsl.dart';
import 'package:porelo_frontend/src/app/wsl_setup.dart';
import 'package:porelo_frontend/src/ui/wsl_machine.dart';

import '../features/support/world.dart';

/// The checks before a WSL distribution is connected to, in order, stopping at the first that
/// fails; and the offer to set Porelo up, shown line by line and run only after a yes, the key checked
/// against the fingerprint the interface carries.
void main() {
  const windows11 = '"Windows 11 Pro" 10.0 (Build 26100)';
  const ubuntu = 'PRETTY_NAME="Ubuntu 26.04 LTS"\nID=ubuntu\nVERSION_ID="26.04"\n';

  /// A distribution called Ubuntu that runs as WSL2, answering [answers] by command.
  ({Wsl wsl, WslSetup setup, List<String> ran}) distribution({
    String os = ubuntu,
    String systemd = 'running',
    bool porelo = true,
    bool daemon = true,
    String fingerprint = poreloKeyFingerprint,
    int failAt = -1,
    String version = windows11,
  }) {
    final ran = <String>[];
    final wsl = Wsl(
      run: (arguments) async => (
        code: 0,
        printed: switch (arguments.join(' ')) {
          '-l -q' || '-l --running -q' => 'Ubuntu\n'.codeUnits,
          '-l -v' => '  NAME   STATE   VERSION\n* Ubuntu Running 2\n'.codeUnits,
          _ => <int>[],
        },
      ),
    );
    final setup = WslSetup(
      distribution: 'Ubuntu',
      operatingSystemVersion: version,
      wsl: wsl,
      answers: (_) async => daemon,
      run: (name, command, {bool asRoot = false}) async {
        final line = '${asRoot ? 'root: ' : ''}${command.join(' ')}';
        ran.add(line);
        if (failAt >= 0 && ran.length - 1 == failAt) return (code: 1, said: 'it failed');
        return switch (command.join(' ')) {
          'cat /etc/os-release' => (code: 0, said: os),
          'systemctl is-system-running' => (code: systemd == 'offline' ? 1 : 0, said: systemd),
          'porelo --version' => (code: porelo ? 0 : 127, said: porelo ? 'porelo 0.4.2' : 'not found'),
          'id -un' => (code: 0, said: 'somebody\n'),
          'gpg --show-keys --with-colons /tmp/porelo.asc' => (
            code: 0,
            said: 'pub:-:4096:1:6B488A9326920DBE:::::\nfpr:::::::::$fingerprint:\n',
          ),
          _ => (code: 0, said: ''),
        };
      },
    );
    return (wsl: wsl, setup: setup, ran: ran);
  }

  test('a supported running distribution with Porelo answering passes every check', () async {
    final it = distribution().setup;

    await it.check();

    expect(it.ready, isTrue);
    expect(it.machine.kind, 'wsl');
    expect(it.machine.distribution, 'Ubuntu');
  });

  test('a Windows older than build 19041 is told so, and nothing else is asked', () async {
    final it = distribution(version: '"Windows 10 Pro" 10.0 (Build 18363)').setup;

    await it.check();

    expect(it.failed?.check, WslCheck.windows);
    expect(it.failed?.words, contains('build 18363'));
    expect(it.findings, hasLength(1));
  });

  test('a system Porelo does not support is said, and no setup is offered', () async {
    final it = distribution(os: 'PRETTY_NAME="Ubuntu 24.04 LTS"\nID=ubuntu\nVERSION_ID="24.04"\n').setup;

    await it.check();

    expect(it.failed?.check, WslCheck.supported);
    expect(it.failed?.words, contains('Ubuntu 24.04 LTS'));
    expect(it.offersTheSetup, isFalse);
  });

  test('without systemd, the separate question is asked, not the setup', () async {
    final it = distribution(systemd: 'offline').setup;

    await it.check();

    expect(it.asksForSystemd, isTrue);
    expect(it.offersTheSetup, isFalse);
  });

  test('without Porelo, the setup is offered', () async {
    final it = distribution(porelo: false).setup;

    await it.check();

    expect(it.failed?.check, WslCheck.porelo);
    expect(it.offersTheSetup, isTrue);
  });

  test('the supported systems are Ubuntu 26.04 or later, Debian 13 and Fedora 43 and 44', () {
    bool supported(String id, String version) => OsRelease(id: id, version: version, name: '').supported;

    expect(supported('ubuntu', '26.04'), isTrue);
    expect(supported('ubuntu', '26.10'), isTrue);
    expect(supported('ubuntu', '24.04'), isFalse);
    expect(supported('debian', '13'), isTrue);
    expect(supported('debian', '12'), isFalse);
    expect(supported('fedora', '43'), isTrue);
    expect(supported('fedora', '44'), isTrue);
    expect(supported('fedora', '42'), isFalse);
    expect(supported('arch', ''), isFalse);
  });

  test('the lines for apt name the key, the source, the agents chosen, lingering and the setup', () async {
    final it = distribution(porelo: false).setup;
    await it.check();
    it.agents.addAll(<String>{'porelo-agent-pi', 'porelo-agent-claude'});

    final shown = it.setupLines('somebody').map((each) => each.shown).toList();

    expect(shown, <String>[
      "sudo sh -c 'curl -fsSL $poreloKeyAddress -o /tmp/porelo.asc'",
      'sudo gpg --dearmor --yes -o /usr/share/keyrings/porelo.gpg /tmp/porelo.asc',
      'sudo sh -c \'echo "deb [signed-by=/usr/share/keyrings/porelo.gpg] $poreloDebRepository releases main" '
          '> /etc/apt/sources.list.d/porelo.list\'',
      "sudo sh -c 'apt-get update && apt-get install -y porelo porelo-agent-claude porelo-agent-pi'",
      'sudo loginctl enable-linger somebody',
      'porelo setup',
    ]);
  });

  test('nothing is chosen in advance: with no agent chosen, only Porelo is installed', () async {
    final it = distribution(porelo: false, os: 'PRETTY_NAME="Fedora Linux 44"\nID=fedora\nVERSION_ID=44\n').setup;
    await it.check();

    final shown = it.setupLines('somebody').map((each) => each.shown).toList();

    expect(it.agents, isEmpty);
    expect(shown, contains("sudo sh -c 'dnf install -y porelo'"));
    expect(shown.join('\n'), contains('/etc/yum.repos.d/porelo.repo'));
  });

  test('a key that does not match the carried fingerprint stops the setup before anything is written', () async {
    final run = distribution(porelo: false, fingerprint: '0000000000000000000000000000000000000000');
    final recorded = <String>[];
    final it = WslSetup(
      distribution: 'Ubuntu',
      operatingSystemVersion: windows11,
      wsl: Wsl(run: (arguments) async => (code: 0, printed: <int>[])),
      run: (name, command, {bool asRoot = false}) async {
        run.ran.add(command.join(' '));
        return command.first == 'gpg' && command[1] == '--show-keys'
            ? (
                code: 0,
                said: 'pub:-:4096:1:0000000000000000:::::\nfpr:::::::::0000000000000000000000000000000000000000:\n',
              )
            : (code: 0, said: '');
      },
      record: (line, said) => recorded.add(line),
    );

    await it.runSetup(it.setupLines('somebody'));

    expect(it.stopped, contains('Expected $poreloKeyFingerprint'));
    expect(it.stopped, contains('0000000000000000000000000000000000000000'));
    expect(run.ran.where((each) => each.contains('dearmor') || each.contains('install')), isEmpty);
    expect(recorded, contains('check the key'));
  });

  // The harm: a file holding Porelo's key and another after it passed the check, and both went
  // into apt's keyring, so packages signed by the other were trusted as Porelo's.
  test('a file holding a second key besides the carried one stops the setup before anything is written', () async {
    final run = distribution(porelo: false);
    final it = WslSetup(
      distribution: 'Ubuntu',
      operatingSystemVersion: windows11,
      wsl: Wsl(run: (arguments) async => (code: 0, printed: <int>[])),
      run: (name, command, {bool asRoot = false}) async {
        run.ran.add(command.join(' '));
        return command.first == 'gpg' && command[1] == '--show-keys'
            ? (
                code: 0,
                said:
                    'pub:-:4096:1:68D19D175D904415:::::\nfpr:::::::::$poreloKeyFingerprint:\n'
                    'sub:-:4096:1:1111111111111111:::::\nfpr:::::::::1111111111111111111111111111111111111111:\n'
                    'pub:-:4096:1:2222222222222222:::::\nfpr:::::::::2222222222222222222222222222222222222222:\n',
              )
            : (code: 0, said: '');
      },
    );

    await it.runSetup(it.setupLines('somebody'));

    expect(it.stopped, contains('2222222222222222222222222222222222222222'));
    expect(run.ran.where((each) => each.contains('dearmor') || each.contains('install')), isEmpty);
  });

  test("the carried key with a subkey of its own is Porelo's key, and the setup goes on", () async {
    final run = distribution(porelo: false);
    final it = WslSetup(
      distribution: 'Ubuntu',
      operatingSystemVersion: windows11,
      wsl: Wsl(run: (arguments) async => (code: 0, printed: <int>[])),
      run: (name, command, {bool asRoot = false}) async {
        run.ran.add(command.join(' '));
        return command.first == 'gpg' && command[1] == '--show-keys'
            ? (
                code: 0,
                said:
                    'pub:-:4096:1:68D19D175D904415:::::\nfpr:::::::::$poreloKeyFingerprint:\n'
                    'sub:-:4096:1:1111111111111111:::::\nfpr:::::::::1111111111111111111111111111111111111111:\n',
              )
            : (code: 0, said: '');
      },
    );

    await it.runSetup(it.setupLines('somebody'));

    expect(it.stopped, isNull);
    expect(run.ran.where((each) => each.contains('dearmor')), isNotEmpty);
  });

  test('every line that ran is recorded, and a failing one stops the rest', () async {
    final run = distribution(porelo: false, failAt: 3);
    final recorded = <String>[];
    final it = WslSetup(
      distribution: 'Ubuntu',
      operatingSystemVersion: windows11,
      wsl: Wsl(run: (arguments) async => (code: 0, printed: <int>[])),
      run: (name, command, {bool asRoot = false}) async {
        run.ran.add(command.join(' '));
        if (command.join(' ').startsWith('sh -c echo')) return (code: 1, said: 'refused');
        return command.first == 'gpg' && command[1] == '--show-keys'
            ? (code: 0, said: 'pub:-:4096:1:68D19D175D904415:::::\nfpr:::::::::$poreloKeyFingerprint:\n')
            : (code: 0, said: '');
      },
      record: (line, said) => recorded.add(line),
    );

    await it.runSetup(it.setupLines('somebody'));

    expect(it.stopped, contains('ended with 1'));
    expect(recorded, hasLength(3));
    expect(run.ran.where((each) => each.contains('apt-get')), isEmpty);
  });

  test('the Windows build is read from what Dart says the system is', () {
    expect(windowsBuild('"Windows 10 Pro" 10.0 (Build 19045)'), 19045);
    expect(windowsBuild('Linux 7.0.0'), isNull);
  });

  // Harm: a snapshot window sets WSL up with release Porelo, which lacks what the snapshot window expects.
  testWidgets(
    'a snapshot window offers and runs the snapshots repository in WSL, and a release window the releases repository',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const fedora = 'PRETTY_NAME="Fedora Linux 44"\nID=fedora\nVERSION_ID=44\n';
      for (final (release, debWanted, debOther, rpmWanted, rpmOther) in <(bool, String, String, String, String)>[
        (
          false,
          '$poreloDebRepository snapshots main',
          '$poreloDebRepository releases main',
          'baseurl=$poreloRpmRepository/snapshots',
          'baseurl=$poreloRpmRepository/releases',
        ),
        (
          true,
          '$poreloDebRepository releases main',
          '$poreloDebRepository snapshots main',
          'baseurl=$poreloRpmRepository/releases',
          'baseurl=$poreloRpmRepository/snapshots',
        ),
      ]) {
        for (final (os, wanted, other) in <(String, String, String)>[
          (ubuntu, debWanted, debOther),
          (fedora, rpmWanted, rpmOther),
        ]) {
          final it = distribution(os: os, porelo: false);
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: WslSteps(onReady: (_) {}, wsl: it.wsl, setupFor: (_) => it.setup, snapshots: !release),
                ),
              ),
            ),
          );
          await World.settle(tester);
          await tester.tap(find.byKey(const Key('wsl-distribution')));
          await World.settle(tester);
          await tester.tap(find.byKey(const Key('wsl-Ubuntu')).last);
          await World.settle(tester);
          await tester.tap(find.byKey(const Key('wsl-check')));
          await World.settle(tester);

          final shown =
              tester
                  .widget<SelectableText>(
                    find.descendant(of: find.byKey(const Key('wsl-lines')), matching: find.byType(SelectableText)),
                  )
                  .data ??
              '';
          expect(shown, contains(wanted), reason: 'release=$release offered lines');
          expect(shown, isNot(contains(other)), reason: 'release=$release offered lines');

          await tester.ensureVisible(find.byKey(const Key('wsl-run-setup')));
          await World.settle(tester);
          await tester.tap(find.byKey(const Key('wsl-run-setup')));
          await World.settle(tester);

          expect(it.ran.join('\n'), contains(wanted), reason: 'release=$release run lines');
          expect(it.ran.join('\n'), isNot(contains(other)), reason: 'release=$release run lines');
          await tester.pumpWidget(const SizedBox.shrink());
          it.setup.dispose();
        }
      }
    },
  );
}
