import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

void main() {
  Map<String, dynamic> reply([Object? flow]) => <String, dynamic>{
    'name': 'an-agent',
    'label': 'An Agent',
    'binary': 'an-agent',
    'version': '1',
    'from': '/usr/bin/an-agent',
    'allowedDomains': <String>[],
    'canLogIn': true,
    'loginCommand': <String>['porelo', 'vault', 'login', 'an-agent'],
    'loginFlow': ?flow,
  };

  // Harm: a flow guessed from a missing or unknown value promises a way the host does not offer.
  test('the flow a definition names is read, and a missing or unknown one is none', () {
    expect(Agent.from(reply('paste-code')).loginFlow, LoginFlow.pasteCode);
    expect(Agent.from(reply('device-code')).loginFlow, LoginFlow.deviceCode);
    expect(Agent.from(reply('loopback')).loginFlow, LoginFlow.loopback);
    expect(Agent.from(reply()).loginFlow, isNull);
    expect(Agent.from(reply('qr-code')).loginFlow, isNull);
    expect(Agent.from(reply(7)).loginFlow, isNull);
  });

  // Harm: reading the flow changes what is run on the machine.
  test('the login command stays as the machine named it whatever the flow', () {
    for (final flow in <Object?>['paste-code', 'device-code', 'loopback', null, 'qr-code']) {
      expect(Agent.from(reply(flow)).loginCommand, <String>['porelo', 'vault', 'login', 'an-agent']);
    }
  });
}
