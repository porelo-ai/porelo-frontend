import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/fleet_backend.dart';
import 'package:porelo_frontend/src/app/room_setup.dart';

class _Machine implements SetsUpRooms {
  _Machine(this.answer);

  final Future<ProjectMessages?> Function() answer;

  @override
  Future<ProjectMessages?> setUpMessages(String project) => answer();
}

ProjectMessages _room({required bool ready, String detail = ''}) => ProjectMessages(
  transport: 'matrix',
  conversation: '!room:host',
  reaches: const <String>[],
  ready: ready,
  detail: detail,
  loopbackOnly: false,
);

void main() {
  // Harm: a room that came up is not opened, or one that did not is opened empty.
  test('a room that can carry messages opens', () async {
    final said = await setUpRoom(_Machine(() async => _room(ready: true)), 'checkout');
    expect(said.ready, isTrue);
  });

  // Harm: a room not ready yet is opened as if it were, or nobody is told why not.
  test("a room not ready yet says why in the machine's words", () async {
    final said = await setUpRoom(
      _Machine(() async => _room(ready: false, detail: 'the homeserver did not answer')),
      'checkout',
    );
    expect(said.ready, isFalse);
    expect(said.words, "checkout's room is not ready yet: the homeserver did not answer");
  });

  // Harm: a refused take fails as a programmer's error, and the press seems lost.
  test("a refused take says the transport's words", () async {
    final said = await setUpRoom(
      _Machine(
        () async => throw const VarlinkException('org.fuin.porelo.Tasks1.ConversationRefused', <String, dynamic>{
          'message': 'the forge refused the take',
          'code': 69,
        }),
      ),
      'checkout',
    );
    expect(said.ready, isFalse);
    expect(said.words, 'The machine refused it: the forge refused the take');
  });

  // Harm: an older Porelo fails with a method name nobody can act on.
  test('a Porelo without the call says it cannot', () async {
    final said = await setUpRoom(_Machine(() async => throw const FeatureNotSupported('SetUpMessages')), 'checkout');
    expect(said.words, contains('cannot set up a room before the first task'));
  });

  // Harm: a project without a conversation reads as a room that is coming.
  test('a project with no room says so', () async {
    final said = await setUpRoom(_Machine(() async => null), 'checkout');
    expect(said.words, 'checkout has no room on this machine.');
  });
}
