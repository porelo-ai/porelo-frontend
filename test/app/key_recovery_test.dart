import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/key_recovery.dart';
import 'package:porelo_frontend/src/app/settings.dart';

const _base = '56420b3';
const _out = '/media/usb/backup';
const _card = '/home/person/.config/porelo/identity/card';

BackupKeyRequest _request(RecoveryReceipts receipts, {BackupScope scope = const BackupScope.organization()}) =>
    BackupKeyRequest(scope: scope, use: BackupKeyUse.make, base: _base, receipts: receipts, random: Random(1));

String _idIn(List<String> command) => command[command.indexOf('--id') + 1];

void main() {
  late RecoveryReceipts receipts;

  setUp(() {
    receipts = SettingsReceipts(Settings(MemorySettingsStore()));
  });

  group('what is run', () {
    // Harm: a dialog sends a scope Core has dropped, so a backup key can never be made after the cut.
    test('making names the organization or the host, the base and the id, and never an old scope', () {
      expect(backupMakeCommand(const BackupScope.organization(), out: _out, id: 'bk-1', base: _base), [
        'porelo',
        'identity',
        'backup-key',
        '--organization',
        '--out',
        _out,
        '--base',
        _base,
        '--id',
        'bk-1',
        '--json',
      ]);
      expect(backupMakeCommand(const BackupScope.host('build'), out: _out, id: 'bk-1', base: _base), [
        'porelo',
        'identity',
        'backup-key',
        '--host',
        'build',
        '--out',
        _out,
        '--base',
        _base,
        '--id',
        'bk-1',
        '--json',
      ]);
    });

    test('using names the backup file and the new card, and never an old scope', () {
      expect(backupUseCommand(const BackupScope.organization(), file: _out, card: _card, id: 'bk-1', base: _base), [
        'porelo',
        'identity',
        'backup-key',
        '--organization',
        '--use',
        _out,
        '--card',
        _card,
        '--base',
        _base,
        '--id',
        'bk-1',
        '--json',
      ]);
    });

    // Harm: a revision read as an option, or a request with no revision to be compared against.
    test('a base that is no revision makes no command', () {
      for (final base in ['', '--force', 'a b']) {
        expect(
          () => backupMakeCommand(const BackupScope.organization(), out: _out, id: 'bk-1', base: base),
          throwsFormatException,
        );
      }
    });
  });

  group('one key per request', () {
    // Harm: a key made but its answer lost is made a second time under a new id.
    for (final code in [69, 70, -1, null, 129, 137]) {
      test('after exit $code the next attempt asks under the same id and first base', () async {
        final first = await _request(receipts).start(_out);
        await expectLater(
          _request(receipts).ended(code: code, lastLine: '', file: _out),
          throwsA(isA<BackupKeyRefused>().having((refused) => refused.words, 'words', contains('kept'))),
        );
        final moved = BackupKeyRequest(
          scope: const BackupScope.organization(),
          use: BackupKeyUse.make,
          base: 'later',
          receipts: receipts,
        );
        expect(moved.pending, isTrue);
        final second = await moved.start(_out);
        expect(_idIn(second), _idIn(first));
        expect(second[second.indexOf('--base') + 1], _base);
      });
    }

    // Harm: a refusal that made nothing keeps its id, so a new try after moved-on is refused for ever.
    test('a refusal is said by its words, drops the request, and the next takes a new id', () async {
      final first = await _request(receipts).start(_out);
      await expectLater(
        _request(receipts).ended(
          code: 65,
          lastLine: jsonEncode({'reason': 'moved-on', 'words': 'the organization moved on', 'revision': 'x'}),
          file: _out,
        ),
        throwsA(
          isA<BackupKeyRefused>()
              .having((refused) => refused.words, 'words', 'the organization moved on')
              .having((refused) => refused.reason, 'reason', 'moved-on'),
        ),
      );
      expect(_request(receipts).pending, isFalse);
      final fresh = BackupKeyRequest(
        scope: const BackupScope.organization(),
        use: BackupKeyUse.make,
        base: _base,
        receipts: receipts,
        random: Random(2),
      );
      expect(_idIn(await fresh.start(_out)), isNot(_idIn(first)));
    });

    test('a reason nobody knows is said by its words', () async {
      await _request(receipts).start(_out);
      await expectLater(
        _request(receipts).ended(code: 65, lastLine: '{"reason":"brand-new","words":"as Porelo says it"}', file: _out),
        throwsA(isA<BackupKeyRefused>().having((refused) => refused.words, 'words', 'as Porelo says it')),
      );
    });

    // Harm: an uncertain request dropped because a later terminal never opened, so a second key follows.
    test('a terminal that never opened leaves the request as it was', () async {
      await _request(receipts).start(_out);
      await expectLater(
        _request(receipts).ended(code: null, lastLine: '', file: _out, started: false),
        throwsA(isA<BackupKeyRefused>()),
      );
      expect(_request(receipts).pending, isFalse, reason: 'nothing ran under a new request');

      await _request(receipts).start(_out);
      await expectLater(_request(receipts).ended(code: 70, lastLine: '', file: _out), throwsA(isA<BackupKeyRefused>()));
      await _request(receipts).start(_out);
      await expectLater(
        _request(receipts).ended(code: null, lastLine: '', file: _out, started: false),
        throwsA(isA<BackupKeyRefused>()),
      );
      expect(_request(receipts).pending, isTrue, reason: 'the earlier attempt may have made it');
    });

    test('a request in one place never answers for another', () async {
      await _request(receipts).start(_out);
      expect(_request(receipts, scope: const BackupScope.host('build')).pending, isFalse);
    });

    // Harm: two terminals under one request at once.
    test('a second attempt for the same place waits until the first has ended', () async {
      final request = _request(receipts);
      await request.attempt(() async {
        await expectLater(_request(receipts).attempt(() async {}), throwsA(isA<BackupKeyRefused>()));
      });
      await _request(receipts).attempt(() async {});
    });
  });

  group('the answer', () {
    Future<String> started() async => _idIn(await _request(receipts).start(_out));

    // Fixture: section 1's answer of a write.
    test('every write’s answer finishes the request', () async {
      final id = await started();
      final done = await _request(receipts)
          .ended(code: 0, lastLine: jsonEncode({'revision': '9d0fcc5', 'id': id, 'again': false}), file: _out);
      expect(done.revision, '9d0fcc5');
      expect(done.again, isFalse);
      expect(_request(receipts).pending, isFalse);
    });

    test('what it names of the key is read', () async {
      final id = await started();
      final done = await _request(receipts).ended(
        code: 0,
        lastLine: jsonEncode({
          'revision': '9d0fcc5',
          'id': id,
          'again': false,
          'scope': {'kind': 'organization', 'name': null},
          'fingerprint': 'SHA256:backup',
          'file': _out,
        }),
        file: _out,
      );
      expect(done.fingerprint, 'SHA256:backup');
    });

    // Harm: an answer for another request or place taken for this one, and its request dropped.
    for (final (label, answer) in [
      ('another request', (String id) => {'revision': 'r', 'id': 'bk-other', 'again': false}),
      ('no JSON', (String id) => 'done'),
      (
        'another place',
        (String id) => {
          'revision': 'r',
          'id': id,
          'again': false,
          'scope': {'kind': 'host', 'name': 'build'},
        },
      ),
      ('another file', (String id) => {'revision': 'r', 'id': id, 'again': false, 'file': '/elsewhere'}),
    ]) {
      test('$label is refused and keeps the request', () async {
        final id = await started();
        final line = answer(id);
        await expectLater(
          _request(receipts).ended(code: 0, lastLine: line is String ? line : jsonEncode(line), file: _out),
          throwsA(isA<BackupKeyRefused>()),
        );
        expect(_request(receipts).pending, isTrue);
      });
    }
  });

  test('a kept request that cannot be read is no request', () async {
    await receipts.keep('backup-make/organization', {
      'scope': {'kind': 'project', 'host': 'demo'},
      'id': 'bk-1',
      'base': _base,
      'earlier': false,
    });
    expect(_request(receipts).pending, isFalse);
  });
}
