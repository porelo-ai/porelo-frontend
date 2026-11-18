# F613 — Removing a Machine Removes Its SSH Files

```json
{
  "$schema": "issue-1.json",
  "id": "F613",
  "title": "Removing a Machine Removes Its SSH Files",
  "state": "Backlog",
  "size": "XS",
  "priority": "Medium",
  "rank": 133,
  "blockedBy": [],
  "covers": "When a person removes a machine from My machines, the window removes the three SSH files it wrote for that machine's card, as it does when an organization's machine goes away; files that hold anything else stay"
}
```

**Why this size.** XS: `Machines._forget` (`lib/src/app/machines.dart`, around line 943) calls `tunnels.dropFor`.
The organization's paths call `tunnels.dropAndUnpublish`, which also removes the files when they still hold exactly
the card's bytes. One unit test.

**What must be true.** A machine a person removed leaves nothing behind that stops a later machine of the same name
from being set up.

## Found

On 2026-11-17, after a live test. The window's SSH folder held the `.conf`, `.conf.known_hosts` and `.conf.pub` of
seven machines no longer in the window's list, from rentals given back days before. A machine set up again under a
reused name stops on such files ([F611](README.md#f611)).

## Plan

- Today: `_forget` drops the machine's tunnel and keeps its card's files.
- Change: `_forget` calls `tunnels.dropAndUnpublish` for a machine with a card. `unpublish` already leaves files that
  do not hold exactly the card's bytes.
- Red first: a test that adds a card machine, publishes its files, and removes the machine. Today the three files stay;
  after the change they are gone. A file changed by hand stays.

## Acceptance

- Removing a card machine removes its three SSH files.
- A file that holds anything else is left.
- The test above fails without the change.
