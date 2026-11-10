import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/central_release.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';
import 'package:porelo_frontend/src/app/host_progress.dart';

/// A machine whose pushes to central stay open until the test ends them.
class _Backend extends Fake implements FleetBackend {
  final asked = <List<String>?>[];
  final pushes = <StreamController<CentralPushProgress>>[];

  @override
  Stream<CentralPushProgress> pushToCentral(String project, {List<String>? repositories}) {
    asked.add(repositories);
    final push = StreamController<CentralPushProgress>();
    pushes.add(push);
    return push.stream;
  }
}

/// Which repositories *Bring it to central…* names, and how a refusal reads.
void main() {
  HostProjectProgress hostSays(String repository, HostRepositoryCentral central) => HostProjectProgress(
    project: 'checkout',
    state: 'carried',
    repositories: [(repository: repository, state: 'taken', why: null, central: central)],
  );

  // Harm: a push named for a repository the machine does not carry, or one whose central moved on, asks the person to
  // agree to what cannot happen; one the host says is ahead but left out keeps finished work from central.
  test('it names what the machine or, where it says nothing more, the host says is ahead, and nothing else', () {
    final listed = [
      const Repository(name: 'payments-api', central: 'ahead', ahead: 3),
      const Repository(name: 'billing', central: 'moved-on'),
      const Repository(name: 'ledger', central: 'ahead', ahead: 2, carriedHere: false),
      const Repository(name: 'audit', central: 'up-to-date'),
      const Repository(name: 'search'),
    ];
    final progress = HostProjectProgress(
      project: 'checkout',
      state: 'carried',
      repositories: [
        (
          repository: 'audit',
          state: 'taken',
          why: null,
          central: const HostRepositoryCentral(state: 'ahead', commits: 1),
        ),
        (
          repository: 'search',
          state: 'taken',
          why: null,
          central: const HostRepositoryCentral(state: 'ahead', commits: 4),
        ),
        (
          repository: 'billing',
          state: 'taken',
          why: null,
          central: const HostRepositoryCentral(state: 'ahead', commits: 5),
        ),
      ],
    );
    expect(aheadOfCentral(listed: listed, progress: progress), [
      (repository: 'payments-api', commits: 3),
      (repository: 'audit', commits: 1),
      (repository: 'search', commits: 4),
    ]);
  });

  // Harm: a count the machine did not give is said as one it did, naming commits that are not there.
  test('ahead with no count is named without one', () {
    final ahead = aheadOfCentral(
      listed: const [Repository(name: 'payments-api', central: 'ahead')],
    );
    expect(commitsToBring(ahead), 'commits of payments-api, how many not reported');
    expect(
      aheadOfCentral(
        listed: const [],
        progress: hostSays('billing', const HostRepositoryCentral(state: 'up-to-date')),
      ),
      isEmpty,
    );
  });

  // Harm: a refused token read as a prompt or a success sends the person to type a token nobody asked for, or to
  // believe work reached central that did not; what reached central before the refusal must not be lost.
  test('a refused token is said as refused, with what reached central before it', () {
    final words = centralRefusalWords(
      CentralPushRefusal(
        const VarlinkException('org.fuin.porelo.Tasks1.CentralTokenRefused', <String, dynamic>{
          'credential': 'acme.central',
          'storeCommand': <String>[],
          'repository': 'billing',
          'pushed': <String>['payments-api'],
          'upToDate': <String>[],
          'forge': 'git.acme.example',
          'status': 401,
        }),
      ),
    );
    expect(words, contains('git.acme.example refused the token acme.central (HTTP 401) at billing'));
    expect(words, contains('Brought to central before it stopped: payments-api.'));
  });

  // Harm: a push of a machine taken out of the window runs on with nobody to say its answer to, and a window closing
  // waits forever on a push it no longer watches.
  test('forgetting the machine, or closing, cancels its push, and the wait for it ends', () async {
    final backend = _Backend();
    final releases = CentralReleases();
    final forgotten = releases.bring(backend, machine: 'm', project: 'checkout', repositories: ['payments-api']);
    final other = releases.bring(backend, machine: 'n', project: 'checkout', repositories: ['payments-api']);
    await pumpEventQueue();
    var cancelled = 0;
    for (final push in backend.pushes) {
      push.onCancel = () => cancelled++;
    }
    releases.forget(keep: {'n'});
    await forgotten.timeout(const Duration(seconds: 1));
    expect(cancelled, 1);
    expect(releases.running('m', 'checkout'), isFalse);
    expect(releases.running('n', 'checkout'), isTrue);
    releases.dispose();
    await other.timeout(const Duration(seconds: 1));
    expect(cancelled, 2);
  });

  // Harm: two presses push twice, the second with what was ahead before the first; an empty list is every
  // repository the push configuration names, never none.
  test('a second press while the first asks or runs starts nothing, and an empty list pushes nothing', () async {
    final backend = _Backend();
    final releases = CentralReleases();
    addTearDown(releases.dispose);
    final agreeing = Completer<bool>();
    final first = releases.bring(
      backend,
      machine: 'm',
      project: 'checkout',
      repositories: ['payments-api'],
      agree: () => agreeing.future,
    );
    expect(releases.running('m', 'checkout'), isTrue);
    var askedAgain = false;
    await releases.bring(
      backend,
      machine: 'm',
      project: 'checkout',
      repositories: ['payments-api'],
      agree: () async => askedAgain = true,
    );
    expect(askedAgain, isFalse);
    agreeing.complete(true);
    await pumpEventQueue();
    expect(backend.asked, [
      ['payments-api'],
    ]);
    backend.pushes.single.add(const CentralPushProgress(pushed: ['payments-api'], upToDate: []));
    await backend.pushes.single.close();
    await first;
    await releases.bring(backend, machine: 'm', project: 'billing', repositories: const []);
    expect(backend.asked, hasLength(1));
  });

  // Harm: an answer naming nothing reads as a push that went well.
  test('a final answer naming nothing is said as refused', () async {
    final backend = _Backend();
    final releases = CentralReleases();
    addTearDown(releases.dispose);
    final done = releases.bring(backend, machine: 'm', project: 'checkout', repositories: ['payments-api']);
    await pumpEventQueue();
    backend.pushes.single.add(const CentralPushProgress(pushed: [], upToDate: []));
    await backend.pushes.single.close();
    await done;
    expect(releases.said('m', 'checkout')!.refused, isTrue);
  });

  // Harm: a repository the host does not carry, or has not taken, is offered to push; one this window just saw reach
  // central stays offered on the host's older word.
  test('what the host has not taken, does not carry, or this window saw reach central is not named', () {
    final progress = HostProjectProgress(
      project: 'checkout',
      state: 'carried',
      repositories: [
        (repository: 'billing', state: 'not-carried', why: null, central: null),
        (
          repository: 'audit',
          state: 'taken',
          why: null,
          central: const HostRepositoryCentral(state: 'ahead', commits: 1),
        ),
        (
          repository: 'search',
          state: 'taken',
          why: null,
          central: const HostRepositoryCentral(state: 'ahead', commits: 4),
        ),
      ],
    );
    final listed = [
      const Repository(name: 'billing', central: 'ahead', ahead: 2),
      const Repository(name: 'audit', central: 'up-to-date'),
      const Repository(name: 'search'),
    ];
    expect(
      aheadOfCentral(listed: listed, progress: progress, carriedAlone: ['billing', 'audit'], atCentral: {'audit'}),
      isEmpty,
    );
    expect(
      saysOfCentral(
        listed: const [Repository(name: 'billing', central: 'ahead', carriedHere: false)],
      ),
      isFalse,
    );
  });

  // Harm: a command shown with a placeholder, or a label with a hole, sends the person to run what cannot run.
  test('a placeholder nothing fills is not shown, and an empty name or reason leaves no hole', () {
    final shut = centralRefusalWords(
      CentralPushRefusal(
        const VarlinkException('org.fuin.porelo.Tasks1.CentralVaultShut', <String, dynamic>{
          'unlock': 'host',
          'unlockCommand': <String>['porelo', 'host', 'unlock', '<host>'],
        }),
      ),
    );
    expect(shut, isNot(contains('<host>')));
    final issuer = centralRefusalWords(
      CentralPushRefusal(
        const VarlinkException('org.fuin.porelo.Tasks1.HostPushTokenUnavailable', <String, dynamic>{'reason': ''}),
      ),
    );
    expect(issuer, isNot(contains('()')));
    expect(storeCentralTokenCommand(credential: '', run: () {}).label, isNot(contains('  ')));
  });
}
