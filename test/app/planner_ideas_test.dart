// Linux only: it reads the planner's runtime directory with its POSIX modes, as planner_test.dart does.
@Tags(<String>['linux'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/planner_ideas.dart';
import 'package:porelo_planning/porelo_planning.dart' show PlannerProject;

/// A stand-in planner on the loopback address: what `POST /projects/{project}/ideas` was sent, and what it answers.
class _Planner {
  _Planner._(this.server) {
    server.listen((request) async {
      final body = await utf8.decodeStream(request);
      calls.add((request.method, request.uri.path, request.headers.value(HttpHeaders.authorizationHeader), body));
      if (request.method == 'PUT') given.add(request.uri.path);
      final (status, text) = request.method == 'PUT'
          ? (204, '')
          : given.isEmpty && unknownUntilGiven
          ? (404, jsonEncode({'title': 'NoSuchProject', 'detail': 'The planner was not given project demo'}))
          : answer;
      request.response
        ..statusCode = status
        ..headers.contentType = ContentType.json
        ..write(text);
      await request.response.close();
    });
  }

  static Future<_Planner> start() async => _Planner._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  final HttpServer server;

  /// Each call: its method, its path, its Authorization header and its body.
  final calls = <(String, String, String?, String)>[];

  /// The projects it was given, by path.
  final given = <String>[];

  /// Whether it knows no project until it is given one, as after its start.
  bool unknownUntilGiven = false;

  /// The status and body it answers.
  (int, String) answer = (201, jsonEncode({'id': 'ST42'}));

  /// Writes the address file as the planner does: owner-only, in an owner-only directory.
  Future<void> announce(String runtime) async {
    final directory = await Directory('$runtime/porelo-planner').create(recursive: true);
    await Process.run('chmod', ['700', directory.path]);
    final written = File('${directory.path}/planner.json.new');
    await written.writeAsString(jsonEncode({'port': server.port, 'token': 'token-of-the-test'}));
    await Process.run('chmod', ['600', written.path]);
    await written.rename('${directory.path}/planner.json');
  }
}

void main() {
  const offer = '00000000-0000-4000-8000-00000000d15c';
  const idea = <String, Object?>{
    'story': {'title': 'Night lights', 'gain': 'Less glare.', 'test': 'The lights dim.', 'priority': 3},
    'issues': [
      {'repository': 'porelo', 'title': 'Dim the lights', 'mustBeTrue': 'The lights dim.', 'worker': 'Agent'},
    ],
  };
  late Directory runtime;
  late _Planner planner;

  setUp(() async {
    runtime = await Directory.systemTemp.createTemp('planner-ideas-');
    await Process.run('chmod', ['700', runtime.path]);
    planner = await _Planner.start();
    await planner.announce(runtime.path);
  });

  tearDown(() async {
    await planner.server.close(force: true);
    await runtime.delete(recursive: true);
  });

  // Harm: the idea reaches no planner, reaches it changed or without its offer, or the token goes elsewhere.
  test(
    'an idea goes as POST /projects/{project}/ideas with its offer and the token, and the story comes back',
    () async {
      final story = await handIdea('demo', offer, idea, runtimeDirectory: runtime.path);

      expect(story, 'ST42');
      final (method, path, authorization, body) = planner.calls.single;
      expect((method, path, authorization), ('POST', '/projects/demo/ideas', 'Bearer token-of-the-test'));
      expect(jsonDecode(body), {'offer': offer, 'idea': idea});
    },
  );

  // Harm: an idea that ends after the planner restarted, before the board was read again, is refused for a project
  // the planner was not given, and never reaches it.
  test('a planner not given the project is given it with its repository, and asked once more', () async {
    planner.unknownUntilGiven = true;

    final story = await handIdea(
      'demo',
      offer,
      idea,
      runtimeDirectory: runtime.path,
      projects: (project) => PlannerProject('https://example.org/$project.git'),
    );

    expect(story, 'ST42');
    expect(planner.calls.map((call) => (call.$1, call.$2)), [
      ('POST', '/projects/demo/ideas'),
      ('PUT', '/projects/demo'),
      ('POST', '/projects/demo/ideas'),
    ]);
    expect(jsonDecode(planner.calls[1].$4), {'repository': 'https://example.org/demo.git'});
  });

  // Harm: the person never learns what in their idea the planner refused, or a refusal is tried again forever.
  test('a refused idea names the planner\'s faults, and is no failure to try again', () async {
    planner.answer = (
      422,
      jsonEncode({
        'title': 'IdeaRefused',
        'detail': 'The idea does not follow the idea format.',
        'parameters': {
          'faults': ['story.title: The title must be one line of 1 to 120 characters.'],
        },
      }),
    );

    await expectLater(
      handIdea('demo', offer, idea, runtimeDirectory: runtime.path),
      throwsA(
        isA<IdeaNotSaved>()
            .having((refusal) => refusal.words, 'words', 'The idea does not follow the idea format.')
            .having((refusal) => refusal.faults, 'faults', [
              'story.title: The title must be one line of 1 to 120 characters.',
            ])
            .having((refusal) => refusal.transient, 'transient', isFalse),
      ),
    );
  });

  // Harm: a planner older than ideas, or one that cannot save now, reads as the idea's own fault and it is dropped.
  test('an older planner is said to need a newer one; a planner that cannot save now is tried again', () async {
    planner.answer = (404, '');
    await expectLater(
      handIdea('demo', offer, idea, runtimeDirectory: runtime.path),
      throwsA(isA<IdeaNotSaved>().having((refusal) => refusal.words, 'words', contains('newer planner'))),
    );

    planner.answer = (404, jsonEncode({'title': 'NoSuchProject', 'detail': 'The planner knows no project demo.'}));
    await expectLater(
      handIdea('demo', offer, idea, runtimeDirectory: runtime.path),
      throwsA(isA<IdeaNotSaved>().having((refusal) => refusal.words, 'words', 'The planner knows no project demo.')),
    );

    planner.answer = (503, jsonEncode({'title': 'RecordUnavailable', 'detail': 'The record is not reached.'}));
    await expectLater(
      handIdea('demo', offer, idea, runtimeDirectory: runtime.path),
      throwsA(isA<IdeaNotSaved>().having((refusal) => refusal.transient, 'transient', isTrue)),
    );

    await expectLater(
      handIdea('demo', offer, idea, runtimeDirectory: '${runtime.path}/none'),
      throwsA(isA<IdeaNotSaved>().having((refusal) => refusal.transient, 'transient', isTrue)),
    );
  });

  // Harm: an idea larger than the planner takes is sent all the same and refused without saying why.
  test('an idea larger than the planner takes is not sent', () async {
    final large = {
      ...idea,
      'story': {'title': 'x' * mostIdeaBytes},
    };

    await expectLater(
      handIdea('demo', offer, large, runtimeDirectory: runtime.path),
      throwsA(isA<IdeaNotSaved>().having((refusal) => refusal.words, 'words', contains('64 KiB'))),
    );
    expect(planner.calls, isEmpty);
  });
}
