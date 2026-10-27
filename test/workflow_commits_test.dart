// Linux only: it runs the workflows' commit-message steps in Bash.
@Tags(<String>['linux'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// Holds the commit-message steps of `.github/workflows/build.yml` and `shared-rules.yml`.
///
/// A direct push to `main` never meets the pull request's check, and a push the Build never starts
/// meets none at all, so the Build reads every pushed range and the daily run reads main's last day.
/// Each step's script is taken from the workflow itself and run with `git` and `java` stubbed.
void main() {
  const pushStep = "The pushed commits' messages";
  const dayStep = "Main's commits of the last day";
  const pullRequestStep = "The pull request's commit messages";
  const classpath = '/stub/a.jar:/stub/b.jar';
  final build = loadYaml(File('.github/workflows/build.yml').readAsStringSync()) as YamlMap;
  final sharedRules = loadYaml(File('.github/workflows/shared-rules.yml').readAsStringSync()) as YamlMap;
  late Directory scratch;

  setUp(() {
    scratch = Directory.systemTemp.createTempSync('commit-steps-');
    Directory('${scratch.path}/build').createSync();
    File('${scratch.path}/build/jdk-cp.txt').writeAsStringSync(classpath);
    final bin = Directory('${scratch.path}/bin')..createSync();
    _script('${bin.path}/java', r'printf "%s\n" "$@" >> "$JAVA_ARGUMENTS"; exit "$CHECK_EXIT"');
    // Answers only the calls the steps make, as git would; any other call fails.
    _script('${bin.path}/git', r'''
case "$*" in
'cat-file -e '*) [ "$#" -eq 3 ] && [ "$3" = "$KNOWN^{commit}" ] ;;
'rev-list -1 --before=26 hours ago HEAD') [ -z "$DAY_START" ] || printf '%s\n' "$DAY_START" ;;
*) echo "unexpected git $*" >&2; exit 99 ;;
esac''');
  });

  tearDown(() => scratch.deleteSync(recursive: true));

  Future<({int exit, String log, List<String> java})> execute(
    YamlMap step,
    Map<String, String> environment, {
    int checkExit = 0,
  }) async {
    final javaArguments = File('${scratch.path}/java-arguments')..writeAsStringSync('');
    final result = await Process.run(
      'bash',
      <String>['--noprofile', '--norc', '-e', '-o', 'pipefail', '-c', step['run'] as String],
      workingDirectory: scratch.path,
      includeParentEnvironment: false,
      environment: <String, String>{
        'PATH': '${scratch.path}/bin:/usr/bin:/bin',
        'KNOWN': 'none',
        'DAY_START': '',
        ...environment,
        'JAVA_ARGUMENTS': javaArguments.path,
        'CHECK_EXIT': '$checkExit',
      },
    ).timeout(const Duration(seconds: 10));
    return (exit: result.exitCode, log: '${result.stdout}${result.stderr}', java: javaArguments.readAsLinesSync());
  }

  /// Runs the Build's step for a push of [ref] from [before]; git holds [known].
  Future<({int exit, String log, List<String> java})> push(
    String ref,
    String before,
    String known, {
    int checkExit = 0,
  }) => execute(_named(build, 'build', pushStep), <String, String>{
    'PUSH_BEFORE': before,
    'GITHUB_SHA': '2222222',
    'GITHUB_REF': ref,
    'GITHUB_REF_TYPE': ref.startsWith('refs/tags/') ? 'tag' : 'branch',
    'KNOWN': known.isEmpty ? 'none' : known,
  }, checkExit: checkExit);

  Future<({int exit, String log, List<String> java})> pullRequest(
    String repository,
    String association,
    String author, {
    String server = 'https://github.com',
    int checkExit = 0,
  }) => execute(_named(sharedRules, 'check', pullRequestStep), <String, String>{
    'PR_BASE': '6666666',
    'PR_HEAD': '7777777',
    'PR_REPOSITORY': repository,
    'GITHUB_REPOSITORY': 'porelo-ai/porelo-frontend',
    'PR_ASSOCIATION': association,
    'PR_AUTHOR': author,
    'PR_SERVER': server,
  }, checkExit: checkExit);

  List<String> checked(String range, [List<String> more = const <String>[]]) => <String>[
    '-cp',
    classpath,
    'org.fuin.porelo.release.Main',
    'check-commits',
    range,
    ...more,
  ];

  const zeros = '0000000000000000000000000000000000000000';

  // The harm: the check skipped on a push, or fed a range a workflow expression built into the script.
  test('the Build checks the pushed range from its own environment', () {
    final step = _named(build, 'build', pushStep);
    expect(step['if'], "github.event_name == 'push'", reason: 'the step runs on a push');
    expect((step['env'] as YamlMap)['PUSH_BEFORE'], r'${{ github.event.before }}');
    expect(step['run'], isNot(contains(r'${{')), reason: 'the range reaches the script through its environment alone');
  });

  // The harm: a range the checkout cannot read, or a check that runs before its classpath is resolved.
  test('the build job checks out every commit and checks after the pinned JDK', () {
    final steps = ((build['jobs'] as YamlMap)['build'] as YamlMap)['steps'] as YamlList;
    final checkouts = steps.whereType<YamlMap>().where((s) => '${s['uses']}'.startsWith('actions/checkout@')).toList();
    expect(checkouts, hasLength(1), reason: 'the build job checks out once');
    expect((checkouts.single['with'] as YamlMap)['fetch-depth'], 0, reason: 'fetch-depth is the number 0');
    final names = <String>[for (final s in steps.whereType<YamlMap>()) '${s['name'] ?? s['uses']}'];
    expect(names.indexOf(pushStep), greaterThan(names.indexOf('./.github/actions/pinned-jdk')));
    expect(names.indexOf('./.github/actions/pinned-jdk'), greaterThan(names.indexOf('${checkouts.single['uses']}')));
  });

  // The harm: a pushed range going unchecked, or a refusal passing.
  test('a pushed range reaches check-commits and its refusal fails the step', () async {
    final passed = await push('refs/heads/main', '1111111', '1111111');
    expect(passed.exit, 0, reason: passed.log);
    expect(passed.java, checked('1111111..2222222'));
    final refused = await push('refs/heads/main', '1111111', '1111111', checkExit: 1);
    expect(refused.exit, isNot(0), reason: 'a refused range passed: ${refused.log}');
  });

  // The harm: a new branch, whose start is all zeros, checking nothing.
  test('a new branch is checked from main', () async {
    final run = await push('refs/heads/topic', zeros, '');
    expect(run.exit, 0, reason: run.log);
    expect(run.java.last, 'origin/main..2222222');
  });

  // The harm: a branch pushed over, whose old tip the checkout lacks, failing a clean push.
  test('a branch pushed over is checked from main', () async {
    final run = await push('refs/heads/topic', '3333333', '1111111');
    expect(run.exit, 0, reason: run.log);
    expect(run.java.last, 'origin/main..2222222');
  });

  // The harm: a tag, whose range from main is empty, checking nothing.
  test('a tag checks the commit it names', () async {
    final run = await push('refs/tags/v1.2.3', zeros, '');
    expect(run.exit, 0, reason: run.log);
    expect(run.java.last, '2222222~1..2222222');
  });

  // The harm: main moved from a commit nobody holds passing as an empty range.
  test('main moved from a commit the checkout lacks fails loudly', () async {
    final run = await push('refs/heads/main', '3333333', '1111111');
    expect(run.exit, isNot(0), reason: run.log);
    expect(run.log, contains('::error::'));
    expect(run.java, isEmpty, reason: 'check-commits started without a range');
  });

  // The harm: a missing start of the range silently checking nothing.
  for (final ref in <String>['refs/heads/main', 'refs/heads/topic', 'refs/tags/v1.2.3']) {
    test('a missing start fails loudly on $ref', () async {
      final run = await push(ref, '', '1111111');
      expect(run.exit, isNot(0), reason: run.log);
      expect(run.log, contains('::error::'));
      expect(run.java, isEmpty, reason: 'check-commits started without a range');
    });
  }

  // The harm: a push the Build never starts, of [skip ci] commits or documents alone, going unchecked.
  test("the schedule checks main's last day", () async {
    final step = _named(sharedRules, 'check', dayStep);
    expect(step['if'], "github.event_name == 'schedule'");
    expect(step['run'], isNot(contains(r'${{')), reason: 'the range comes from git, not a workflow expression');
    final steps = ((sharedRules['jobs'] as YamlMap)['check'] as YamlMap)['steps'] as YamlList;
    final checkout = steps.first as YamlMap;
    expect('${checkout['uses']}', startsWith('actions/checkout@'));
    expect((checkout['with'] as YamlMap)['fetch-depth'], 0, reason: "the checkout holds main's last day");

    final run = await execute(step, <String, String>{'DAY_START': '4444444'});
    expect(run.exit, 0, reason: run.log);
    expect(run.java, checked('4444444..HEAD'));
    final refused = await execute(step, <String, String>{'DAY_START': '4444444'}, checkExit: 1);
    expect(refused.exit, isNot(0), reason: 'a refused day passed: ${refused.log}');
  });

  // The harm: a repository younger than a day checking nothing, or leaving out its first commit.
  test('a repository younger than a day is read whole', () async {
    final run = await execute(_named(sharedRules, 'check', dayStep), <String, String>{'DAY_START': ''});
    expect(run.exit, 0, reason: run.log);
    expect(run.java, checked('HEAD'));
  });

  // The harm: a second fetch, which a private forge copy refuses to a checkout without credentials.
  test("a member's pull request is checked from the checkout alone", () async {
    for (final association in <String>['MEMBER', 'OWNER']) {
      final run = await pullRequest('porelo-ai/porelo-frontend', association, 'someone');
      expect(run.exit, 0, reason: '$association: ${run.log}');
      expect(run.java, checked('6666666..7777777'), reason: '$association is from inside');
    }
    final refused = await pullRequest('porelo-ai/porelo-frontend', 'MEMBER', 'someone', checkExit: 1);
    expect(refused.exit, isNot(0), reason: 'a refused pull request passed: ${refused.log}');
  });

  // The harm: a workflow expression in the script running what a pull request's title or branch carries.
  test("the pull request's facts reach the script through its environment", () {
    final step = _named(sharedRules, 'check', pullRequestStep);
    expect(step['if'], "github.event_name == 'pull_request'", reason: 'the step runs on a pull request');
    final env = step['env'] as YamlMap;
    expect(env['PR_BASE'], r'${{ github.event.pull_request.base.sha }}');
    expect(env['PR_HEAD'], r'${{ github.event.pull_request.head.sha }}');
    expect(env['PR_AUTHOR'], r'${{ github.event.pull_request.user.login }}');
    expect(env['PR_REPOSITORY'], r'${{ github.event.pull_request.head.repo.full_name }}');
    expect(env['PR_ASSOCIATION'], r'${{ github.event.pull_request.author_association }}');
    expect(env['PR_SERVER'], r'${{ github.server_url }}');
    expect(step['run'], isNot(contains(r'${{')));
  });

  // The harm: the repository's own update workflow's pull request refused for want of a sign-off.
  test("the own workflow's pull request is from inside", () async {
    final run = await pullRequest('porelo-ai/porelo-frontend', 'CONTRIBUTOR', 'github-actions[bot]');
    expect(run.exit, 0, reason: run.log);
    expect(run.java, checked('6666666..7777777'));
  });

  // The host's forge, as its runner names itself: it sends no author association at all.
  const forge = 'https://10.73.0.1:3000';

  // The harm: every pull request on the host's forge refused for want of a sign-off our own commits never carry.
  test("a forge pull request from the same repository is from inside", () async {
    final run = await pullRequest('porelo-ai/porelo-frontend', '', 'agent-machines', server: forge);
    expect(run.exit, 0, reason: run.log);
    expect(run.java, checked('6666666..7777777'));
  });

  // The harm: code from another forge repository passing without its author's sign-off.
  test('a forge pull request from elsewhere stays from outside', () async {
    final run = await pullRequest('someone/porelo-frontend', '', 'someone', server: forge);
    expect(run.java, checked('6666666..7777777', <String>['--outside']));
  });

  // The harm: code from outside passing without its author's sign-off.
  test('a pull request from elsewhere stays from outside', () async {
    final outside = checked('6666666..7777777', <String>['--outside']);
    expect((await pullRequest('someone/porelo-frontend', 'CONTRIBUTOR', 'github-actions[bot]')).java, outside);
    expect((await pullRequest('porelo-ai/porelo-frontend', 'CONTRIBUTOR', 'someone')).java, outside);
    expect((await pullRequest('someone/porelo-frontend', 'MEMBER', 'someone')).java, outside);
  });
}

void _script(String path, String body) {
  File(path).writeAsStringSync('#!/bin/sh\n$body\n');
  Process.runSync('chmod', <String>['755', path]);
}

YamlMap _named(YamlMap workflow, String job, String name) {
  final steps = ((workflow['jobs'] as YamlMap)[job] as YamlMap)['steps'] as YamlList;
  return steps.whereType<YamlMap>().firstWhere(
    (step) => step['name'] == name,
    orElse: () => fail('no step "$name" in the job $job'),
  );
}
