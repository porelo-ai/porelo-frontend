# F400 — A Join Into A Second Room Says To Accept The Invitation

**Status:** Review.
**Size:** XS - one field read, the steps' words for an invitation, and their test.

**What must be true.** When *Join* in a project's messages invites a Matrix account the person already has, rather
than making one, the window says to accept the invitation to the room in the Matrix client they already sign in to,
and shows no password and no "shown once" note.

## Why

The Matrix transport is to invite an existing account of the same homeserver into a second project's room instead of
refusing it (porelo-message-matrix's join, agreed in the room 2026-11-06), answering a login without a password.
The window shows only the fields present, so nothing breaks, but its steps tell the person to sign in with a password
shown below and that seeing it again means a new one, which is not so for an invitation.

## Plan

- `lib/src/client/models.dart`: `MessagesJoined.invited`, read from the daemon's `JoinMessages` answer field
  `invited: bool`, false where absent (Agent Core, 2026-11-06).
- `lib/src/ui/messages_view.dart`: for an invitation, the steps say to open the Matrix client they already use, signed
  in as the Matrix ID shown, and accept the invitation to the room shown; no "shown once" note.
- **The test that goes red first:** a widget test of the messages view with a joined answer `invited: true` and no
  password: no step names a password and no row reads Password. It guards a person told to sign in with a password
  that does not exist, who then asks for a new one and loses their account's sessions.

## How it stands

- `MessagesJoined.invited` reads Porelo's `invited`, false where a daemon does not say. For an invitation the
  messages dialog says the existing Matrix account was invited, to open the client they already sign in to as the
  Matrix ID shown and accept the invitation to the room shown; it shows the homeserver, Matrix ID and room, no
  password, no "shown once" note, no *New password*, and *Done* without the password sentence. Seen red: the
  dialog said to sign in with a password (`test/ui/conversation_accounts_test.dart`).
- A code reading found that after *Done* and opening the dialog again, or while the homeserver forward is down, the
  join answer is gone and *New password* came back for the invited account, and that the tests did not decode the
  answer, carried no password to suppress, nor opened the dialog again; also a grey-button note for a hidden
  *New password*, no loopback forward note, empty Matrix ID or room words, and no copy buttons for an invitation.
  All taken: the settings remember beside the person whether the join invited it (`messageInvited`, set before the
  forward, cleared with the person, absent read as not invited), and that alone gates *New password* and its grey
  words; the invitation shows the loopback note, treats an empty field as absent, and copies each field but a
  password, which it never shows. Seen red: *New password* offered after reopening, the grey note, the missing
  forward note, the empty Matrix ID row and the missing copy buttons (`test/ui/conversation_accounts_test.dart`);
  the decoding (`test/client/messages_test.dart`), the shown password and the remembered invitation
  (`test/app/room_accounts_test.dart`) by a deliberate break.
- Not run live: no host runs a Porelo with `invited` yet.

## Blocked by

- Freed (2026-11-10): Porelo's `JoinMessages` answers `invited: bool`, true only where the transport invited the
  person's existing account, false otherwise, never absent.
