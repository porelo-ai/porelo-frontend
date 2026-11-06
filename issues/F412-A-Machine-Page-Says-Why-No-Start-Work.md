# F412 — A Machine Page Says Why It Offers No Start Work

**Status:** Backlog.
**Size:** XS - where an organization's machine page offers no *Start work*, it says why in one line, and the window's
two connections on it are told apart in words.

**What must be true.** A machine page that offers no *Start work* says what stands in its way (the organization's
connection to it is down, it waits for your token, you have no project there); and "Connected" says which connection:
this window's to the machine's Porelo, or the organization's way in that work starts through.

## Why

The operator's walk on the rehearsal VM (2026-11-06): *My machines → rehearsal* said "Connected" and offered no *Start
work*, which the operator then looked for on the Organization page.

It is the same page from both places (`shell.dart` `_machineOnePage`, where a machine has an organization's card).
"Connected" there is this window's connection to the machine's Porelo (`machine_details_page.dart`); *Start work*
shows only where the organization's connection to the machine is up and it waits for no token
(`organization_host_pages.dart` `_connection`, `ready`). The page said neither.

## Plan

- `lib/src/ui/organization_host_pages.dart` `_connection`: where `ready` is false and work could start otherwise, one
  line under the buttons names the first thing missing, from the same conditions.
- `lib/src/ui/machine_details_page.dart`: on a machine with an organization's card the line says "This window is
  connected to its Porelo".
- **The test that goes red first:** a machine page whose host waits for a token shows no *Start work* and says it waits
  for the token. It guards a person left looking for a button with nothing saying why it is not there.
