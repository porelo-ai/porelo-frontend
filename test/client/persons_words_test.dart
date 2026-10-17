// Linux only: it stands the mock daemon on a unix socket, and on GitHub's Windows runner a test
// through it hung where no timeout could end it.
@Tags(<String>['linux'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/mock/mock_daemon.dart';

/// A person's own words reaching a task's agent: why a push was dropped, why a message was refused,
/// or anything said straight into its inbox. Sent only when there are words, so a Porelo that takes
/// no `reason` never meets one it does not know.
void main() {
  late MockDaemon daemon;
  late Map<String, dynamic> asked;

  setUp(() async {
    daemon = MockDaemon();
    await daemon.start();
  });

  tearDown(() => daemon.stop());

  Future<PoreloClient> connect() => PoreloClient.connect(Backend(socketPath: daemon.socketPath, label: 'mock'));

  void answering(String method, Map<String, dynamic> reply) => daemon.method(method, (parameters) {
        asked = parameters;
        return reply;
      });

  test('a drop names its reason, and says whether its task was told', () async {
    answering('Reject', <String, dynamic>{'rejected': 'migrate', 'told': true});

    final done = await (await connect()).reject('checkout', 'migrate', reason: '  the rounding is wrong ');

    expect(asked['reason'], 'the rounding is wrong');
    expect(done.told, isTrue);
  });

  test('a drop without words sends no reason, and a Porelo that does not say told is not read as no', () async {
    answering('Reject', <String, dynamic>{'rejected': 'migrate'});

    final done = await (await connect()).reject('checkout', 'migrate', reason: '   ');

    expect(asked.containsKey('reason'), isFalse);
    expect(done.told, isNull);
  });

  test('a refusal carries the reason, a release never does', () async {
    answering('Release', <String, dynamic>{'outcome': 'REFUSED'});
    final client = await connect();

    await client.release('porelo-checkout-shell', 'msg-1.json', refuse: true, reason: 'not yet');
    expect(asked['reason'], 'not yet');

    await client.release('porelo-checkout-shell', 'msg-1.json', reason: 'not yet');
    expect(asked.containsKey('reason'), isFalse);
    expect(asked.containsKey('refuse'), isFalse);
  });

  test('words told to a task go to that task, and the file written comes back', () async {
    answering('Tell', <String, dynamic>{'message': '/inbox/told-1.json'});

    final written = await (await connect()).tell('porelo-checkout-migrate', 'stop the migration');

    expect(asked, <String, dynamic>{'task': 'porelo-checkout-migrate', 'text': 'stop the migration'});
    expect(written, '/inbox/told-1.json');
  });
}
