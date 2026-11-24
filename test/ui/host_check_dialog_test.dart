import 'dart:async';
import 'dart:io' show ProcessException;

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/host_check_run.dart';
import 'package:porelo_frontend/src/app/run_here.dart';

void main() {
  group('whether the check is carried', () {
    Future<HostCheckRun?> carried(FutureOr<Ran> Function() answer) => HostCheckRun(
      executable: 'porelo-host',
      run: (_, arguments, {inDirectory, environment = const {}, input}) async {
        expect(arguments, ['check', '--available']);
        return answer();
      },
    ).carried().then((carried) => carried.run);

    // Harm: the dialog of today gains a check step that cannot run, on the collection pinned now or an older command.
    test('only exit 0 gives the step; a collection with none, an older command and none at all do not', () async {
      expect(await carried(() => (code: 0, out: '', err: '')), isNotNull);
      expect(await carried(() => (code: 4, out: '', err: '')), isNull);
      expect(await carried(() => (code: 64, out: '', err: 'usage')), isNull);
      expect(await carried(() => throw const ProcessException('porelo-host', [])), isNull);
    });

    Future<String?> why(FutureOr<Ran> Function() answer) async => (await HostCheckRun(
      executable: 'porelo-host',
      run: (_, _, {inDirectory, environment = const {}, input}) async => answer(),
    ).carried()).why;

    // Harm: a collection the package left unreadable is worded as one without a check, and the broken install hides.
    test(
      'what porelo-host says of a missing check is the reason given; an older command and none at all say so',
      () async {
        const unreadable =
            'The collection carried here cannot be read by this account: /usr/lib/x.tar.gz (Permission denied).';
        expect(await why(() => (code: 0, out: '', err: '')), isNull);
        expect(await why(() => (code: 4, out: '$unreadable\n', err: '')), unreadable);
        expect(await why(() => (code: 4, out: '', err: '')), contains('holds no check'));
        expect(
          await why(() => (code: 64, out: '', err: 'usage: porelo-host check\n')),
          contains('usage: porelo-host check'),
        );
        expect(await why(() => throw const ProcessException('porelo-host', [])), contains('could not be run'));
      },
    );
  });
}
