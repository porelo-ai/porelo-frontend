import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/ui/tile_console.dart';

import '../features/support/world.dart';

/// A machine slow to show a session's screen.
class _SlowScreens extends FakeBackend {
  _SlowScreens() : super(const <Task>[]);

  int asked = 0;

  @override
  Future<Screen> screen(String task, {required int last, bool escapes = false}) {
    asked++;
    return Completer<Screen>().future;
  }
}

/// A work tile's look at the session's screen, every few seconds.
///
/// The harm: a machine slower to answer than the look's period got a second, third and tenth call
/// queued behind the first, on the one connection the person's own actions go through.
void main() {
  testWidgets('a look at the screen not answered yet is not asked again beside itself', (tester) async {
    final backend = _SlowScreens();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TileConsole(backend: backend, task: 'porelo-checkout-shell', onEnlarge: () {}, inATerminal: true),
        ),
      ),
    );

    await tester.pump(TileConsole.drawnEvery * 10);

    expect(backend.asked, 1);
    await tester.pumpWidget(const SizedBox());
  });
}
