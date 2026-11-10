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

  // Harm: an invited account forgotten as invited is offered New password, which ends its sessions in every room.
  test(
    'an invited membership survives reopening, goes with its person, and older settings read as not invited',
    () async {
      final store = MemorySettingsStore();
      final settings = Settings(store);
      addTearDown(settings.dispose);
      await settings.rememberMessagePerson('local', 'demo', 'anna');
      await settings.rememberMessageInvited('local', 'demo', invited: true);
      await settings.rememberMessagePerson('local', 'other', 'bea');
      final reopened = Settings(store);
      addTearDown(reopened.dispose);
      await reopened.load();
      expect(reopened.messageInvited('local', 'demo'), isTrue, reason: 'an invitation must survive restarting');
      expect(reopened.messageInvited('local', 'other'), isFalse, reason: 'each project keeps its own');
      await reopened.rememberMessagePerson('local', 'demo', 'cleo');
      expect(reopened.messageInvited('local', 'demo'), isFalse, reason: 'another person is not that invitation');
      await settings.rememberMessageInvited('local', 'other', invited: true);
      await settings.rememberMessagePerson('local', 'other', null);
      expect(settings.messageInvited('local', 'other'), isFalse, reason: 'a forgotten member is not invited');
      await settings.rememberMessagePerson('local', 'other', 'bea');
      expect(settings.messageInvited('local', 'other'), isFalse, reason: 'joining again starts as not invited');
      await settings.rememberMessageInvited('local', 'nobody', invited: true);
      expect(settings.messageInvited('local', 'nobody'), isFalse, reason: 'only a remembered person is invited');

      final older = Settings(
        MemorySettingsStore({
          'messagePeople': {
            'local': {'demo': 'anna'},
          },
        }),
      );
      addTearDown(older.dispose);
      await older.load();
      expect(older.messageInvited('local', 'demo'), isFalse, reason: 'settings from before this field are not invited');
      for (final value in <Object?>[
        7,
        'demo',
        <Object?>['demo'],
        <String, Object?>{'local': 'demo'},
        <String, Object?>{'local': 7},
        <String, Object?>{
          'local': <Object?>[7, true, ''],
        },
        <String, Object?>{
          'elsewhere': <Object?>['demo'],
        },
        <String, Object?>{
          'local': <Object?>['other'],
        },
      ]) {
        final wrong = Settings(
          MemorySettingsStore({
            'messagePeople': {
              'local': {'demo': 'anna'},
            },
            'messageInvited': value,
          }),
        );
        addTearDown(wrong.dispose);
        await wrong.load();
        expect(
          wrong.messageInvited('local', 'demo'),
          isFalse,
          reason: 'an unchecked field is not an invitation: $value',
        );
        expect(wrong.messagePerson('local', 'demo'), 'anna', reason: 'a wrong field leaves the person readable');
      }
    },
  );

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
