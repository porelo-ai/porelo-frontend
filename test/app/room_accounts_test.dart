import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/settings.dart';

void main() {
  // Harm: a lost or shared project identity can reset another room account's password.
  test('room names survive reopening and clearing one preserves the other projects', () async {
    final store = MemorySettingsStore();
    final settings = Settings(store);
    addTearDown(settings.dispose);
    await settings.rememberMessagePerson('local', 'demo', 'anna');
    await settings.rememberMessagePerson('local', 'other', 'bea');
    final reopened = Settings(store);
    addTearDown(reopened.dispose);
    await reopened.load();
    expect(reopened.messagePerson('local', 'demo'), 'anna', reason: 'the joined name must survive restarting');
    expect(reopened.messagePerson('local', 'other'), 'bea', reason: 'each project has its own joined name');
    await reopened.rememberMessagePerson('local', 'demo', null);
    await settings.load();
    expect(
      settings.messagePerson('local', 'demo'),
      isNull,
      reason: 'an absent member must stay forgotten after restart',
    );
    expect(settings.messagePerson('local', 'other'), 'bea', reason: 'forgetting one room must preserve another');
  });

  // Harm: unchecked stored fields can crash startup or select an invalid account for a password reset.
  test('stored room names check every machine project and person and ignore flat entries', () async {
    for (final value in <Object?>[
      null,
      7,
      'anna',
      <Object?>[],
      <String, Object?>{'demo': 'anna'},
      <String, Object?>{'local': 'anna'},
      <Object?, Object?>{
        7: {'demo': 'anna'},
        '': {'demo': 'anna'},
        ' ': {'demo': 'anna'},
        'bad\x00machine': {'demo': 'anna'},
        'local': 7,
      },
      <String, Object?>{
        'local': <Object?, Object?>{7: 'anna', '': 'anna', ' ': 'anna', 'bad\x00project': 'anna', 'demo': 7},
      },
      for (final person in <Object?>[
        null,
        true,
        <Object?>[],
        <String, Object?>{},
        '',
        'Anna',
        'a b',
        'a\x00b',
        'anna\n',
      ])
        <String, Object?>{
          'local': {'demo': person},
        },
    ]) {
      final settings = Settings(MemorySettingsStore({'messagePeople': value}));
      addTearDown(settings.dispose);
      await settings.load();
      for (final machine in ['local', '', ' ', 'bad\x00machine', '7', 'demo']) {
        for (final project in ['demo', '', ' ', 'bad\x00project', '7']) {
          expect(
            settings.messagePerson(machine, project),
            isNull,
            reason: 'invalid or unscoped stored identities must never reach reset',
          );
        }
      }
    }
    final settings = Settings(
      MemorySettingsStore({
        'messagePeople': <Object?, Object?>{
          'local': <Object?, Object?>{'demo': 'anna.2_=-', 'other': false, 7: 'bea'},
          'old-project': 'anna',
          7: {'demo': 'bea'},
        },
      }),
    );
    addTearDown(settings.dispose);
    await settings.load();
    expect(
      settings.messagePerson('local', 'demo'),
      'anna.2_=-',
      reason: 'valid names must remain usable beside invalid entries',
    );
    expect(
      settings.messagePerson('local', 'other'),
      isNull,
      reason: 'a wrong field type must not be coerced into a name',
    );
  });
}
