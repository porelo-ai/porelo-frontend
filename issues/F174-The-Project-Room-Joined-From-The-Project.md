# F174 — The Project Room Joined From The Project

**Status:** Backlog.
**Size:** M - joining moved to the project's page, the dialog's steps for Element and a button opening it, the first screen's address and the chat name's rule.

**What must be true.** Joining a project's room is an action of the project, on its page, for the
project on the machine selected there; the dialog tells the way with Element step by step and opens
it; the first screen names no address the person's client cannot reach, and the chat name's rule is
said before *Join*.

## Plan

- **Today**, read in the code: *Join the project's room* sits in the host machine's menu
  (`machine.joinRoom`, `commands.dart`) beside the project's *Messages* (`project.messages`), both
  opening `MessagesDialog` (`messages_view.dart`). Its first screen shows `ProjectMessages.reaches`
  as *Over matrix, reaching 127.0.0.1:8008*, the host's own address. The name is trimmed but not
  lower-cased, and a refusal stays after the name was corrected (`conversation.dart`). URLs open
  through `Desk.open` (`desk.dart`).
- **Moved:** `machine.joinRoom` goes; the project page's *Messages* tile reads *Messages and the
  project's room*, for the project and machine selected there.
- **First screen:** the address shows only after *Join*, as the forwarded one on this computer;
  before, *on the server* stands beside the transport.
- **The name:** the field says *lower-case letters, digits and . _ = -* and lower-cases what is
  typed; the refusal clears when the field changes.
- **Element:** after *Join*, numbered steps: open Element, *Edit* the homeserver, paste the
  homeserver URL, sign in with the Matrix ID and password, join the room by its name. *Open
  Element* opens `https://app.element.io/` through `Desk.open`, with no credential in the URL.
- **Tests, their harm, red first:** two machines with a project of the same name: the tile joins
  through the selected machine's backend (a person let into another machine's room); the URL opened
  carries no password. Words get no test.

- *Taken until the operator answers otherwise:* **Element with the homeserver filled in:** no working link form for app.element.io's sign-in with
  a custom homeserver was found. Recommended and taken: *Open Element* opens app.element.io and the
  steps say to edit the homeserver; a prefilled link only if one is shown to work while building.

## Acceptance

- In the guided walk and on the next rented host: the room is joined from the project's page, the
  steps lead into Element, *Michi* becomes `michi` as typed.
