# F427 — A Host's Forge Opened From Its Machine

```json
{
  "$schema": "issue-1.json",
  "id": "F427",
  "title": "A Host's Forge Opened From Its Machine",
  "state": "Review",
  "size": "S",
  "priority": "Medium",
  "rank": 75,
  "blockedBy": [],
  "covers": "A connected host's row and machine page offer *Open its forge*, at the address its forge answers to."
}
```

**Why this size.** one command on the organization's machine row and the machine's page, from the forward the window
already raises, and its test.

**What must be true.** While the window is connected to a host with a forge of its own, the host's row under the
organization and its machine page offer *Open its forge*, which opens the forge's web page in the browser at the
address the host's forge answers to.

## Why

In the trial move of 2026-11-07 the window forwarded the host's forge web port while connected, but offered no way to
open it: *My forges* listed only the central forge, and the machine had no *Open the forge*. The person typed
`http://localhost:3000`, which the host's forge refuses with 403: it answers only to `<host>.localhost:<port>` and
`127.0.0.1:<port>`.

## Plan

- `HostCardSsh.forgeUrl` (`packages/porelo_host/lib/src/host_card_ssh.dart`) is `http://<host>.localhost:<webPort>/`,
  the address the forge's gate accepts. The command opens that, through the window's existing `openLink`.
- *Open its forge* is a `Command` (`lib/src/ui/commands.dart`) homed on the organization's machine row and the
  machine's page (`lib/src/ui/organization_host_pages.dart`). It is grey while the window is not connected to the
  host, saying "Connect first: the forge is reached through the connection", and grey for a host without a forge,
  saying so.
- Red first: a widget test with a connected host card holding a web port expects the command and the opened address
  `http://<host>.localhost:<port>/`, and grey with its reason while not connected.

## Acceptance

- A connected host with a forge offers *Open its forge* on its row and its page, and it opens
  `http://<host>.localhost:<port>/`.
- Not connected, the command is listed grey with its reason; a host without a forge says it has none.

## Reading

- The card's forge address is given only while connected, and has a test of its own on the real connections.
- A host the organization lists without a forge says so before any connection, not "Connect first".
- The command's run no longer repeats the check the menu makes before it runs.

