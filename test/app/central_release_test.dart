import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/central_release.dart';
import 'package:porelo_frontend/src/app/host_progress.dart';

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
}
