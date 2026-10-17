import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/emergency_stop.dart';

import '../features/support/world.dart';

/// A machine that answers what stopping would do only when told to.
class _Slow extends FakeBackend {
  _Slow() : super(const <Task>[]);

  final Completer<void> answer = Completer<void>();

  @override
  Future<Panicked> panic({bool? dryRun}) async {
    await answer.future;
    return super.panic(dryRun: dryRun);
  }
}

void main() {
  test('a dialog put away before the machine answered hears nothing afterwards', () async {
    // "Leave it" on a slow machine disposes the model while its question is still out.
    final machine = _Slow();
    final stop = EmergencyStop();
    final asking = stop.consider(machine);

    stop.dispose();
    machine.answer.complete();

    await expectLater(asking, completes);
  });
}
