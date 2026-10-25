# F184 — The Room's Accounts Listed With Remove And New Password

**Status:** Review; Remove waits for porelo's removal of a room account.
**Size:** M - `PoreloClient` in `lib/src/client/porelo_client.dart`, `FleetBackend` in `lib/src/app/fleet_backend.dart`, `ProjectConversation` in `lib/src/app/conversation.dart`, `Settings` in `lib/src/app/settings.dart`, and `MessagesDialog` in `lib/src/ui/messages_view.dart`.

**What must be true.** The project's *Messages* dialog lists everyone who has an account in the
project's room, each with *Remove* to take that account out again. When the person using this
computer already has an account in the room, the dialog shows `"You are in as <name>"` with *New
password* (`talk join --reset`) instead of the *Join* form.

## Plan

- **Where it is today.**
  - `PoreloClient.messageMembers` (`lib/src/client/porelo_client.dart`, line 1032) calls
    `org.fuin.porelo.Tasks1.MessageMembers` and returns `List<MessageMember>` (`person` and `user`
    in `lib/src/client/models.dart`, line 1359), and `PoreloClient.joinMessages` (line 937) calls
    `JoinMessages` with `project`, `person`, and `reset: true | false`.
  - What the daemon lacks today: a removal. The list is `MessageMembers` and the new password is
    `JoinMessages` with `reset: true` (its `MemberExists` error exists), so the list and *New
    password* can be built now. *Remove* is `RemoveMessageMember(project, person) -> (user)` with
    the error `NoSuchMember(person)`, which porelo is filing as an issue of its own; until it
    ships, it goes into `doc/Contract-Gaps.md` and *Remove* is listed as unavailable with that
    reason.
  - In `MessagesDialog` (`lib/src/ui/messages_view.dart`, lines 84–147) and `ProjectConversation`
    (`lib/src/app/conversation.dart`), `members` are rendered as plain text rows (`'${each.person},
    as ${each.user}'`) with no *Remove* action.
  - Below `Who is in it`, `MessagesDialog` always shows the `Join it` section with the `Your name in
    chat` `TextField` (`Key('join-person')`) and the *Join* button (`Key('join-send')`). The button
    to reset the password (`Key('join-reset')`) appears only after the person types their existing
    name, clicks *Join*, and receives a `VarlinkException` with `'MemberExists'`
    (`ProjectConversation.join` in `lib/src/app/conversation.dart`, line 150). Nothing remembers
    which account on this project belongs to the person on this computer.
- **Steps.**
  1. Document the gap in `doc/Contract-Gaps.md`; once `RemoveMessageMember` is served, add `removeMessageMember(String project, String
     person)` to `PoreloClient` (`lib/src/client/porelo_client.dart`), `FleetBackend`
     (`lib/src/app/fleet_backend.dart`), and `MockPoreloDaemon` (`lib/src/mock/mock_daemon.dart`).
  2. In `Settings` (`lib/src/app/settings.dart`), remember the `person` name this computer joined a
     project's room as (or match it against `members` returned by `messageMembers`), clearing it if
     that member is no longer in `members` or is removed.
  3. In `ProjectConversation` (`lib/src/app/conversation.dart`), add `remove(String person)` which
     calls `_backend.removeMessageMember(project.name, person)` and refreshes `members`, and expose
     `joinedAs` (the `MessageMember` in `members` for this person, if any).
  4. In `MessagesDialog` (`lib/src/ui/messages_view.dart`):
     - On each row under *Who is in it*, add a *Remove* button (`Key('member-remove ${each.person}')`)
       with a confirmation step that calls `model.remove(each.person)`.
     - When `model.joinedAs` is present (or the room has the person's account), replace the *Join*
       `TextField` and *Join* button with `"You are in as <name>"` and a *New password* button that
       calls `model.join( reset: true)` (`JoinMessages` with `reset: true`) and displays the new
       one-time password.
- **Tests, their harm, red first.**
  - *Harm:* removing a room member leaves stale credentials active on the homeserver or leaves
    `joinedAs` pointing at a removed account so the person cannot join again; or clicking *New
    password* calls `JoinMessages` without `reset: true` and fails with `MemberExists`.
  - In `test/messages_view_test.dart` (or `test/conversation_test.dart`), verify against
    `MockPoreloDaemon` that:
    1. Joining records the person's account so re-opening `MessagesDialog` shows `"You are in as
       <name>"` and *New password*, and clicking *New password* calls `joinMessages(..., reset:
       true)` and displays the new password.
    2. Clicking *Remove* on a member calls `removeMessageMember`, removes the member from `members`,
       and when that member was `joinedAs`, brings the *Join* form back.
    Break the `reset: true` flag and the `removeMessageMember` call first and watch both assertions
    fail.
  - Words, colors, and layout get no test.

## Acceptance

- Opening *Messages* for a project lists every account in the room under *Who is in it*, each with a
  *Remove* action that removes the account from the room.
- When the person already has an account in the project's room, the dialog shows `"You are in as
  <name>"` with a *New password* button instead of the *Join* form, and clicking *New password*
  issues and shows a fresh password for that account.
- After the person's own account is removed, the *Join* form is offered again.
