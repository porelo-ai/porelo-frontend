import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';

void main() {
  // Measured on Porelo 213: Start raises NoSuchDestination before anything exists, naming the entry.
  test("Start's refusal of a credential nobody can reach is said in words, naming the entry", () async {
    final refused = Stream<StartProgress>.error(
      const VarlinkException('org.fuin.porelo.Tasks1.NoSuchDestination', <String, dynamic>{'name': 'f56-extra'}),
    ).transform(startRefusalsSaid);
    await expectLater(
      refused,
      emitsError(
        isA<NoSuchDestination>().having(
          (it) => '$it',
          'words',
          contains('The credential f56-extra is for a destination this machine does not declare. Nothing was started'),
        ),
      ),
    );
  });

  // Porelo's Start answers this by name when the task's earlier work still waits at the gate.
  test("Start's refusal while earlier work waits is said in words, naming the work", () async {
    final refused = Stream<StartProgress>.error(
      const VarlinkException('org.fuin.porelo.Tasks1.EarlierWorkWaits', <String, dynamic>{
        'task': 'migrate',
        'commit': '9a3c1f2b8e7d6c5a4f3e2d1c0b9a8f7e6d5c4b3a',
        'subject': 'Round to the nearest penny, not away from zero',
      }),
    ).transform(startRefusalsSaid);
    await expectLater(
      refused,
      emitsError(
        isA<EarlierWorkWaits>().having(
          (it) => '$it',
          'words',
          allOf(
            contains('migrate was not started'),
            contains('9a3c1f2 "Round to the nearest penny, not away from zero" still waits at the gate'),
            contains('Forward it or drop it there, then start again'),
          ),
        ),
      ),
    );
  });

  test('any other error passes as it came', () async {
    const other = VarlinkException('org.fuin.porelo.Tasks1.NoSuchProject', <String, dynamic>{});
    final passed = Stream<StartProgress>.error(other).transform(startRefusalsSaid);
    await expectLater(passed, emitsError(same(other)));
  });
}
