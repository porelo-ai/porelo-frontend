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
}
