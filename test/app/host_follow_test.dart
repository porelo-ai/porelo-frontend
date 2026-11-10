import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_follow.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';
import 'package:porelo_frontend/src/app/run_here.dart';
import 'package:porelo_host/porelo_host.dart' show HostCardSsh;

const _key = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

final _build = Machine.fromHostCard(
  HostCardSsh(name: 'build', address: '203.0.113.7', sshPort: 22, hostKey: _key, login: 'mia', publicKey: _key),
  socketPath: '/run/person/daemon.sock',
);

/// Answers every command with [answer], keeping each remote line asked.
({SshHostFollow follow, List<String> asked}) _host(Ran answer) {
  final asked = <String>[];
  Future<Ran> run(
    String program,
    List<String> arguments, {
    String? inDirectory,
    Map<String, String> environment = const {},
    String? input,
  }) async {
    asked.add(arguments.last);
    return answer;
  }

  return (follow: SshHostFollow(run: run), asked: asked);
}

void main() {
  // Harm: the window runs a follow on a host that has none, or calls a host without it able.
  test('whether a host offers the start is asked of its Porelo, in the login shell, without starting it', () async {
    final offered = _host((code: 0, out: 'Usage: porelo host follow', err: ''));
    expect(await offered.follow.whyNotOffered(_build, 'build'), isNull);
    expect(offered.asked.single, contains("-lc 'porelo host follow --help'"));

    final older = _host((code: 2, out: '', err: "Unmatched argument at index 1: 'follow'"));
    expect(
      await older.follow.whyNotOffered(_build, 'build'),
      "build's Porelo offers no start of its read of the organization: it reads it at its next round, within five "
      'minutes.',
    );
    expect(older.asked, hasLength(1), reason: 'only asked, never started');
  });

  // Harm: a read that ended is said as anything but what the host answered.
  test("a completed read is said in the host's own words, a failed one with its status", () async {
    final done = _host((code: 0, out: '{"invocation":"${'a' * 32}","completed":true,"exitCode":0}', err: ''));
    expect(await done.follow.follow(_build, 'build'), 'build read the organization.');
    expect(done.asked.single, contains("-lc 'porelo host follow'"));

    final failed = _host((
      code: 65,
      out: '{"invocation":"${'b' * 32}","completed":true,"exitCode":65}',
      err: 'porelo-host: the commit is signed by no key in force\n',
    ));
    expect(
      await failed.follow.follow(_build, 'build'),
      'build read the organization, and its read ended with status 65: porelo-host: the commit is signed by no key '
      'in force',
    );
  });

  // Harm: a host without the start is offered it again, or its refusal is said in words of the window's own.
  test("a host without the start or refusing it says why, in the backend's words", () async {
    const unavailable = 'porelo: host follow is unavailable; update the host program to one supporting org follow-now';
    final older = _host((code: 69, out: '', err: '$unavailable\n'));
    await expectLater(
      older.follow.follow(_build, 'build'),
      throwsA(isA<HostFollowUnavailable>().having((gone) => gone.words, 'words', unavailable)),
    );

    final refused = _host((code: 65, out: '', err: 'porelo-host: mia is locked on this host\n'));
    await expectLater(
      refused.follow.follow(_build, 'build'),
      throwsA(
        isA<OrganizationRefused>()
            .having((it) => it.words, 'words', 'porelo-host: mia is locked on this host')
            .having((it) => it is HostFollowUnavailable, 'unavailable', isFalse),
      ),
    );
  });
}
