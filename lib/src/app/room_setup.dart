import 'package:porelo_frontend/client.dart';

import 'fleet_backend.dart';

/// What setting up a project's room before its first task did.
class RoomSetUp {
  /// Constructor taking both.
  const RoomSetUp({required this.ready, required this.words});

  /// Whether the room can carry messages now, so it opens.
  final bool ready;

  /// Why it cannot, in words for a person; empty when it is ready.
  final String words;
}

/// Sets up [project]'s room on [machine]. For a project the machine carries and this person has not taken yet, this
/// takes it here first, as its first start would.
///
/// Every outcome is an answer: a room not ready yet says why, and a refusal says the machine's words.
Future<RoomSetUp> setUpRoom(SetsUpRooms machine, String project) async {
  try {
    final messages = await machine.setUpMessages(project);
    if (messages == null) return RoomSetUp(ready: false, words: '$project has no room on this machine.');
    if (messages.ready) return const RoomSetUp(ready: true, words: '');
    return RoomSetUp(
      ready: false,
      words: messages.detail.isEmpty
          ? "$project's room is not ready yet."
          : "$project's room is not ready yet: ${messages.detail}",
    );
  } on FeatureNotSupported {
    return const RoomSetUp(ready: false, words: "This machine's Porelo cannot set up a room before the first task.");
  } on VarlinkException catch (refusal) {
    final said = refusal.parameters['message'] ?? refusal.parameters['words'];
    return RoomSetUp(
      ready: false,
      words: refusal.simpleName == 'ConversationRefused'
          ? 'The machine refused it: ${said ?? 'no reason given'}'
          : 'The machine refused it: ${said ?? refusal.simpleName}.',
    );
  }
}
