import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/idea_walk.dart';
import '../support/story_play.dart';

/// The host the work reaches for: reserved for examples, and not among those the stub declares.
const undeclared = 'example.org';

/// Usage: the work reaches a host its project did not declare
///
/// Reached from inside the work's container, as its agent would: porelo blocks it and asks a person, and the question
/// lapses unanswered after a minute.
Future<void> theWorkReachesAHostItsProjectDidNotDeclare(WidgetTester tester) =>
    played(tester, '12 the work reaches $undeclared, which its project did not declare', () async {
      final container = Played.container ?? fail('no work was started');
      Played.reach = await Process.start(
        'podman',
        [
          'exec',
          container,
          'sh',
          '-c',
          'if command -v curl >/dev/null 2>&1; then exec curl -s -o /dev/null --max-time 50 https://$undeclared/; fi; '
              'exec timeout 50 bash -c "exec 3<>/dev/tcp/$undeclared/443"',
        ],
        environment: {'XDG_RUNTIME_DIR': await theAccountsRuntime()},
      );
      addTearDown(() => Played.reach?.kill());
      Map<String, dynamic>? work;
      await until(
        tester,
        () async {
          work = await theWork();
          return '${work?['waitingFor'] ?? ''}'.isNotEmpty;
        },
        within: const Duration(seconds: 45),
        asked: () =>
            'asked for porelo to list $container waiting for a clearance question; it listed '
            'waitingFor "${work?['waitingFor'] ?? ''}", activity ${work?['activity']}',
      );
    }, goesOn: true);
