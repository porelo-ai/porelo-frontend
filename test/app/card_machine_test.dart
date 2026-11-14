import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_host/porelo_host.dart' show HostCardSsh;

import '../support/organization_fixtures.dart' show buildHost;

Machine _card(String machine, String address, {String login = 'pat'}) => Machine(
  name: machine,
  socketPath: '/unused-$machine',
  hostCard: HostCardSsh(
    name: 'build',
    address: address,
    sshPort: 22,
    hostKey: buildHost.hostKey!,
    login: login,
    publicKey: buildHost.hostKey!,
  ),
);

void main() {
  final first = _card('build', '192.0.2.7');
  final second = _card('build-again', '198.51.100.9');

  // Harm: of two machines under the same card's name and login, the list of one that is not the organization's machine
  // ends a wait for the token that machine still has.
  test('two cards that both pass for the machine name none of them', () {
    expect(cardMachineOf([first, second], 'build', login: 'pat', isTheMachine: (_) => true), isNull);
  });

  // Harm: a card whose address the organization no longer names lends its machine's list to the one it names.
  test('only the card the organization takes for its machine is that machine', () {
    bool named(HostCardSsh card) => card.address == '198.51.100.9';
    expect(cardMachineOf([first, second], 'build', login: 'pat', isTheMachine: named), same(second));
    expect(cardMachineOf([first], 'build', login: 'pat', isTheMachine: named), isNull);
    expect(
      cardMachineOf([first], 'build', login: 'mia', isTheMachine: (_) => true),
      isNull,
      reason: 'another login',
    );
  });
}
