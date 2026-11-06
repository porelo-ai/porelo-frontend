import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/start_work.dart' show CheckoutHere;
import 'package:porelo_frontend/src/ui/default_view.dart';

import '../features/support/world.dart';

void main() {
  const asks = FirstStart(
    outcome: FirstStart.askNew,
    found: <Finding>[
      Finding(what: 'package.maven', value: 'maven', source: 'pom.xml'),
      Finding(what: 'maven.version', source: 'pom.xml'),
      Finding(what: 'setting', value: 'unknown: a wrapper would have to run', source: 'mvnw'),
    ],
    hosts: <String>['repo.maven.apache.org', 'nexus.example'],
    marked: <String>['nexus.example'],
    file: 'project: x-project\n',
    project: 'x-project',
    hash: 'h1',
  );

  late List<String> started;
  late List<String> startedWith;
  late CheckoutHere? startedFrom;
  late List<(String, CheckoutHere?)> startedOn;
  late List<List<String>> gitAsked;

  Future<FakeBackend> open(
    WidgetTester tester,
    FirstStart first, {
    bool thisComputer = true,
    String origin = 'git@forge.example:me/x.git\n',
    int gitCode = 0,
    String? branch = 'feature/x',
    String? picked = '/home/me/x',
  }) async {
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    started = <String>[];
    gitAsked = <List<String>>[];
    startedFrom = null;
    startedOn = <(String, CheckoutHere?)>[];
    final backend = FakeBackend(const <Task>[])..theFirstStartSays = first;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => DefaultDialog(
                  machine: backend,
                  machineName: 'here',
                  thisComputer: thisComputer,
                  onStartWork: (repository, checkout) async => startedOn.add((repository, checkout)),
                  onStartProject: (project, notes, checkout) async {
                    started.add(project);
                    startedWith = notes;
                    startedFrom = checkout;
                  },
                  pickAFolder: ({initialDirectory, title}) async => picked,
                  runGit: (program, arguments, {inDirectory, environment = const <String, String>{}, input}) async {
                    // Detached, symbolic-ref ends with 1 and prints nothing.
                    if (arguments.first == 'symbolic-ref') {
                      // The chosen checkout's branch, never the one this program runs in.
                      if (inDirectory != picked) return (code: 0, out: 'elsewhere\n', err: '');
                      return branch == null ? (code: 1, out: '', err: '') : (code: 0, out: '$branch\n', err: '');
                    }
                    gitAsked.add(<String>[program, ...arguments, inDirectory ?? '']);
                    return (code: gitCode, out: origin, err: '');
                  },
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return backend;
  }

  Future<void> pick(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('default-checkout')));
    await tester.pumpAndSettle();
  }

  String address(WidgetTester tester) =>
      tester.widget<TextField>(find.byKey(const Key('default-address'))).controller!.text;

  // Harm: a plugin failed or a lookup did not answer, and the person says yes to a guess with no word of it.
  testWidgets('the plugins\' notes stand above the question, and a finding\'s note beside it', (tester) async {
    await open(
      tester,
      const FirstStart(
        outcome: FirstStart.askNew,
        notes: <String>['The Maven plugin found no JDK vendor to ask.'],
        found: <Finding>[
          Finding(what: 'package.maven', value: 'maven', source: 'pom.xml', note: 'the distribution\'s package'),
        ],
        project: 'x-project',
        hash: 'h1',
      ),
    );
    await pick(tester);
    final note = find.byKey(const ValueKey<String>('first-start-note 0'));
    expect(tester.widget<SelectableText>(note).data, 'The Maven plugin found no JDK vendor to ask.');
    expect(find.text('package: maven  (pom.xml): the distribution\'s package'), findsOneWidget);
    expect(
      tester.getTopLeft(note).dy,
      lessThan(tester.getTopLeft(find.textContaining('package: maven')).dy),
      reason: 'read before what it speaks of',
    );
  });

  // Harm: a real machine answers several notes, and the question drew an error in place of what it asks.
  testWidgets('several notes, even the same one twice, all stand in both places', (tester) async {
    const notes = <String>['one note', 'another note', 'one note'];
    await open(tester, const FirstStart(outcome: FirstStart.askNew, notes: notes, project: 'x', hash: 'h'));
    await pick(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('another note'), findsOneWidget);
    expect(find.text('one note'), findsNWidgets(2));
    await tester.tap(find.byKey(const Key('first-start-no')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await open(tester, const FirstStart(outcome: 'NO_PLUGIN', notes: notes));
    await pick(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('another note'), findsOneWidget);
    expect(find.text('one note'), findsNWidgets(2));
  });

  // Harm: `NOTHING_RECOGNIZED` hides that the plugin that would have recognized it failed.
  testWidgets('an answer that asks nothing shows its notes too', (tester) async {
    await open(
      tester,
      const FirstStart(outcome: 'NOTHING_RECOGNIZED', notes: <String>['The Maven plugin ended with 1.']),
    );
    await pick(tester);
    expect(find.byKey(const Key('first-start')), findsNothing);
    final note = find.byKey(const ValueKey<String>('default-note 0'));
    expect(tester.widget<SelectableText>(note).data, 'The Maven plugin ended with 1.');
  });

  testWidgets('a known checkout hands its notes to where the work starts', (tester) async {
    await open(tester, const FirstStart(outcome: FirstStart.known, project: 'x', notes: <String>['a note']));
    await pick(tester);
    expect(startedWith, <String>['a note']);
  });

  test('an answer from a Porelo without notes reads as having none', () {
    final said = FirstStart.from(const <String, dynamic>{
      'outcome': 'ASK_NEW',
      'found': <Map<String, dynamic>>[
        <String, dynamic>{'what': 'w', 'value': 'v', 'source': 's'},
      ],
    });
    expect(said.notes, isEmpty);
    expect(said.found.single.note, isEmpty);
    final withThem = FirstStart.from(const <String, dynamic>{
      'outcome': 'ASK_NEW',
      'notes': <String>['n'],
      'found': <Map<String, dynamic>>[
        <String, dynamic>{'what': 'w', 'value': 'v', 'source': 's', 'note': 'm'},
      ],
    });
    expect(withThem.notes, <String>['n']);
    expect(withThem.found.single.note, 'm');
  });

  // Harm: a repository's file opens the network with nobody having said yes to its text.
  testWidgets('a yes names the hash of what was shown, and work starts in its project', (tester) async {
    final backend = await open(tester, asks);
    await pick(tester);
    expect(backend.firstStartsAsked, <String>['/home/me/x']);
    expect(backend.firstStartsConfirmed, isEmpty);
    expect(find.textContaining('package: maven'), findsOneWidget);
    expect(find.text('maven.version  (pom.xml)'), findsOneWidget);
    expect(find.textContaining('could not be read: a wrapper would have to run'), findsOneWidget);
    expect(find.textContaining('repo.maven.apache.org'), findsOneWidget);
    expect(find.textContaining('project: x-project'), findsOneWidget);
    await tester.tap(find.byKey(const Key('first-start-yes')));
    await tester.pumpAndSettle();
    expect(backend.firstStartsConfirmed, <(String, String)>[('/home/me/x', 'h1')]);
    expect(started, <String>['x-project']);
    expect(find.byKey(const Key('default-dialog')), findsNothing);
  });

  // Harm: a No that kept something, or started something else, would not be a no.
  testWidgets('a no calls nothing, leaves the start as it is, and the next start asks again', (tester) async {
    final backend = await open(tester, asks);
    await pick(tester);
    await tester.tap(find.byKey(const Key('first-start-no')));
    await tester.pumpAndSettle();
    expect(backend.firstStartsConfirmed, isEmpty);
    expect(started, isEmpty);
    expect(address(tester), 'git@forge.example:me/x.git');
    expect(gitAsked.single, <String>['git', 'remote', 'get-url', 'origin', '/home/me/x']);
    expect(find.textContaining('asks again'), findsOneWidget);
    await pick(tester);
    expect(find.byKey(const Key('first-start')), findsOneWidget);
    expect(backend.firstStartsAsked, hasLength(2));
  });

  // Harm: Enter on a repository's own host opens it.
  testWidgets('a host only the checkout names is marked, and a yes is then not the default', (tester) async {
    await open(tester, asks);
    await pick(tester);
    expect(find.byKey(const ValueKey<String>('first-start-marked nexus.example')), findsOneWidget);
    expect(tester.widget<TextButton>(find.byKey(const Key('first-start-no'))).autofocus, isTrue);
    expect(tester.widget<FilledButton>(find.byKey(const Key('first-start-yes'))).autofocus, isFalse);
  });

  testWidgets('with nothing marked a yes is the default', (tester) async {
    await open(tester, const FirstStart(outcome: FirstStart.askUnknownFile, project: 'x-project', hash: 'h2'));
    await pick(tester);
    expect(tester.widget<FilledButton>(find.byKey(const Key('first-start-yes'))).autofocus, isTrue);
  });

  testWidgets('a known checkout asks nothing and starts in its project', (tester) async {
    final backend = await open(tester, const FirstStart(outcome: FirstStart.known, project: 'x-project'));
    await pick(tester);
    expect(find.byKey(const Key('first-start')), findsNothing);
    expect(backend.firstStartsConfirmed, isEmpty);
    expect(started, <String>['x-project']);
  });

  // Harm: the machine cannot see this checkout, so without its branch work starts from another one.
  testWidgets('a project a checkout names starts with the branch that checkout is on', (tester) async {
    await open(tester, const FirstStart(outcome: FirstStart.known, project: 'x-project'));
    await pick(tester);
    expect(started, <String>['x-project']);
    expect(startedFrom?.branch, 'feature/x');
    expect(startedFrom?.origin, 'git@forge.example:me/x.git');
    expect(startedFrom?.path, '/home/me/x', reason: 'a file may name the folder where there is no origin');
    expect(startedFrom?.namedTheProject, isTrue, reason: 'the project is the one this checkout named');
  });

  testWidgets('a detached checkout names no branch, and the machine decides', (tester) async {
    await open(tester, const FirstStart(outcome: FirstStart.known, project: 'x-project'), branch: null);
    await pick(tester);
    expect(started, <String>['x-project']);
    expect(startedFrom?.branch, isNull);
  });

  testWidgets('a checkout started in default goes with the repository it is the origin of', (tester) async {
    await open(tester, const FirstStart(outcome: 'NOTHING_RECOGNIZED'));
    await pick(tester);
    await tester.tap(find.byKey(const Key('default-start-new')));
    await tester.pumpAndSettle();
    final (repository, checkout) = startedOn.single;
    expect(checkout?.branch, 'feature/x');
    expect(checkout?.repository, repository);
  });

  // Harm: another repository typed over the checkout's address would start from a branch of the checkout's.
  testWidgets('an address typed over the checkout\'s starts with no branch of it', (tester) async {
    await open(tester, const FirstStart(outcome: 'NOTHING_RECOGNIZED'));
    await pick(tester);
    await tester.enterText(find.byKey(const Key('default-address')), 'git@forge.example:me/other.git');
    await tester.pump();
    await tester.tap(find.byKey(const Key('default-start-new')));
    await tester.pumpAndSettle();
    expect(startedOn.single.$2, isNull);
  });

  testWidgets('a repository of an organization\'s project has no question', (tester) async {
    await open(tester, const FirstStart(outcome: FirstStart.notDefault, project: 'theirs'));
    await pick(tester);
    expect(find.byKey(const Key('first-start')), findsNothing);
    expect(started, <String>['theirs']);
  });

  for (final outcome in const <String>['NO_PLUGIN', 'NOTHING_RECOGNIZED']) {
    testWidgets('$outcome starts as today and says so', (tester) async {
      await open(tester, FirstStart(outcome: outcome));
      await pick(tester);
      expect(find.byKey(const Key('first-start')), findsNothing);
      expect(find.byKey(const Key('default-said')), findsOneWidget);
      expect(address(tester), 'git@forge.example:me/x.git');
      expect(started, isEmpty);
    });
  }

  // Harm: the person's own file is not used, the start goes on in Default, and it passes as one more line.
  testWidgets('a file that is not taken is a warning, with its reason, and asks nothing', (tester) async {
    final backend = await open(
      tester,
      const FirstStart(
        outcome: FirstStart.askUnknownFile,
        refusal: 'project.name must differ from the repository, such as x-project.',
      ),
    );
    await pick(tester);
    expect(find.byKey(const Key('first-start')), findsNothing);
    expect(backend.firstStartsConfirmed, isEmpty);
    final said = tester.widget<Text>(find.byKey(const Key('default-problem')));
    expect(said.data, contains('project.name must differ from the repository, such as x-project.'));
    expect(said.data, contains('in Default, not that file'));
    expect(said.style?.color, Theme.of(tester.element(find.byKey(const Key('default-problem')))).colorScheme.error);
    expect(address(tester), 'git@forge.example:me/x.git');
  });

  // Harm: a plugin that failed on the same checkout goes unsaid, as no question opens to hold its words.
  testWidgets('a file not taken keeps what the plugins say', (tester) async {
    await open(
      tester,
      const FirstStart(
        outcome: FirstStart.askUnknownFile,
        refusal: 'It does not read.',
        notes: <String>['The Maven plugin ended with 1.'],
      ),
    );
    await pick(tester);
    expect(find.byKey(const Key('default-problem')), findsOneWidget);
    expect(find.text('The Maven plugin ended with 1.'), findsOneWidget);
  });

  // Harm: a checkout that moved on is blamed on a file, and the person goes looking for a fault it does not have.
  testWidgets('a refusal that is no fault of a file does not say a file was not used', (tester) async {
    final backend = await open(
      tester,
      const FirstStart(outcome: FirstStart.askNew, file: 'project: {}', project: 'x-project', hash: 'abc'),
    );
    backend.confirmFails = const VarlinkException('org.fuin.porelo.Tasks1.FirstStartRefused', <String, dynamic>{
      'reason': 'MOVED_ON',
      'detail': 'the file is not what that hash named',
    });
    await pick(tester);
    await tester.tap(find.byKey(const Key('first-start-yes')));
    await tester.pumpAndSettle();
    final said = tester.widget<Text>(find.byKey(const Key('default-problem')));
    expect(said.data, 'the file is not what that hash named');
  });

  // Harm: an older Porelo answers the same with no reason, as `67261bbc` does, and that must warn too.
  testWidgets('a file not taken with no reason given warns, and says where the reason is', (tester) async {
    await open(tester, const FirstStart(outcome: FirstStart.askUnknownFile));
    await pick(tester);
    expect(find.byKey(const Key('first-start')), findsNothing);
    final said = tester.widget<Text>(find.byKey(const Key('default-problem')));
    expect(said.data, contains('was not taken'));
    expect(said.data, contains('in a terminal'));
    expect(find.byKey(const Key('default-said')), findsNothing);
  });

  // Harm: the person pressed yes, nothing happened, and nothing said why.
  testWidgets('a refused yes says the machine\'s words and leaves the start as it is', (tester) async {
    final backend = await open(tester, asks);
    backend.confirmFails = const VarlinkException('org.fuin.porelo.Tasks1.FirstStartRefused', <String, dynamic>{
      'reason': 'NAME_TAKEN',
      'detail': 'x-project is another project of this machine.',
    });
    await pick(tester);
    await tester.tap(find.byKey(const Key('first-start-yes')));
    await tester.pumpAndSettle();
    final said = tester.widget<Text>(find.byKey(const Key('default-problem')));
    expect(said.data, contains('x-project is another project of this machine.'));
    expect(said.data, contains('in Default, not that file'));
    expect(started, isEmpty);
    expect(address(tester), 'git@forge.example:me/x.git');
  });

  testWidgets('a checkout with no origin says so', (tester) async {
    await open(tester, const FirstStart(outcome: 'NOTHING_RECOGNIZED'), gitCode: 2, origin: '');
    await pick(tester);
    expect(find.textContaining('names no origin'), findsOneWidget);
  });

  testWidgets('putting the folder dialog away asks nothing', (tester) async {
    final backend = await open(tester, asks, picked: null);
    await pick(tester);
    expect(backend.firstStartsAsked, isEmpty);
  });

  // Harm: a path of this computer sent to another machine, whose plugin runs nowhere.
  testWidgets('on another machine there is no question, and the window says what holds', (tester) async {
    await open(tester, asks, thisComputer: false);
    expect(find.byKey(const Key('default-checkout')), findsNothing);
    expect(find.byKey(const Key('default-nothing-detected')), findsOneWidget);
  });
}
