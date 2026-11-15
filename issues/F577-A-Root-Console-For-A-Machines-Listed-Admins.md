# F577 — A Root Console For A Machine's Listed Admins

```json
{
  "$schema": "issue-1.json",
  "id": "F577",
  "title": "A Root Console For A Machine's Listed Admins",
  "state": "Review",
  "size": "S",
  "priority": "High",
  "rank": 13,
  "blockedBy": [],
  "covers": "Story ST361: a machine's SSH Console offers a switch between the person's own account and root to a person the organization lists as that machine's admin, and to nobody else."
}
```

**Why this size.** One switch on the console page and one variant of its command line; the organization's view
already names each machine's admins, and the console and its terminal stand.

**What must be true.** A person the organization lists as a machine's admin opens a root shell on that machine from
its SSH Console, by the key their agent holds and the host key the machine was pinned with; nobody else is offered
one.

## Plan

- Who may: after every follow, root on a host takes exactly the card keys of the persons listed as that machine's
  admins (`hosts[].admins`); an Organization Admin not listed there takes none. So the switch shows only where the
  organization's view, fresh or stale, names the person (`me`, holding roles) among that machine's admins.
- `lib/src/app/ssh_console.dart`: `sshConsoleCommand(machine, {asRoot})` logs in as `root@<host>`, with the
  machine's pinned options, the key from the agent, no key file and no password option. On Linux the card's options
  go through its control master, whose path does not name the login, so a root line there would ride the person's
  own connection and open their shell, not root's: the root line opens a connection of its own
  (`ControlPath=none`, `ProxyCommand=none`), as a card's line on Windows always does. `rootConsoleOffered(machine,
  view)` says whether the switch shows.
- `lib/src/ui/ssh_console_view.dart` and `shell.dart`: a segmented switch *My account* / *root* above the button,
  for an offered person alone; the terminal's title and words name the login. A root login refused (no follow yet,
  key not taken) shows ssh's own answer in the terminal, nothing more.
- Red first: `test/app/ssh_console_test.dart` — the switch offered to a listed admin and not to an Organization
  Admin not listed, a person not listed, a revoked card, or a machine without a card; the root line differs from the
  person's own only in the login on Windows, and on Linux only in the login and the connection of its own.

## Acceptance

- The guards above, each seen red; a widget test that the switch shows for a listed admin, not for others, and that
  *root* opens the terminal with the root line.

## Built

- `rootConsoleOffered` (`lib/src/app/ssh_console.dart`) offers the switch only where the organization's view, fresh
  or stale, lists the person, holding roles, among the admins of the machine its card names; an owner or an
  Organization Admin not listed, a revoked card and a machine no card names get none. The press asks it again.
- `sshConsoleCommand(machine, asRoot: true)` logs in as `root@<host>` with the machine's own options; on Linux
  `ownConnection` swaps the card's master for a connection of its own, and refuses a master shared in any other form.
- The console page (`SshConsoleView`) shows *My account* / *root* to an offered person, its state its machine's own,
  so a login chosen on one console is never carried to the next.
- Tests: the switch's and the line's guards in `test/app/ssh_console_test.dart`, the switch, its line and the
  carry-over in `test/ui/machine_own_pages_test.dart`; each seen red.
- The reading by another model (Claude Sonnet) found the carry-over between machines' consoles, fixed with its test,
  and a master shared in another form, fixed with its test. Declined: comparing the card's login with the
  organization's login, since the card's key is the person's own card key whatever login it names, and root takes
  that key. Noted and not built, as a yellow: a test of the press's second ask; whose key root takes changes only
  with the machine's next follow, whatever the window offers.
