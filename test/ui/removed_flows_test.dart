import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';

import '../features/support/world.dart';

const _removed = [
  'Register the project',
  'Add a developer',
  'Project settings: Developers',
  'Bring it to the host',
  'Choose another registry',
  'Create the registry',
  'Registry publication',
  'Take this project off',
];

Future<void> _find(WidgetTester tester, String words) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await World.settle(tester);
  await tester.enterText(find.byKey(const Key('command-query')), words);
  await World.settle(tester);
}

void main() {
  // Harm: a person who holds every role is still offered a flow that no longer does anything.
  testWidgets('the finder and the project menu offer no removed flow to a person holding every role', (tester) async {
    await World.startBackend(World.work);
    await World.startApp(tester);
    World.fleet.selectProject('checkout');
    World.shell.goTo(Section.project);
    await World.settle(tester);
    await _find(tester, 'Remove this project');
    expect(find.widgetWithText(ListTile, 'Remove this project'), findsOneWidget, reason: 'the finder is asked');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await World.settle(tester);
    for (final words in _removed) {
      await _find(tester, words);
      expect(
        find.descendant(of: find.byType(ListTile), matching: find.textContaining(words)),
        findsNothing,
        reason: words,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await World.settle(tester);
    }
    await World.tapInView(tester, 'project-menu');
    for (final words in _removed) {
      expect(find.textContaining(words), findsNothing, reason: words);
    }
  });

  // Harm: a sentence tells a person to use a flow nothing offers any more.
  test('no text in the interface names a removed flow', () {
    final sources = Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
    for (final source in sources) {
      final text = source.readAsStringSync();
      for (final words in _removed) {
        expect(text, isNot(contains(words)), reason: '${source.path} names $words');
      }
    }
  });
}
