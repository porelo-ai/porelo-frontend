import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/settings.dart';

void main() {
  Future<Settings> loaded(MemorySettingsStore store) async {
    final settings = Settings(store);
    await settings.load();
    return settings;
  }

  // Harm: an offer the planner gave a started task is lost with a restart, or reported for another machine's task.
  test('an offer is kept beside its machine and container across a restart, and only there', () async {
    final store = MemorySettingsStore();
    final settings = await loaded(store);

    await settings.rememberPlanningOffer(machine: 'laptop', container: 'porelo-demo-st1', offer: 'offer-1');

    final again = await loaded(store);
    expect(again.planningOffer('laptop', 'porelo-demo-st1'), 'offer-1');
    expect(again.planningOffer('host', 'porelo-demo-st1'), isNull, reason: 'another machine started nothing for it');
    expect(again.planningOffer('laptop', 'porelo-demo-st2'), isNull);
  });

  // Harm: the offer of a removed task stays and is reported for a later task of the same container name.
  test('a forgotten offer is gone, also after a restart', () async {
    final store = MemorySettingsStore();
    final settings = await loaded(store);
    await settings.rememberPlanningOffer(machine: 'laptop', container: 'porelo-demo-st1', offer: 'offer-1');
    await settings.rememberPlanningOffer(machine: 'laptop', container: 'porelo-demo-st2', offer: 'offer-2');

    await settings.forgetPlanningOffer('laptop', 'porelo-demo-st1');

    expect(settings.planningOffer('laptop', 'porelo-demo-st1'), isNull);
    final again = await loaded(store);
    expect(again.planningOffer('laptop', 'porelo-demo-st1'), isNull);
    expect(
      again.planningOffer('laptop', 'porelo-demo-st2'),
      'offer-2',
      reason: 'only the removed task loses its offer',
    );
  });

  // Harm: an entry edited by hand or by another build is taken as an offer, or breaks the whole settings load.
  test('an unreadable offer entry is skipped and the readable ones are kept', () async {
    final settings = await loaded(
      MemorySettingsStore({
        'planningOffers': [
          {'machine': 'laptop', 'container': 'porelo-demo-st1', 'offer': 'offer-1'},
          {'machine': 'laptop', 'container': 'porelo-demo-st2', 'offer': 7},
          {'machine': '', 'container': 'porelo-demo-st3', 'offer': 'offer-3'},
          {'machine': 'laptop', 'container': 'porelo-demo-st4', 'offer': 'x' * 201},
          {'machine': 'laptop', 'container': 'porelo-demo\x00st5', 'offer': 'offer-5'},
          'not an entry',
        ],
      }),
    );

    expect(settings.planningOffer('laptop', 'porelo-demo-st1'), 'offer-1');
    for (final (machine, container) in [
      ('laptop', 'porelo-demo-st2'),
      ('', 'porelo-demo-st3'),
      ('laptop', 'porelo-demo-st4'),
      ('laptop', 'porelo-demo\x00st5'),
    ]) {
      expect(settings.planningOffer(machine, container), isNull, reason: '$container is no readable entry');
    }
  });
}
