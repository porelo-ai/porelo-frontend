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
