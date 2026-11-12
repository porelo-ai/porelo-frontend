import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

import 'e2e.dart';
import 'rehearsal.dart';

/// A real idea's walk, as `tool/walk_idea.sh` names it: the project, the planner it put on the path, the planner's
/// probe and the forge the project's repositories are on.
abstract final class Walk {
  /// The project the window and the probe name.
  static String get project => _required('PORELO_WALK_PROJECT');

  /// The project porelo runs the walk's tasks under, which knows the issue repository.
  static String get poreloProject => _required('PORELO_WALK_PORELO_PROJECT');

  /// The agent every task of the walk runs.
  static String get agent => _required('PORELO_WALK_AGENT');

  /// That agent's model.
  static String get model => _required('PORELO_WALK_MODEL');

  /// The planner's read-only probe.
  static String get probe => _required('PORELO_WALK_PROBE');

  /// The planner the driver put first on the path.
  static String get planner => _required('PORELO_WALK_PLANNER');

  /// The project repository's clone URL.
  static String get ownUrl => _required('PORELO_WALK_OWN_URL');

  /// The clone URL of the forge's repository [name], beside the project's own and spelled as it is.
  static String urlOf(String name) =>
      '${ownUrl.substring(0, ownUrl.lastIndexOf('/') + 1)}$name${ownUrl.endsWith('.git') ? '.git' : ''}';

  /// The repositories the issues are worked in, one issue, one builder and one reader each.
  static List<String> get issueRepositories => _required('PORELO_WALK_ISSUE_REPOS').split(' ');

  /// The tip of the issue repository [repository] when the run started.
  static String issueHeadOf(String repository) {
    for (final each in _required('PORELO_WALK_ISSUE_HEADS').split(' ')) {
      if (each.startsWith('$repository=')) return each.substring(repository.length + 1);
    }
    throw StateError('PORELO_WALK_ISSUE_HEADS names no tip of $repository');
  }

  /// When the run started, UTC, as the probe's `records` takes it.
  static String get since => _required('PORELO_WALK_SINCE');

  /// How long a task's agent may work.
  static Duration get taskDeadline =>
      Duration(minutes: int.tryParse(Platform.environment['PORELO_WALK_TASK_MINUTES'] ?? '') ?? 30);

  /// What the discussion's agent is told to end its session.
  static String get quit {
    final said = Platform.environment['PORELO_WALK_AGENT_QUIT'] ?? '';
    return said.isEmpty ? '/quit' : said;
  }

  /// The story's title, told the discussion so the probe can find the story by it.
  static String get title => 'A hello file for $project';

  /// The idea in the person's first words: everything the discussion's brief asks, so its agent need not ask.
  static String get idea => switch (issueRepositories) {
    [final one] =>
      'Title: $title. A user gains a file hello.txt at the top of the repository $one that says hello. The test '
          'that shows it works: hello.txt is in $one and says hello. Priority: Low. It concerns the repository $one '
          'alone, with one issue of size S that an Agent works. I agree with this as written: write it down without '
          'asking further.',
    final several =>
      'Title: $title. A user gains a file hello.txt at the top of each of the repositories ${_named(several)} that '
          'says hello. The test that shows it works: hello.txt is in each of them and says hello. Priority: Low. It '
          'concerns the repositories ${_named(several)}, with one issue of size S in each that an Agent works, each '
          'issue changing only its own repository and waiting on no other. I agree with this as written: write it '
          'down without asking further.',
  };

  static String _named(List<String> names) => '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';

  static String _required(String variable) {
    final value = Platform.environment[variable] ?? '';
    if (value.isEmpty) throw StateError('$variable is not set: run this through tool/walk_idea.sh');
    return value;
  }

  /// The story the idea was saved as, once the probe named it.
  static String? story;

  /// The story's issues as the probe listed them last.
  static List<({String id, String repository, String state})> issues = [];

  /// The containers of the project's tasks before the step that starts one.
  static Set<String> tasksBefore = {};

  /// The discussion's container, once it was seen.
  static String? discussion;

  /// The builders' and the readers' containers, one per issue, once each was seen.
  static List<String> builders = [], readers = [];
}

/// Runs one step of the walk: a picture of the window where it fails, and one line `OK` or `FAIL` in the steps file
/// the driver reads, the failure's words with it.
///
/// A run taken up again from step `PORELO_WALK_FROM` skips the steps before it, step 1 excepted, which opens the
/// planning; what they found is read back from the state file `PORELO_WALK_STATE`, which every step that held writes.
Future<void> walked(WidgetTester tester, String step, Future<void> Function() body) async {
  final number = int.tryParse(step.split(' ').first) ?? 0;
  final from = int.tryParse(Platform.environment['PORELO_WALK_FROM'] ?? '') ?? 1;
  if (!_stateRead) {
    _stateRead = true;
    if (from > 1) _readState();
  }
  if (number > 1 && number < from) {
    noteStep('SKIPPED $step: taken up again from step $from');
    return;
  }
  try {
    await pictured(tester, body);
  } catch (failure) {
    noteStep('FAIL $step: ${'$failure'.replaceAll('\n', ' | ')}');
    rethrow;
  }
  noteStep('OK $step');
  _writeState();
}

bool _stateRead = false;

File? get _stateFile => switch (Platform.environment['PORELO_WALK_STATE'] ?? '') {
  '' => null,
  final path => File(path),
};

void _writeState() => _stateFile?.writeAsStringSync(
  jsonEncode({
    'story': Walk.story,
    'issues': [
      for (final each in Walk.issues) [each.id, each.repository, each.state],
    ],
    'tasksBefore': Walk.tasksBefore.toList(),
    'discussion': Walk.discussion,
    'builders': Walk.builders,
    'readers': Walk.readers,
  }),
  flush: true,
);

void _readState() {
  final file = _stateFile;
  if (file == null || !file.existsSync()) return;
  final state = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  Walk.story = state['story'] as String?;
  Walk.issues = [
    for (final each in (state['issues'] as List? ?? const []).cast<List<dynamic>>())
      (id: each[0] as String, repository: each[1] as String, state: each[2] as String),
  ];
  Walk.tasksBefore = {...(state['tasksBefore'] as List? ?? const []).cast<String>()};
  Walk.discussion = state['discussion'] as String?;
  Walk.builders = [...(state['builders'] as List? ?? const []).cast<String>()];
  Walk.readers = [...(state['readers'] as List? ?? const []).cast<String>()];
}

/// Adds [line] to the steps file the driver reads, where it names one.
void noteStep(String line) {
  final into = Platform.environment['PORELO_WALK_STEPS'] ?? '';
  if (into.isNotEmpty) File(into).writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
}

/// The account's own runtime directory: the test's is one of `tool/e2e.sh`'s own, which porelo does not answer in.
Future<String> theAccountsRuntime() async =>
    _runtime ??= '/run/user/${((await Process.run('id', ['-u'])).stdout as String).trim()}';
String? _runtime;

/// Asks the planner's probe [check] and answers what it printed; a check that does not hold fails the step with what
/// the probe asked and got, and one that cannot run fails it saying so.
Future<String> probe(List<String> check) async {
  final ran = await _probe(check);
  return switch (ran.exitCode) {
    0 => ran.stdout as String,
    1 => fail('the probe did not find ${check.join(' ')}: ${ran.stderr}${ran.stdout}'),
    _ => fail('the probe could not run ${check.join(' ')} (exit ${ran.exitCode}): ${ran.stderr}${ran.stdout}'),
  };
}

/// Whether the probe's [check] holds now: for a wait, which asks again rather than failing.
Future<bool> probeHolds(List<String> check) async => (await _probe(check)).exitCode == 0;

Future<ProcessResult> _probe(List<String> check) async {
  // The window's planner writes its address under the window's runtime directory; porelo answers under the account's.
  final windows = Platform.environment['XDG_RUNTIME_DIR'] ?? '';
  return Process.run(
    Walk.probe,
    check,
    environment: {
      'PLANNER_PROJECT': Walk.project,
      'PORELO_PROJECT': Walk.poreloProject,
      'PLANNER_ADDRESS_FILE': '$windows/porelo-planner/planner.json',
      'XDG_RUNTIME_DIR': await theAccountsRuntime(),
    },
  );
}

/// Runs [script] in the account's login shell, as porelo is reached from a terminal on the machine.
Future<String> inTheAccount(String script) async {
  final ran = await Process.run('bash', ['-lc', script], environment: {'XDG_RUNTIME_DIR': await theAccountsRuntime()});
  if (ran.exitCode != 0) throw StateError('`$script` failed with exit ${ran.exitCode}: ${ran.stderr}');
  return ran.stdout as String;
}

const _listOverTheSocket = r'''python3 -I -c '
import json, os, socket
s = socket.socket(socket.AF_UNIX)
s.connect(os.environ["XDG_RUNTIME_DIR"] + "/porelo/porelod.sock")
s.sendall(json.dumps({"method": "org.fuin.porelo.Tasks1.List"}).encode() + b"\0")
b = b""
while not b.endswith(b"\0"):
    got = s.recv(65536)
    if not got:
        break
    b += got
print(b.rstrip(b"\0").decode())'
''';

/// The project's tasks as porelo on the machine lists them, never as the window shows them.
Future<List<Map<String, dynamic>>> theProjectsTasks() async {
  // `porelo task list` prints no JSON, so the daemon's own List is asked over its socket, as the window asks it.
  final said = await inTheAccount(_listOverTheSocket);
  final Object? listed;
  try {
    listed = jsonDecode(said);
  } on FormatException {
    fail("porelod's List answered no JSON: $said");
  }
  final tasks = switch (listed) {
    {'parameters': {'tasks': final List<dynamic> all}} => all,
    _ => fail("porelod's List answered no list of tasks: $said"),
  };
  return [
    for (final each in tasks.whereType<Map<String, dynamic>>())
      if (each['project'] == Walk.poreloProject) each,
  ];
}

/// A task's container, as porelo names it.
String theContainerOf(Map<String, dynamic> task) => '${task['container'] ?? task['name'] ?? ''}';

/// Whether porelo says the task's agent ended: its end recorded, or the task no longer running.
bool hasEnded(Map<String, dynamic> task) =>
    task['agentEnded'] != null || task['agent_ended'] != null || task['ended'] != null || task['running'] == false;

/// Notes the project's tasks, so [theNewTask] finds only one started after.
Future<void> noteTheTasks() async =>
    Walk.tasksBefore = {for (final each in await theProjectsTasks()) theContainerOf(each)};

/// The task porelo lists that was not there when [noteTheTasks] last noted, once it is: at most [within].
Future<Map<String, dynamic>> theNewTask(
  WidgetTester tester,
  String what, {
  Duration within = const Duration(minutes: 5),
}) async => (await theNewTasks(tester, what, 1, within: within)).single;

/// The [count] tasks porelo lists that were not there when [noteTheTasks] last noted, once there are: at most
/// [within].
Future<List<Map<String, dynamic>>> theNewTasks(
  WidgetTester tester,
  String what,
  int count, {
  Duration within = const Duration(minutes: 5),
}) async {
  var found = <Map<String, dynamic>>[];
  await pumpUntil(
    tester,
    () async {
      found = (await theProjectsTasks()).where((each) => !Walk.tasksBefore.contains(theContainerOf(each))).toList();
      return found.length >= count;
    },
    timeout: within,
    what: 'porelo to list $what of ${Walk.poreloProject}, $count of them',
  );
  found = found.sublist(0, count);
  // The driver's clean-up takes the forge's branches and pull requests of these tasks away.
  final into = Platform.environment['PORELO_WALK_TASKS'] ?? '';
  if (into.isNotEmpty) {
    for (final each in found) {
      File(into)
          .writeAsStringSync('${theContainerOf(each)} ${each['task'] ?? ''}\n', mode: FileMode.append, flush: true);
    }
  }
  return found;
}

/// The issue the task in [container] works, by the repository porelo lists it in; null where no issue is in it.
Future<String?> theIssueOf(String container) async {
  final repository = (await theTask(container))['repository'];
  return Walk.issues.where((issue) => issue.repository == repository).firstOrNull?.id;
}

/// Whether porelo lists [container] no longer.
Future<bool> isGone(String container) async =>
    (await theProjectsTasks()).every((each) => theContainerOf(each) != container);

/// The task in [container] as porelo lists it now; fails where porelo lists it no longer.
Future<Map<String, dynamic>> theTask(String container) async =>
    (await theProjectsTasks()).where((each) => theContainerOf(each) == container).firstOrNull ??
    fail('porelo no longer lists $container');

/// Waits until porelo says the agent in [container] ended, at most [within]; fails at once where the task is gone, and
/// fast where the same failure is read three times in a row (porelo not answering, or the planner raising [issue]).
///
/// With [goneIsEnded], porelo no longer listing it counts as its end: a task that read its whole project is removed
/// when its run ends, and is then answered as an empty record.
Future<Map<String, dynamic>> untilItEnds(
  WidgetTester tester,
  String container, {
  required Duration within,
  String? issue,
  bool goneIsEnded = false,
}) async {
  final by = DateTime.now().add(within);
  String? last;
  var again = 0;
  while (true) {
    String? failure;
    try {
      if (goneIsEnded && await isGone(container)) return const {};
      final task = await theTask(container);
      if (hasEnded(task)) return task;
      if (issue != null && !await probeHolds(['attention', issue, 'NONE'])) {
        failure = 'the planner raises attention on $issue';
      }
    } on StateError catch (error) {
      failure = '$error';
    }
    if (failure != null) {
      again = failure == last ? again + 1 : 1;
      last = failure;
      if (again >= 3) fail('$container did not end, and the same failure came three times: $failure');
    } else {
      again = 0;
      last = null;
    }
    if (DateTime.now().isAfter(by)) fail('$container did not end within ${within.inMinutes} minutes');
    await pumpFor(tester, const Duration(seconds: 20));
  }
}

/// Whether a process of this account runs the planner the driver put on the path.
bool thePathsPlannerRuns() {
  final wanted = File(Walk.planner).resolveSymbolicLinksSync();
  for (final each in Directory('/proc').listSync().whereType<Directory>()) {
    try {
      if (Link('${each.path}/exe').resolveSymbolicLinksSync() == wanted) return true;
    } on FileSystemException {
      // A process gone meanwhile, or another account's.
    }
  }
  return false;
}

/// The terminal of the session the window shows, once it shows one.
Future<Terminal> theSessionsTerminal(WidgetTester tester) async {
  final view = find.byType(TerminalView);
  await pumpUntil(tester, () => view.evaluate().isNotEmpty, timeout: const Duration(minutes: 2), what: 'a session');
  return tester.widget<TerminalView>(view.last).terminal;
}

/// Types [words] into [terminal] and presses Enter, as a person at the keyboard.
Future<void> say(WidgetTester tester, Terminal terminal, String words) async {
  terminal.textInput(words);
  await pumpFor(tester, const Duration(milliseconds: 500));
  terminal.keyInput(TerminalKey.enter);
  await pumpFor(tester);
}

/// Waits until what [terminal] shows has not changed for [quiet]: the agent waits for the person. At most [within].
Future<void> untilQuiet(
  WidgetTester tester,
  Terminal terminal, {
  required Duration quiet,
  required Duration within,
}) async {
  final by = DateTime.now().add(within);
  var shown = _withoutTheStatusLine(terminal);
  var since = DateTime.now();
  while (DateTime.now().difference(since) < quiet) {
    if (DateTime.now().isAfter(by)) fail('the session did not fall quiet within ${within.inMinutes} minutes');
    await pumpFor(tester, const Duration(seconds: 2));
    final now = _withoutTheStatusLine(terminal);
    if (now != shown) {
      shown = now;
      since = DateTime.now();
    }
  }
}

/// What [terminal] shows without its last line: the session's tmux status line, whose clock moves on its own.
String _withoutTheStatusLine(Terminal terminal) {
  final lines = terminal.buffer.getText().split('\n').map((each) => each.trimRight()).toList();
  while (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }
  if (lines.isNotEmpty) lines.removeLast();
  return lines.join('\n');
}

/// The story's issues as the probe lists them, each `<id> <repository> <state> …`, with the state each is in.
Future<List<({String id, String repository, String state})>> theStorysIssues(String story) async => [
  for (final line in (await probe(['issues', story])).split('\n').where((each) => each.trim().isNotEmpty))
    switch (line.trim().split(RegExp(r'\s+'))) {
      [final id, final repository, final state, ...] => (id: id, repository: repository, state: state),
      _ => fail('the probe listed an issue of $story as "$line"'),
    },
];

/// Opens the story's page in the planning place, from its card on the board.
Future<void> toTheStory(WidgetTester tester) async {
  await toThePlace(tester, 'planning');
  final crumb = find.byKey(const Key('planning-crumb 0'));
  if (crumb.evaluate().isNotEmpty) {
    await tester.tap(crumb.first);
    await pumpFor(tester);
  }
  final card = find.byKey(Key('planning-story ${Walk.story}'));
  await pumpUntil(
    tester,
    () => card.evaluate().isNotEmpty,
    timeout: const Duration(minutes: 2),
    what: 'the card of ${Walk.story}',
  );
  await tester.ensureVisible(card.first);
  await tester.tap(card.first);
  await pumpFor(tester);
  await pumpUntil(
    tester,
    () => find.byKey(Key('planning-move ${Walk.issues.first.id}')).evaluate().isNotEmpty,
    timeout: const Duration(minutes: 1),
    what: 'the issues of ${Walk.story}',
  );
}

/// The states a person may move [issue] to, in the board's order, as its menu offers them; the menu is closed again.
Future<List<String>> theMovesOffered(WidgetTester tester, String issue) async {
  await tester.ensureVisible(find.byKey(Key('planning-move $issue')).first);
  await pumpFor(tester);
  await tester.tap(find.byKey(Key('planning-move $issue')).first);
  await pumpFor(tester);
  final prefix = 'planning-move-to $issue ';
  final offered = [
    for (final each
        in find
            .byWidgetPredicate(
              (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith(prefix),
            )
            .evaluate())
      (each.widget.key! as ValueKey<String>).value.substring(prefix.length),
  ];
  await tester.tapAt(Offset.zero);
  await pumpFor(tester);
  return offered;
}

/// Moves [issue] to [state] on the story's page and saves it, as a person does; fails with the board's words where the
/// planner refused it.
Future<void> moveAndSave(WidgetTester tester, String issue, String state) async {
  final move = find.byKey(Key('planning-move $issue'));
  final to = find.byKey(Key('planning-move-to $issue $state'));
  // Right after a saved move the board is drawn again, and a tap on the next issue's menu may land on the old one:
  // the menu is opened again until it offers the move.
  final by = DateTime.now().add(const Duration(minutes: 1));
  // A tap that misses fails here rather than passing on with a warning: the page above the issues grows with a run's
  // sections, and a menu below the window took a pick that never reached it.
  final missedWarns = WidgetController.hitTestWarningShouldBeFatal;
  WidgetController.hitTestWarningShouldBeFatal = true;
  try {
    while (to.evaluate().isEmpty && DateTime.now().isBefore(by)) {
      await pumpUntil(tester, () => move.evaluate().isNotEmpty, what: 'the move menu of $issue');
      await tester.ensureVisible(move.first);
      await pumpFor(tester);
      await tester.tap(move.first);
      await pumpFor(tester);
      if (to.evaluate().isEmpty) await pumpFor(tester, const Duration(seconds: 5));
    }
    await pumpUntil(tester, () => to.evaluate().isNotEmpty, what: 'the move of $issue to $state');
    await tester.tap(to.last);
    await pumpFor(tester);
  } finally {
    WidgetController.hitTestWarningShouldBeFatal = missedWarns;
  }
  final save = find.byKey(const Key('planning-save-moves'));
  await pumpUntil(tester, () => save.evaluate().isNotEmpty, what: 'Save changes');
  await tester.tap(save.first);
  await pumpUntil(
    tester,
    () =>
        find.byKey(const Key('planning-moves-pending')).evaluate().isEmpty ||
        find.byKey(Key('planning-move-problem $issue')).evaluate().isNotEmpty ||
        find.byKey(const Key('planning-move-error')).evaluate().isNotEmpty,
    timeout: const Duration(minutes: 2),
    what: 'the planner to save the move of $issue to $state',
  );
  for (final problem in [Key('planning-move-problem $issue'), const Key('planning-move-error')]) {
    if (find.byKey(problem).evaluate().isNotEmpty) {
      fail('the move of $issue to $state was refused: ${tester.widget<Text>(find.byKey(problem).first).data}');
    }
  }
}

/// The probe's reads that an issue stands in [state] on the board and in its repository's file.
Future<void> theIssueStandsIn(String issue, String repository, String state) async {
  await probe(['issue-state', issue, state]);
  await inTheForge(['store-issue', Walk.urlOf(repository), issue, state]);
}

/// Probes [check], a read of the forge: the planner answers before its push lands, so this asks again for two minutes.
Future<String> inTheForge(List<String> check) async {
  final by = DateTime.now().add(const Duration(minutes: 2));
  while (!await probeHolds(check) && DateTime.now().isBefore(by)) {
    await Future<void>.delayed(const Duration(seconds: 5));
  }
  return probe(check);
}
