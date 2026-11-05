import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/host_readiness.dart';

import '../features/support/world.dart';

class _Answering extends FakeBackend {
  _Answering() : super(const <Task>[]);

  final answers = <Completer<Health>>[];

  @override
  Future<Health> doctor() {
    answers.add(Completer<Health>());
    return answers.last.future;
  }
}

Health _health({required bool ready}) => Health(probes: const <Probe>[], ready: ready);

void main() {
  // Harm: the machine first gone to could not be asked, and the last machine's "ready" hides that.
  test('a check that fails leaves no earlier verdict', () async {
    final readiness = HostReadiness();
    final first = FakeBackend(const <Task>[])..theHealthItReports = _health(ready: true);
    await readiness.look(first);
    expect(readiness.ready, isTrue);
    await readiness.look(FakeBackend(const <Task>[])..doctorIsUnsupported = true);
    expect(readiness.ready, isNull);
    expect(readiness.problem, isNotNull);
  });

  // Harm: one machine's late answer is shown under the name of the machine asked after it.
  test('a late answer to an earlier look is not kept', () async {
    final readiness = HostReadiness();
    final backend = _Answering();
    final earlier = readiness.look(backend);
    final later = readiness.look(backend);
    backend.answers[1].complete(_health(ready: false));
    await later;
    backend.answers[0].complete(_health(ready: true));
    await earlier;
    expect(readiness.ready, isFalse);
    expect(readiness.busy, isFalse);
  });

  // Harm: a machine left while it was asked has its verdict shown for the one gone to instead.
  test('forgetting drops the verdict, and an answer still on its way', () async {
    final readiness = HostReadiness();
    final backend = _Answering();
    final asked = readiness.look(backend);
    readiness.forget();
    backend.answers.single.complete(_health(ready: true));
    await asked;
    expect(readiness.ready, isNull);
    expect(readiness.busy, isFalse);
  });
}
