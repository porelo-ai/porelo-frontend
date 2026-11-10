import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_host/porelo_host.dart' show HostCardSsh;
import 'package:porelo_frontend/src/app/host_pull_requests.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/ui/command_to_copy.dart';

import '../features/support/world.dart';
import '../support/expand_list_rows.dart';

const _key = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

/// The host `elsewhere`, its forge forwarded to this computer at port 3000.
final _host = Machine.fromHostCard(
  HostCardSsh(
    name: 'elsewhere',
    address: 'elsewhere.example.org',
    sshPort: 22,
    hostKey: _key,
    login: 'hana',
    publicKey: _key,
    webPort: 3000,
  ),
  socketPath: '/tmp/elsewhere.sock',
  sshConfig: '/tmp/elsewhere.config',
);

final _foo = Project.from(const <String, dynamic>{
  'name': 'foo',
  'file': '/srv/foo/project.yml',
  'repositories': <Map<String, dynamic>>[
    <String, dynamic>{
      'name': 'foo-1',
      'own': true,
      'upstream': 'http://127.0.0.1:3001/foo/foo-1.git',
      'carriedHere': true,
    },
  ],
});

const _made = HostPullRequest(
  repository: 'foo-1',
  number: 1,
  title: 'Make the parser strict',
  head: '0123456789abcdef0123456789abcdef01234567',
  author: 'Agent Pi <pi@example.org>',
  committer: 'Hana <hana@example.org>',
  trailers: <String>['Assisted-by: Claude Code, claude-opus-5-5'],
  state: 'open',
);

/// One whose makers the machine does not report.
const _unsaid = HostPullRequest(
  repository: 'foo-1',
  number: 2,
  title: 'Say less',
  head: '89abcdef0123456789abcdef0123456789abcdef',
  state: 'open',
);

Finder _row(int number) => find.byKey(ValueKey<String>('attention-row pull request elsewhere/foo/foo-1#$number'));

Future<FakePullRequestWatch> _watched(WidgetTester tester) async {
  final askAgainAfter = HostPullRequests.askAgainAfter;
  HostPullRequests.askAgainAfter = const Duration(seconds: 1);
  addTearDown(() => HostPullRequests.askAgainAfter = askAgainAfter);
  await World.startBackend(World.work);
  await World.startApp(tester);
  World.elsewhere.theProjectsItHas = <Project>[_foo];
  await World.machines.add(_host);
  await World.settle(tester);
  World.shell.goTo(Section.attention);
  await World.settle(tester);
  return World.elsewhere.pullRequestWatches.single;
}

void main() {
  // Harm: a pull request waiting for the person's merge is not said where they look, opens somewhere other than the
  // pull request on the host's forge, or reads as a task's tile with that task's actions on it.
  testWidgets("an open pull request is one row with its one action, opening it on the host's forge", (tester) async {
    final watch = await _watched(tester);
    watch.answer(<HostPullRequest>[_made]);
    await World.settle(tester);

    expect(_row(1), findsOneWidget);
    expect(
      find.descendant(
        of: _row(1),
        matching: find.textContaining('Pull request 1 of foo-1 waits for your approval and merge'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _row(1),
        matching: find.byWidgetPredicate((widget) => '${widget.key}'.startsWith("[<'tile ")),
      ),
      findsNothing,
    );

    World.opened.clear();
    await tester.tap(find.descendant(of: _row(1), matching: find.text('Open the pull request')));
    await World.settle(tester);
    expect(World.opened, <Uri>[Uri.parse('http://elsewhere.localhost:3000/foo/foo-1/pulls/1')]);
  });

  // Harm: the makers of the commit asked to be merged are not seen, or makers the machine never reported read as
  // none, which the trailer check would then pass or fail.
  testWidgets("its row shows the head commit's makers through the trailer check, and says what is not reported", (
    tester,
  ) async {
    final watch = await _watched(tester);
    watch.answer(<HostPullRequest>[_made, _unsaid]);
    await World.settle(tester);
    await expandListRows(tester, within: _row(1));
    await expandListRows(tester, within: _row(2));
    await World.settle(tester);

    for (final said in <String>['Agent Pi <pi@example.org>', 'Hana <hana@example.org>', _made.trailers!.single]) {
      expect(
        find.descendant(of: _row(1), matching: find.text(said)),
        findsOneWidget,
        reason: said,
      );
    }
    expect(
      find.descendant(of: _row(1), matching: find.byKey(const ValueKey<String>('review-trailer-check unknown'))),
      findsOneWidget,
      reason: 'without the whole message a co-author outside the trailer block cannot be ruled out',
    );
    expect(find.descendant(of: _row(2), matching: find.text('not reported by the machine')), findsNWidgets(3));
  });

  // Harm: a missing token or a refused read is said as the daemon's token, or the store command is run from here;
  // and rows a failed watch said are dropped as if their pull requests had ended.
  testWidgets('a refused read is said in words, the store command to copy, and the rows stay as stale', (tester) async {
    final watch = await _watched(tester);
    watch.answer(<HostPullRequest>[_made]);
    await World.settle(tester);
    watch.fail(
      MissingHostForgeToken(
        const VarlinkException('org.fuin.porelo.Tasks1.MissingHostForgeToken', <String, dynamic>{
          'credential': 'forge.person',
          'storeCommand': <String>['porelo', 'host', 'forge-token'],
        }),
      ),
    );
    await World.settle(tester);

    expect(_row(1), findsOneWidget, reason: 'an error never closes a row');
    expect(find.descendant(of: _row(1), matching: find.textContaining('out of date')), findsWidgets);
    final refused = find.byKey(const ValueKey<String>('attention-row pull requests refused elsewhere/foo'));
    expect(refused, findsOneWidget);
    await expandListRows(tester, within: refused);
    await World.settle(tester);
    expect(find.descendant(of: refused, matching: find.textContaining('no forge token of yours')), findsWidgets);
    expect(
      tester.widget<CommandToCopy>(find.descendant(of: refused, matching: find.byType(CommandToCopy))).command,
      'porelo host forge-token',
    );
    expect(find.textContaining('MissingHostForgeToken'), findsNothing);
    expect(World.terminals, isEmpty, reason: 'the store command is shown, never run');

    await tester.pump(const Duration(seconds: 1));
    World.elsewhere.pullRequestWatches.last.fail(
      HostPullRequestsRefused(
        const VarlinkException('org.fuin.porelo.Tasks1.HostPullRequestsRefused', <String, dynamic>{
          'reason': 'vault-unreadable',
          'message': 'the vault is locked or unreadable; unlock or repair it before reading reviews',
        }),
      ),
    );
    await World.settle(tester);
    await expandListRows(tester, within: refused);
    await World.settle(tester);
    expect(find.descendant(of: refused, matching: find.textContaining('locked or cannot be read')), findsWidgets);
    expect(find.textContaining('vault-unreadable'), findsNothing);
    expect(find.descendant(of: refused, matching: find.byType(CommandToCopy)), findsNothing);
  });

  // Harm: a token missing reads as a refusal, or the words send the person to a command that is not shown.
  testWidgets('a missing token with no safe command is labelled as missing, with no command to copy', (tester) async {
    final watch = await _watched(tester);
    watch.fail(
      MissingHostForgeToken(
        const VarlinkException('org.fuin.porelo.Tasks1.MissingHostForgeToken', <String, dynamic>{
          'credential': 'forge.person',
          'storeCommand': <String>['porelo', 'host', 'forge-token\nrm -rf ~'],
        }),
      ),
    );
    await World.settle(tester);

    final refused = find.byKey(const ValueKey<String>('attention-row pull requests refused elsewhere/foo'));
    expect(find.descendant(of: refused, matching: find.text('Forge token missing')), findsWidgets);
    await expandListRows(tester, within: refused);
    await World.settle(tester);
    expect(find.descendant(of: refused, matching: find.byType(CommandToCopy)), findsNothing);
    expect(find.descendant(of: refused, matching: find.textContaining('command below')), findsNothing);
  });
}
