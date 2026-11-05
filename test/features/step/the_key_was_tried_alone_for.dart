import 'package:flutter_test/flutter_test.dart';

import '../support/world.dart';

/// Usage: the key {'SHA256:personalKeyOfThePerson'} was tried alone for {'refs/porelo/incoming/migrate:refs/heads/fix-rounding'}
Future<void> theKeyWasTriedAloneFor(WidgetTester tester, String key, String refspec) async {
  final tried = World.backend.keysTried.single;
  expect(tried.id, key);
  expect(tried.source, 'AGENT');
  expect(tried.refspec, refspec);
}
