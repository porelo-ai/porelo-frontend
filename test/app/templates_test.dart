import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/settings.dart';
import 'package:porelo_frontend/src/app/templates.dart';

/// A template is a convenience, and a convenience that can quietly widen what work may reach is
/// not one. That is the part with teeth, and it is what most of this file is about.
void main() {
  Templates templatesOn(MemorySettingsStore store) => Templates(Settings(store));

  const nightly = Template(
    name: 'nightly-tests',
    project: 'checkout',
    agent: 'an-agent',
    mode: Mode.unattended,
    prompt: 'Run the nightly tests',
  );

  test('a template carries what a job is, and nothing that weakens what it is held to', () {
    // `Start` takes `clearance` and `noGate`, and either would let a job set up last month be
    // running today with the gate off. Neither is a field here, and this fails the moment one is.
    expect(nightly.stored.keys.toSet(), <String>{'name', 'project', 'agent', 'mode', 'prompt'});
  });

  test('a setting nobody offered is not honored just because it is in the file', () async {
    // The store is a JSON file somebody can edit. A hand-written `noGate` must not reach `Start`
    // by way of a template — which is why reading one names its fields rather than copying a map.
    final store = MemorySettingsStore(<String, Object?>{
      'templates': <Map<String, Object?>>[
        <String, Object?>{...nightly.stored, 'noGate': true, 'clearance': 'off'},
      ],
    });
    final templates = templatesOn(store);

    await templates.load();

    expect(templates.all, hasLength(1));
    expect(templates.all.single.stored.containsKey('noGate'), isFalse);
    expect(templates.all.single.stored.containsKey('clearance'), isFalse);
  });

  test('an unattended job with nothing to do cannot be started', () {
    const empty = Template(
      name: 'nightly-tests',
      project: 'checkout',
      agent: 'an-agent',
      mode: Mode.unattended,
      prompt: '   ',
    );

    // It would start something and give it nothing to do — the same combination the start dialog
    // refuses, refused again here because a template is the place it could hide.
    expect(empty.startable, isFalse);
    expect(nightly.startable, isTrue);
  });

  test('a mode this build does not know renders rather than starting anything', () {
    const later = Template(
      name: 'from-a-later-build',
      project: 'checkout',
      agent: 'an-agent',
      mode: Mode('PAIRED'),
      prompt: 'something',
    );

    expect(later.mode.recognized, isFalse);
    expect(later.startable, isFalse, reason: 'nothing here knows what that mode would do');
    expect(later.mode.label, isNotEmpty);
  });

  test('naming a job twice replaces it rather than listing it twice', () async {
    final templates = templatesOn(MemorySettingsStore());
    await templates.keep(nightly);

    await templates.keep(
      const Template(
        name: 'nightly-tests',
        project: 'checkout',
        agent: 'other-agent',
        mode: Mode.unattended,
        prompt: 'Run them differently',
      ),
    );

    // Two entries with one name in one project are two commands reading identically, and
    // whichever ran would be the wrong one half the time.
    expect(templates.all, hasLength(1));
    expect(templates.all.single.agent, 'other-agent');
  });

  test('the same name in two projects is two jobs, not one', () async {
    final templates = templatesOn(MemorySettingsStore());

    await templates.keep(nightly);
    await templates.keep(
      const Template(
        name: 'nightly-tests',
        project: 'billing',
        agent: 'an-agent',
        mode: Mode.unattended,
        prompt: 'Run the nightly tests',
      ),
    );

    expect(templates.all, hasLength(2));
    expect(templates.forProject('checkout'), hasLength(1));
    expect(templates.forProject('billing'), hasLength(1));
  });

  test('forgetting one leaves the others', () async {
    final templates = templatesOn(MemorySettingsStore());
    await templates.keep(nightly);
    await templates.keep(
      const Template(
        name: 'weekly-audit',
        project: 'checkout',
        agent: 'an-agent',
        mode: Mode.unattended,
        prompt: 'Audit the dependencies',
      ),
    );

    await templates.forget(nightly);

    expect(templates.all.map((job) => job.name), <String>['weekly-audit']);
  });

  test('a template keeps the repository it starts in, and one named before keeps none', () {
    const inPayments = Template(
      name: 'nightly-tests',
      project: 'checkout',
      agent: 'an-agent',
      mode: Mode.unattended,
      prompt: 'Run the nightly tests',
      repository: 'payments-api',
    );

    expect(Template.fromStored(inPayments.stored).repository, 'payments-api');
    expect(Template.fromStored(nightly.stored).repository, isEmpty);
  });
}
