# F511 — An Open Menu Follows What Can Run

```json
{
  "$schema": "issue-1.json",
  "id": "F511",
  "title": "An Open Menu Follows What Can Run",
  "state": "Review",
  "size": "S",
  "priority": "Medium",
  "rank": 84,
  "blockedBy": [],
  "covers": "An entry of an open command menu turns runnable or greyed out as its view's state changes, instead of keeping what it was when the menu opened."
}
```

**Why this size.** S: the command menu's entries drawn from a listenable of the view's commands while the menu is open,
and a widget test per direction.

**What must be true.** A person who opens a command menu while the view is still reading or changing sees each entry
become runnable as soon as it can run, and a runnable entry greyed out as soon as it no longer can, without closing and
opening the menu again.

## Why

`commandMenuEntries` (`lib/src/ui/command_menu.dart`) builds the `PopupMenuItem`s once, when the menu opens, from the
`Command`s of that moment. The Credentials menu (`lib/src/ui/connections_view.dart`) greys out adding and forgetting while
the connections are read or changed (`unavailable: 'Still reading or changing the connections.'`). After a key is sent
into the vault the window reads the connections again at once, so a person who opens the menu then gets a grey Forget
that stays grey after the read has ended; the tap on it does nothing. The leased-machine test of forgetting a key went
red on exactly this (Build 43297466833); the test now waits before opening the menu, the person cannot.

The reverse holds too: an entry runnable at opening stays drawn runnable after the view turned busy, and runs into a
change already under way.

## Plan

- `CommandMenu` keeps the commands its view gives it now in a `ValueNotifier`, set after the frame in which the view
  rebuilt it, and each entry of its open menu is drawn from it (`ValueListenableBuilder`), so `PopupMenuButton`'s route
  redraws it. The menu stays open; only the entries change. An entry whose command is gone since is drawn grey and
  runs nothing; choosing runs only a command available now, as before.
- Every view rebuilds its `CommandMenu` as its state changes already, so every `CommandMenu` follows without a change at
  its call site; no model is passed. The right-click menu (`showCommandMenu`) is drawn once, as before.
- Red first in `test/ui/connections_menu_test.dart`: open the menu while busy, then end busy and pump: the forget entry
  is enabled and a tap calls `onForget`. And: open while idle, turn busy, pump: the entry is disabled and a tap calls
  nothing.

## Acceptance

- With the Credentials menu open during the re-read after storing a key, Forget turns runnable when the read ends, and
  choosing it forgets the connection.
- An entry that becomes unavailable while the menu is open is drawn as unavailable with its reason, and choosing it runs
  nothing.

## Estimate

`F511 size=S est=15 basis=median S 15 (11 records)`
