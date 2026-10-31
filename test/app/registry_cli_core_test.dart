import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/registry.dart';
import 'package:porelo_frontend/src/app/run_here.dart';

const _base = '1111111111111111111111111111111111111111';
const _commit = '2222222222222222222222222222222222222222';

void main() {
  late Directory scratch;
  late List<List<String>> calls;
  late List<String> handedText;
  late Ran answer;

  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('registry-cli-');
    calls = [];
    handedText = [];
    answer = (code: 0, out: '{"commit":"$_commit","path":"hosts/walk9/access.yml"}', err: '');
  });
  tearDown(() => scratch.delete(recursive: true));

  CliRegistryCore core() => CliRegistryCore(
    scratch: '${scratch.path}/filing',
    run: (program, arguments, {inDirectory, environment = const {}, input}) async {
      calls.add([program, ...arguments]);
      final i = arguments.indexWhere((each) => each == '--file' || each == '--card');
      if (i >= 0) handedText.add(await File(arguments[i + 1]).readAsString());
      return answer;
    },
  );

  // Guards a host access change filed twice or on another base: the id and base reach Core.
  test('a host access change is handed to Core as its file, with its id and base', () async {
    final filed = await core().file(
      '/private/registry/checkout',
      const RegistryFiling(
        RegistryFilingKind.hostAccess,
        host: 'walk9',
        id: 'ab12',
        base: _base,
        content: 'admins: {}\n',
      ),
    );

    expect(filed.revision, _commit);
    expect(calls.single.take(5), ['porelo', 'registry', 'file', 'host-access', '/private/registry/checkout']);
    expect(calls.single.skip(7), ['--host', 'walk9', '--id', 'ab12', '--base', _base, '--json']);
    expect(calls.single[5], '--file');
    expect(handedText, ['admins: {}\n']);
    expect(scratch.listSync(recursive: true).whereType<File>(), isEmpty, reason: 'nothing handed stays behind');
  });

  // Guards an owners.yml change handed to Core as a card, which files it at the wrong path or is refused.
  test('an owners.yml change is handed to Core as its file, with its id and base', () async {
    await core().file(
      '/private/registry/checkout',
      const RegistryFiling(RegistryFilingKind.owners, person: 'bob', id: 'ab12', base: _base, content: 'owners: []\n'),
    );

    expect(calls.single, [
      'porelo',
      'registry',
      'file',
      'owners',
      '/private/registry/checkout',
      '--file',
      calls.single[6],
      '--id',
      'ab12',
      '--base',
      _base,
      '--json',
    ]);
    expect(handedText, ['owners: []\n']);
  });

  // Guards a host card removal that hands Core a file or loses its host, id or base, and so removes another.
  test('a host card removal is handed to Core with its host, id and base and no file', () async {
    final filed = await core().file(
      '/private/registry/checkout',
      const RegistryFiling(RegistryFilingKind.hostCardRemove, host: 'walk9', id: 'ab12', base: _base),
    );

    expect(filed.revision, _commit);
    expect(calls.single, [
      'porelo',
      'registry',
      'file',
      'host-card-remove',
      '/private/registry/checkout',
      '--host',
      'walk9',
      '--id',
      'ab12',
      '--base',
      _base,
      '--json',
    ]);
    expect(scratch.listSync(recursive: true).whereType<File>(), isEmpty, reason: 'a removal hands no file');
  });

  // Guards a refused read or change passing as a registry or a commit: it is a refusal in Core's words.
  test('a refusal is Core typed words and never an answer, and leaves no file behind', () async {
    answer = (code: 65, out: '{"reason":"base-moved","words":"HEAD is not the base."}', err: 'secret-ish noise');

    await expectLater(
      core().file('/c', const RegistryFiling(RegistryFilingKind.hostCard, host: 'walk9', content: 'card')),
      throwsA(isA<RegistryRefusal>().having((refused) => refused.words, 'words', 'HEAD is not the base.')),
    );
    await expectLater(core().read('/c'), throwsA(isA<RegistryRefusal>()));
    expect(scratch.listSync(recursive: true).whereType<File>(), isEmpty);
  });

  // Guards a filing that ended after its commit (69, 70) read as one that made nothing, so its request is dropped and
  // the next attempt commits a second time.
  test('a refused filing keeps Core’s exit code and typed reason', () async {
    for (final (code, reason) in [(70, null), (69, 'push-failed'), (65, 'base-moved')]) {
      answer = (code: code, out: reason == null ? '' : '{"reason":"$reason","words":"w"}', err: '');
      await expectLater(
        core().file('/c', const RegistryFiling(RegistryFilingKind.owners, content: 'owners: []\n')),
        throwsA(
          isA<RegistryFilingRefused>()
              .having((refused) => refused.code, 'code', code)
              .having((refused) => refused.reason, 'reason', reason),
        ),
      );
    }
  });
}
