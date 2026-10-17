import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/host_readiness_view.dart';
import 'package:porelo_frontend/src/ui/tokens.dart';

/// Each check a machine reports is drawn as `porelo doctor` colours it on a terminal, with a shape of
/// its own so it reads without colour too.
void main() {
  final scheme = ColorScheme.fromSeed(seedColor: Colors.indigo);

  test('OK is green, MISSING red, DEGRADED and UNKNOWN yellow', () {
    expect(probeLook('OK', scheme).$2, StateColours.working);
    expect(probeLook('MISSING', scheme).$2, scheme.error);
    expect(probeLook('DEGRADED', scheme).$2, StateColours.waiting);
    expect(probeLook('UNKNOWN', scheme).$2, StateColours.waiting);
  });

  test('a state this build does not know never draws as the good case', () {
    expect(probeLook('SOMETHING-NEW', scheme), isNot(probeLook('OK', scheme)));
  });

  test('each state has a shape of its own, so it reads without colour', () {
    final shapes = <IconData>{for (final state in <String>['OK', 'MISSING', 'DEGRADED', 'UNKNOWN']) probeLook(state, scheme).$1};
    expect(shapes, hasLength(4));
  });
}
