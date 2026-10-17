import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: what porelo doctor found is shown {'podman 4.9.3 is too old'}
Future<void> whatPoreloDoctorFoundIsShown(WidgetTester tester, String line) async {
  expect(find.byKey(const Key('doctor-found')), findsOneWidget);
  final found = tester.widget<SelectableText>(find.byKey(const Key('doctor-found-lines'))).data!;
  expect(found, contains(line));
  expect(found, contains('-> run podman version'), reason: 'the advice under the finding is missing');
  expect(found, isNot(contains('DEGRADED')), reason: 'a finding every fresh machine has was shown as a refusal');
  expect(found, isNot(contains('git ')), reason: 'a line that passed was shown as a refusal');
}
