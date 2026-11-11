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

  // Harm: an end is reported for another project or task than the one started, or a restart loses what a report needs
  // and so reports an end twice or never.
  test('an offer keeps its provider, project, story, task and what was reported of it, across a restart', () async {
    final store = MemorySettingsStore();
    final settings = await loaded(store);
    await settings.rememberPlanningOffer(
      machine: 'laptop',
      container: 'porelo-demo-st1',
      offer: 'offer-1',
      provider: 'porelo-planner',
      project: 'demo',
      story: 'ST1',
      task: 'main',
      ended: 'an end before the start',
    );

    await settings.planningOfferReported('laptop', 'porelo-demo-st1', started: true);
    await settings.planningOfferReported('laptop', 'porelo-demo-st1', ended: 'the end reported');

    final kept = (await loaded(store)).plannedOffer('laptop', 'porelo-demo-st1')!;
    expect(
      (kept.offer, kept.provider, kept.project, kept.story, kept.task, kept.reportable),
      ('offer-1', 'porelo-planner', 'demo', 'ST1', 'main', true),
    );
    expect(kept.startedReported, isTrue);
    expect(kept.ended, 'the end reported');
  });

  // Harm: an entry an earlier build kept breaks the load or is lost, or is reported with names guessed for it.
  test('an older entry without project and task loads and is kept, but cannot be reported', () async {
    final store = MemorySettingsStore({
      'planningOffers': [
        {'machine': 'laptop', 'container': 'porelo-demo-st1', 'offer': 'offer-1'},
      ],
    });
    final settings = await loaded(store);

    expect(settings.planningOffer('laptop', 'porelo-demo-st1'), 'offer-1');
    expect(settings.plannedOffer('laptop', 'porelo-demo-st1')!.reportable, isFalse);
    await settings.rememberPlanningOffer(machine: 'laptop', container: 'porelo-demo-st2', offer: 'offer-2');

    final again = await loaded(store);
    expect(again.planningOffer('laptop', 'porelo-demo-st1'), 'offer-1', reason: 'a later write keeps it');
    expect(again.plannedOffer('laptop', 'porelo-demo-st1')!.reportable, isFalse);
  });

  // Harm: a follow-up task the planner offered is started twice, after a retry or a restart of the window.
  test('an offer handed to Start stays handed across a restart', () async {
    final store = MemorySettingsStore();
    final settings = await loaded(store);
    expect(settings.planningOfferHanded('offer-1'), isFalse);

    await settings.handPlanningOffer('offer-1');

    final again = await loaded(store);
    expect(again.planningOfferHanded('offer-1'), isTrue);
    expect(again.planningOfferHanded('offer-2'), isFalse);
  });
}
