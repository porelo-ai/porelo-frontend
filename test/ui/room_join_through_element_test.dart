import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/conversation.dart';
import 'package:porelo_frontend/src/app/desk.dart';
import 'package:porelo_frontend/src/app/element_desktop.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/ui/messages_view.dart';
import 'package:porelo_host/porelo_host.dart';

import '../features/support/world.dart';
import '../support/organization_fixtures.dart';

const _key = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

final _host = Machine.fromHostCard(
  HostCardSsh(
    name: 'alpha',
    address: 'alpha.example.org',
    sshPort: 22,
    hostKey: _key,
    login: 'alice',
    publicKey: _key,
    webPort: 18080,
    gitPort: 18081,
    matrixPort: 18082,
  ),
  socketPath: '/run/person/daemon.sock',
);

/// A host carrying the organization's project `demo` and running no homeserver, as `build` in the fixture.
final _build = Machine.fromHostCard(
  HostCardSsh(
    name: 'build',
    address: '203.0.113.7',
    sshPort: 22,
    hostKey: _key,
    login: 'mia',
    publicKey: _key,
    webPort: 8081,
    gitPort: 8082,
  ),
  socketPath: '/run/person/daemon.sock',
);

const _laptop = Machine(name: 'local', socketPath: '/unused');

final _today = DateTime.utc(2026, 11, 8);

class _Element implements ElementDesktop {
  _Element({required this.there, this.refusal});

  final bool there;
  final Exception? refusal;
  final opened = <({String homeserver, String? profile})>[];

  @override
  Future<bool> installed() async => there;

  @override
  Future<void> open({required String homeserver, String? profile}) async {
    if (refusal case final refused?) throw refused;
    opened.add((homeserver: homeserver, profile: profile));
  }
}

class _Backend extends FakeBackend {
  _Backend() : super([]);
}

Future<ProjectConversation> _open(
  WidgetTester tester, {
  required Machine machine,
  ElementDesktop? element,
  RoomAdmission Function()? admission,
  String project = 'demo',
  List<MessageMember> members = const [],
  FakeBackend? backend,
}) async {
  final asked = (backend ?? _Backend())..membersOf[project] = members.toList();
  final model = ProjectConversation(
    asked,
    machine,
    Project.from({'name': project}),
    settings: Settings(MemorySettingsStore()),
    admission: admission,
  );
  addTearDown(model.dispose);
  await model.load();
  await tester.pumpWidget(
    MaterialApp(
      home: MessagesDialog(conversation: model, element: element),
    ),
  );
  await tester.pumpAndSettle();
  return model;
}

void main() {
  // Harm: on a host a join can only end in the transport's refusal, since the homeserver manages its people itself.
  testWidgets('on a host with Element the room is joined by opening Element signed in to the host', (tester) async {
    final element = _Element(there: true);
    await _open(
      tester,
      machine: _host,
      element: element,
      members: const [MessageMember(person: 'Agent Pi', user: '@porelo-pi:alpha')],
    );
    expect(find.byKey(const Key('join-person')), findsNothing, reason: 'no name field on a host');
    expect(find.byKey(const Key('join-login')), findsNothing);
    expect(find.byKey(const Key('join-it')), findsNothing, reason: 'no join that ends in a refusal');
    expect(find.byKey(const Key('install-element')), findsNothing);
    final separate = tester.widget<CheckboxListTile>(find.byKey(const Key('element-separate-instance')));
    expect(separate.value, isTrue, reason: 'a separate instance keeps an open Element as it is');
    await tester.tap(find.byKey(const Key('open-element-signed-in')));
    await tester.pumpAndSettle();
    expect(element.opened, [(homeserver: 'http://alpha.localhost:18082/', profile: 'alpha')]);
    await tester.tap(find.byKey(const Key('element-separate-instance')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-element-signed-in')));
    await tester.pumpAndSettle();
    expect(element.opened.last, (homeserver: 'http://alpha.localhost:18082/', profile: null));
  });

  // Harm: a start that fails without a word leaves the person waiting for an Element that never comes.
  testWidgets('an Element that could not be started says why', (tester) async {
    await _open(
      tester,
      machine: _host,
      element: _Element(there: true, refusal: const ProcessException('element-desktop', [], 'No such file')),
    );
    await tester.tap(find.byKey(const Key('open-element-signed-in')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Element could not be started: '), findsOneWidget);
    expect(find.textContaining('No such file'), findsOneWidget);
  });

  // Harm: a Remove beside a person the host's homeserver manages offers what only the host can do.
  testWidgets('on a host who is in the room reads by name alone', (tester) async {
    await _open(
      tester,
      machine: _host,
      element: _Element(there: true),
      members: const [MessageMember(person: 'Agent Pi', user: '@porelo-pi:alpha')],
    );
    expect(find.byKey(const ValueKey<String>('member-chip Agent Pi')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('member-remove Agent Pi')), findsNothing);
  });

  // Harm: without Element a person is left with no way in to the host's room.
  testWidgets('on a host without Element it offers to install it and says the way by hand', (tester) async {
    final previousDesk = desk;
    final opened = <List<String>>[];
    desk = Desk.of('linux', const {}, startDetached: (program, arguments) async => opened.add([program, ...arguments]));
    addTearDown(() => desk = previousDesk);
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await _open(tester, machine: _host, element: _Element(there: false));
    expect(find.byKey(const Key('open-element-signed-in')), findsNothing);
    expect(find.byKey(const Key('join-person')), findsNothing);
    expect(find.byKey(const Key('join-it')), findsNothing);
    await tester.tap(find.byKey(const Key('install-element')));
    await tester.tap(find.byKey(const Key('copy-homeserver')));
    await tester.pumpAndSettle();
    expect(opened, [
      ['xdg-open', 'https://element.io/download'],
    ]);
    expect(copied, ['http://alpha.localhost:18082/']);
  });

  // Harm: a free field prefilled with a name the room refuses invites a join that can only fail.
  testWidgets('elsewhere the join offers only the logins the room admits', (tester) async {
    final backend = _Backend();
    final view = organizationFor('mia');
    await _open(
      tester,
      machine: _build,
      backend: backend,
      admission: () => roomAdmission('demo', machine: _build, organizationRead: true, view: view, today: _today),
    );
    expect(find.byKey(const Key('join-person')), findsNothing, reason: 'no free field');
    expect(find.byKey(const Key('join-login')), findsOneWidget);
    await tester.tap(find.byKey(const Key('join-login')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('join-login pat')), findsWidgets);
    expect(find.byKey(const ValueKey<String>('join-login mia')), findsWidgets);
    expect(find.byKey(const ValueKey<String>('join-login rex')), findsNothing, reason: 'a revoked card holds nothing');
    expect(find.byKey(const ValueKey<String>('join-login olive')), findsNothing, reason: 'not in the project');
    await tester.tap(find.text('pat').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('join-it')));
    await tester.pumpAndSettle();
    expect(backend.joins, [(project: 'demo', person: 'pat', reset: false)]);
  });

  // Harm: an organization's project nobody holds a current key in must not read as one anybody may join.
  testWidgets('a room that admits nobody says so and offers no join', (tester) async {
    final view = organizationFor('mia');
    await _open(
      tester,
      machine: _build,
      admission: () => roomAdmission(
        'demo',
        machine: _build,
        organizationRead: true,
        view: organizationFor('mia', persons: const []),
        today: _today,
      ),
    );
    expect(view.projects.any((each) => each.name == 'demo'), isTrue);
    expect(find.byKey(const Key('join-person')), findsNothing);
    expect(find.byKey(const Key('join-login')), findsNothing);
    expect(find.byKey(const Key('join-nobody-admitted')), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('join-it'))).onPressed, isNull);
  });

  // Harm: an organization not read yet must not read as a room that takes any name.
  testWidgets('an organization not read yet is said, beside the free field', (tester) async {
    await _open(
      tester,
      machine: _build,
      admission: () => roomAdmission('demo', machine: _build, organizationRead: false),
    );
    expect(find.byKey(const Key('join-person')), findsOneWidget);
    expect(find.byKey(const Key('join-admission-unread')), findsOneWidget);
  });

  // Harm: a read that failed must not read as one still to come, or its reason is lost.
  testWidgets('an organization that could not be read says so, with why', (tester) async {
    await _open(
      tester,
      machine: _build,
      admission: () => roomAdmission('demo', machine: _build, organizationRead: false, problem: 'the store is gone'),
    );
    expect(find.byKey(const Key('join-person')), findsOneWidget);
    expect(find.byKey(const Key('join-admission-unread')), findsNothing);
    expect(find.textContaining('The organization could not be read: the store is gone'), findsOneWidget);
  });

  // Harm: the organization's list applied to a project of the same name on a machine that does not carry it.
  testWidgets('a same-named project on a machine not carrying the organization’s keeps the free field', (tester) async {
    await _open(
      tester,
      machine: _laptop,
      admission: () =>
          roomAdmission('demo', machine: _laptop, organizationRead: true, view: organizationFor('mia'), today: _today),
    );
    expect(find.byKey(const Key('join-person')), findsOneWidget);
    expect(find.byKey(const Key('join-login')), findsNothing);
  });

  test('who a room admits follows the organization', () {
    final view = organizationFor('mia');
    RoomAdmission on(Machine machine, String project, {OrganizationView? of, bool read = true}) =>
        roomAdmission(project, machine: machine, organizationRead: read, view: of, today: _today);
    expect(on(_build, 'demo', of: view), isA<AdmittedLogins>());
    expect((on(_build, 'demo', of: view) as AdmittedLogins).logins, [
      'mia',
      'pat',
    ], reason: 'the asking person’s own login first');
    expect(
      on(_build, 'own', of: view),
      isA<AnyName>(),
      reason: 'a project the organization does not list is the machine’s own, which takes any name',
    );
    expect(on(_build, 'demo'), isA<AnyName>(), reason: 'no organization');
    expect(on(_build, 'demo', read: false), isA<AdmissionUnread>());
    expect(on(_laptop, 'demo', of: view), isA<AnyName>(), reason: 'the laptop does not carry the organization’s demo');
  });

  // Harm: a card run out has no current key, and the machine refuses its login.
  test('a member whose card has run out is not offered', () {
    final view = organizationFor(
      'mia',
      persons: const [
        OrganizationPerson(login: 'pat', key: 'SHA256:pat', standing: CardStanding.trusted, expires: '2026-11-07'),
        OrganizationPerson(login: 'mia', key: 'SHA256:mia', standing: CardStanding.trusted, expires: '2026-11-08'),
      ],
    );
    final admitted = roomAdmission('demo', machine: _build, organizationRead: true, view: view, today: _today);
    expect((admitted as AdmittedLogins).logins, ['mia'], reason: 'a card is current through the day it names');
  });
}
