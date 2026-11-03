import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_progress.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';

void main() {
  // Harm: a host admin sees a project as carried that the host holds back, or an account's end goes unsaid.
  test('the contract answer is read: state, why, and the day an account goes', () {
    final read = HostProgress.read('''
{"organization": "ok", "projects": [
  {"project": "demo", "state": "held", "why": "app has unpushed commits", "since": "2026-11-02"},
  {"project": "other", "state": "waiting-for-token", "why": null, "since": null}],
 "persons": [{"login": "rex", "purge_on": "2026-11-09"}, {"login": "pat"}], "later": 1}
''');
    expect(read.of('demo')?.state, 'held');
    expect(read.of('demo')?.why, 'app has unpushed commits');
    expect(read.of('other')?.waitsForToken, isTrue);
    expect(read.wantsToken, isTrue);
    expect(read.locked.single.login, 'rex');
    expect(read.locked.single.purgeOn, '2026-11-09');
  });

  // Harm: today's host, which answers neither part, breaks the page; or a first `up` waiting goes unsaid.
  test("an older host's answer says nothing of them, and a host waiting for its first token says so", () {
    expect(HostProgress.read('{"host":"h","persons":[{"login":"a"}]}').projects, isEmpty);
    expect(HostProgress.read('{"host":"h"}').wantsToken, isFalse);
    expect(HostProgress.read('{"organization":"waiting-for-token"}').wantsToken, isTrue);
  });

  // Harm: a fetch the host refused goes unseen, and a host admin takes the old state for the organization's.
  test('what the last fetch refused is read, and null or another shape says nothing', () {
    expect(
      HostProgress.read('{"refused":"the commit is signed by no key in force"}').refused,
      contains('signed by no key'),
    );
    expect(HostProgress.read('{"refused":null}').refused, isNull);
    expect(HostProgress.read('{"refused":7}').refused, isNull);
    expect(HostProgress.read('{"host":"h"}').refused, isNull);
  });

  test('what is no answer is refused', () {
    expect(() => HostProgress.read('no'), throwsA(isA<OrganizationRefused>()));
  });

  group('asking', () {
    late List<String> asked;
    late String? fed;
    late ({int code, String out, String err}) answer;
    late SshHostProgress progress;

    setUp(() {
      asked = [];
      fed = 'unset';
      answer = (code: 0, out: '{}', err: '');
      progress = SshHostProgress(
        run: (program, arguments, {inDirectory, environment = const {}, input}) async {
          asked = [program, ...arguments];
          fed = input;
          return answer;
        },
      );
    });

    // Harm: an unpinned ssh, or another account, is used to reach root; or a token could lie on the standard input.
    test('root is asked through the pinned config, with no agent', () async {
      await progress.refresh('/c/build.conf', 'build');
      expect(asked.first, 'ssh');
      expect(asked.sublist(1, 3), ['-F', '/c/build.conf']);
      expect(asked, containsAll(['ForwardAgent=no', 'BatchMode=yes', 'root@build']));
      expect(asked.last, SshHostProgress.refreshVerb);
      expect(fed, '');
    });

    // Harm: a host admin gives a token that cannot help, as the host took no address for the project, and is told
    // the host still waits for it; or a project that does wait is no longer offered the token.
    group('a project waiting for the token', () {
      late Map<String, String> files;
      late List<String> verbs;

      setUp(() {
        files = {};
        verbs = [];
        progress = SshHostProgress(
          run: (program, arguments, {inDirectory, environment = const {}, input}) async {
            final verb = arguments.last;
            verbs.add(verb);
            if (verb == SshHostProgress.statusVerb) {
              return (
                code: 0,
                out:
                    '{"projects":[{"project":"demo","state":"waiting-for-token"},'
                    '{"project":"lost","state":"waiting-for-token"},{"project":"done","state":"carried"}]}',
                err: '',
              );
            }
            final name = RegExp(r'projects/(.+)\.json').firstMatch(verb)?.group(1);
            final file = files[name];
            return file == null ? (code: 1, out: '', err: 'no such file') : (code: 0, out: file, err: '');
          },
        );
      });

      test('with no address on the host it wants no token', () async {
        files = {'demo': '{"address":"git@forge:o/demo.git"}', 'lost': '{"address":null}'};
        final read = await progress.status('/c/build.conf', 'build');
        expect(read.of('demo')!.waitsForToken, isTrue);
        expect(read.of('lost')!.waitsForToken, isFalse);
        expect(read.of('lost')!.hasNoAddress, isTrue);
        expect(read.wantsToken, isTrue);
      });

      test('alone, it leaves nothing to give a token for', () async {
        files = {'demo': '{"address":null}', 'lost': '{"address":null}'};
        expect((await progress.status('/c/build.conf', 'build')).wantsToken, isFalse);
      });

      test('what cannot be read leaves the offer as the host said it', () async {
        final read = await progress.status('/c/build.conf', 'build');
        expect(read.of('lost')!.hasNoAddress, isFalse);
        expect(read.wantsToken, isTrue);
      });

      test('only those waiting are read, and a name a shell could read otherwise is not', () async {
        files = {'demo': '{"address":"a"}', 'lost': '{"address":"a"}'};
        await progress.status('/c/build.conf', 'build');
        expect(verbs.where((verb) => verb.contains('done')), isEmpty);
        expect(verbs, hasLength(3));
        final odd = SshHostProgress(
          run: (program, arguments, {inDirectory, environment = const {}, input}) async {
            verbs.add(arguments.last);
            return (code: 0, out: r'{"projects":[{"project":"a;$(x)","state":"waiting-for-token"}]}', err: '');
          },
        );
        verbs.clear();
        final read = await odd.status('/c/build.conf', 'build');
        expect(verbs, [SshHostProgress.statusVerb]);
        expect(read.wantsToken, isTrue);
      });
    });

    // Harm: a key a follow took off root reads as a fault of the host, or as the wait a person's own account has.
    test('a key the host does not take as root is said as no longer an admin\'s', () async {
      answer = (code: 255, out: '', err: 'root@192.0.2.1: Permission denied (publickey).\n');
      await expectLater(
        progress.status('/c/build.conf', 'build'),
        throwsA(
          isA<OrganizationRefused>().having(
            (refused) => refused.words,
            'words',
            allOf(contains('not a key of this host'), isNot(contains('five minutes'))),
          ),
        ),
      );
    });

    // Harm: a refusal reads as a state.
    test("a refusal is said in the host's words", () async {
      answer = (code: 65, out: '', err: 'porelo-host-person: nope\n');
      await expectLater(
        progress.status('/c/build.conf', 'build'),
        throwsA(isA<OrganizationRefused>().having((refused) => refused.words, 'words', 'porelo-host-person: nope')),
      );
    });
  });
}
