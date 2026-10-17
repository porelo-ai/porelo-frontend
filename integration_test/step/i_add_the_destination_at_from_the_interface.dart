import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';

/// Usage: I add the destination {'e2e-weather'} at {'https://api.weather.invalid/v1'} from the interface
Future<void> iAddTheDestinationAtFromTheInterface(WidgetTester tester, String name, String upstream) async {
  await openTheDestinations(tester);
  // A form left open by a refusal is typed into again, as a person would.
  if (find.byKey(const Key('add-destination')).evaluate().isNotEmpty) {
    await tester.tap(find.byKey(const Key('add-destination')));
    await pumpUntilShown(tester, const Key('destination-name'));
  }
  await tester.enterText(find.byKey(const Key('destination-name')), name);
  await tester.enterText(find.byKey(const Key('destination-upstream')), upstream);
  await tester.enterText(find.byKey(const Key('destination-prefix')), 'Bearer ');
  await pumpFor(tester);
  await tester.ensureVisible(find.byKey(const Key('check-destination')));
  await tester.tap(find.byKey(const Key('check-destination')));
  // The refusal of an earlier try goes with the press; waited out, so it is not read as this one's.
  await pumpUntil(
    tester,
    () => find.byKey(const Key('destination-refused')).evaluate().isEmpty,
    what: 'the earlier answer to go',
  );
  await pumpUntil(
    tester,
    () =>
        find.byKey(const Key('destination-previewed')).evaluate().isNotEmpty ||
        find.byKey(const Key('destination-refused')).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
    what: 'the machine to check the destination',
  );
  if (find.byKey(const Key('destination-refused')).evaluate().isNotEmpty) return;
  await tester.ensureVisible(find.byKey(const Key('write-destination')));
  await tester.tap(find.byKey(const Key('write-destination')));
  await pumpUntil(
    tester,
    () => find.textContaining('Written: $name').evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
    what: 'the machine to say it wrote $name',
  );
}
