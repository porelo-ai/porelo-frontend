import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';
import 'package:porelo_frontend/src/app/porelo_organization_source.dart';
import 'package:porelo_frontend/src/app/run_here.dart';

Map<String, Object?> _preview() => {
  'repository': 'app',
  'upstream': 'https://forge.example.org/acme/app.git',
  'revision': 'project-before',
  'draft': 'review: required\n',
  'values': [
    {
      'key': 'build',
      'value': 'mvn verify',
      'file': 'pom.xml',
      'line': 7,
      'origin': null,
      'unknown': false,
      'note': 'Check the profile.',
      'plugin': 'maven',
    },
    {
      'key': 'check',
      'value': null,
      'file': null,
      'line': null,
      'origin': 'not detected',
      'unknown': true,
      'note': null,
      'plugin': null,
    },
  ],
  'disagreements': [
    {
      'key': 'build',
      'values': ['mvn verify', 'mvn package'],
    },
  ],
  'unplaced': ['custom setting'],
  'not_placed': ['unsupported setting'],
  'credentials_needed': ['forge access'],
  'plugins': [
    {'name': 'maven', 'state': 'new-state', 'why': 'A reason.'},
  ],
};

void main() {
  late PoreloOrganizationSource source;
  late List<List<String>> calls;
  late Ran result;

  setUp(() {
    calls = [];
    result = (code: 0, out: jsonEncode(_preview()), err: '');
    source = PoreloOrganizationSource(
      run: (program, arguments, {inDirectory, environment = const {}, input}) async {
        expect(program, 'porelo');
        calls.add(arguments);
        return result;
      },
    );
  });

  // Harm: a preview could file unreviewed settings or silently omit conflicting evidence before signing.
  test('preview writes nothing and keeps every warning and origin while allowing added fields', () async {
    result = (
      code: 0,
      out: jsonEncode({
        ..._preview(),
        'future': {'enabled': true},
      }),
      err: '',
    );
    final draft = await source.readProjectInit('/checkouts/app', project: 'demo', name: 'app');
    expect(calls.single, ['project', 'init', '/checkouts/app', '--project', 'demo', '--name', 'app', '--json']);
    expect(draft.revision, 'project-before');
    expect(draft.values.map((value) => (value.key, value.value, value.file, value.line, value.origin, value.unknown)), [
      ('build', 'mvn verify', 'pom.xml', 7, null, false),
      ('check', 'null', null, null, 'not detected', true),
    ]);
    expect(draft.values.first.note, 'Check the profile.');
    expect(draft.values.first.plugin, 'maven');
    expect(draft.disagreements.single.values, contains('mvn package'));
    expect(draft.credentialsNeeded, contains('forge access'));
    expect(draft.plugins.single, (name: 'maven', state: 'new-state', why: 'A reason.'));
    expect(draft.unplaced, contains('custom setting'));
    expect(draft.notPlaced, contains('unsupported setting'));
  });

  // Harm: an unrelated added field could silently make review optional or prevent an admin from repairing it.
  test('an undocumented review field cannot silently establish a policy or break project reads', () async {
    for (final extra in [
      'optional',
      {'state': 'unrelated'},
    ]) {
      result = (code: 0, out: jsonEncode({'project': 'demo', 'revision': 'before', 'review': extra}), err: '');
      final project = await source.readProject('demo');
      expect(project.review, isNull);
    }
  });

  // Harm: every real checkout's draft is refused as unreadable, or a person reads raw JSON. This is Core's answer as the
  // published package gave it for a pom with one property.
  test('the draft as real Core answers it is read and said in words', () async {
    final row = {
      'key': 'maven.version',
      'value': '',
      'file': 'pom.xml',
      'line': 0,
      'origin': 'CHECKOUT',
      'unknown': false,
      'note': 'no version is asked for, so any Maven serves',
      'plugin': 'maven',
    };
    result = (
      code: 0,
      out: jsonEncode({
        ..._preview(),
        'values': [row],
        'disagreements': [
          {
            'key': 'java.version',
            'values': [
              {...row, 'value': '21', 'line': 2},
              {...row, 'value': '17', 'line': 9},
            ],
          },
        ],
        'unplaced': <Object?>[],
        'not_placed': [row],
        'credentials_needed': [
          {'id': 'nexus', 'command': 'porelo vault put nexus'},
        ],
        'plugins': [
          {'state': 'recognized', 'why': '', 'name': 'maven'},
        ],
      }),
      err: '',
    );
    final draft = await source.readProjectInit('/checkout', project: 'demo');
    expect(draft.values.single.line, isNull);
    expect(draft.values.single.file, 'pom.xml');
    expect(draft.plugins.single.why, isNull);
    expect(draft.unplaced, isEmpty);
    expect(draft.notPlaced, 'maven.version · pom.xml · no version is asked for, so any Maven serves · Plugin: maven');
    expect(draft.credentialsNeeded, 'nexus');
    expect(draft.disagreements.single.values, '21 (pom.xml:2) or 17 (pom.xml:9)');
  });

  // Harm: the address given for a machine's own forge never reaches Core, so the file names central.
  test('the local address goes to Core as upstream, in the preview and the filing', () async {
    await source.readProjectInit('/c', project: 'demo', upstream: 'http://127.0.0.1:3001/demo/app.git');
    expect(calls.last, containsAllInOrder(['--upstream', 'http://127.0.0.1:3001/demo/app.git']));
    await source.apply(
      const OrganizationWrite(
        change: OrganizationChange.initializeProject,
        input: {'project': 'demo', 'checkout': '/c', 'upstream': 'http://127.0.0.1:3001/demo/app.git'},
        person: 'pat',
        base: 'b',
        id: 'i',
      ),
    );
    expect(calls.last, containsAllInOrder(['--yes', '--upstream', 'http://127.0.0.1:3001/demo/app.git']));
  });

  // Harm: a partial or malformed draft must never become permission to sign an incomplete project.
  test('malformed drafts and missing project revisions fail closed', () async {
    final bad = <Object?>[
      null,
      [],
      {..._preview()}..remove('revision'),
      {..._preview(), 'revision': ''},
      {..._preview(), 'draft': 7},
      for (final field in ['values', 'disagreements', 'plugins', 'credentials_needed', 'unplaced', 'not_placed'])
        {..._preview()}..remove(field),
      {
        ..._preview(),
        'values': [
          {'key': 'build', 'value': 'run', 'unknown': 'false'},
        ],
      },
      {
        ..._preview(),
        'values': [
          {'key': 'build', 'value': 'run', 'unknown': false, 'line': '7'},
        ],
      },
      {
        ..._preview(),
        'values': [false],
      },
      {
        ..._preview(),
        'disagreements': [
          {'key': 'build', 'values': false},
        ],
      },
      {
        ..._preview(),
        'plugins': [
          {'name': 'maven', 'state': false},
        ],
      },
    ];
    for (final answer in bad) {
      result = (code: 0, out: jsonEncode(answer), err: '');
      await expectLater(source.readProjectInit('/checkouts/app', project: 'demo'), throwsA(isA<OrganizationRefused>()));
    }
    result = (code: 0, out: '{broken', err: 'private diagnostics');
    await expectLater(source.readProjectInit('/checkouts/app', project: 'demo'), throwsA(isA<OrganizationRefused>()));
    expect(calls.every((call) => !call.contains('--yes')), isTrue);
  });

  // Harm: signing against the wrong revision overwrites work; retrying without an ID can file the change twice.
  test('signing sends the reviewed base and ID and only explicit policy choices', () async {
    result = (code: 0, out: '{}', err: '');
    await source.apply(
      const OrganizationWrite(
        change: OrganizationChange.initializeProject,
        input: {'project': 'demo', 'checkout': '/checkouts/app', 'review': 'optional', 'central': 'required'},
        person: 'pat',
        base: 'project-before',
        id: 'same-change',
      ),
    );
    expect(calls.single, [
      'project',
      'init',
      '/checkouts/app',
      '--project',
      'demo',
      '--yes',
      '--review',
      'optional',
      '--central',
      'required',
      '--base',
      'project-before',
      '--id',
      'same-change',
      '--json',
    ]);
  });

  // Harm: a malformed folder could be interpreted as a write option, and a missing base could overwrite later work.
  test('unsafe checkout arguments and missing bases start no process', () async {
    await expectLater(source.readProjectInit('--yes', project: 'demo'), throwsA(isA<OrganizationRefused>()));
    for (final change in [OrganizationChange.initializeProject, OrganizationChange.changeProjectReview]) {
      await expectLater(
        source.apply(
          OrganizationWrite(
            change: change,
            input: const {'project': 'demo', 'checkout': '/checkouts/app', 'review': 'optional'},
            person: 'pat',
            base: '',
            id: 'one',
          ),
        ),
        throwsA(isA<OrganizationRefused>()),
      );
    }
    expect(calls, isEmpty);
  });

  // Harm: changing review on the wrong scope could let work leave a different repository without review.
  test('review and creation choices use the exact project and repository commands', () async {
    result = (code: 0, out: '{}', err: '');
    for (final (change, input, command) in [
      (
        OrganizationChange.openProject,
        {'project': 'demo', 'review': 'optional'},
        ['project', 'open', 'demo', '--review', 'optional'],
      ),
      (
        OrganizationChange.addProjectRepository,
        {'project': 'demo', 'repository': 'app', 'address': 'upstream', 'review': 'optional'},
        ['project', 'repository', 'add', 'demo', 'app', '--upstream', 'upstream', '--review', 'optional'],
      ),
      (
        OrganizationChange.changeProjectReview,
        {'project': 'demo', 'review': 'required'},
        ['project', 'review', 'demo', 'required'],
      ),
      (
        OrganizationChange.changeProjectReview,
        {'project': 'demo', 'repository': 'app', 'review': 'optional'},
        ['project', 'review', 'demo', 'app', 'optional'],
      ),
    ]) {
      await source.apply(OrganizationWrite(change: change, input: input, person: 'pat', base: 'before', id: 'one'));
      expect(calls.last, [...command, '--base', 'before', '--id', 'one', '--json']);
    }
    calls.clear();
    await expectLater(
      source.apply(
        const OrganizationWrite(
          change: OrganizationChange.changeProjectReview,
          input: {'project': 'demo', 'review': '--yes'},
          person: 'pat',
          base: 'before',
          id: 'one',
        ),
      ),
      throwsA(isA<OrganizationRefused>()),
    );
    expect(calls, isEmpty);
  });
}
