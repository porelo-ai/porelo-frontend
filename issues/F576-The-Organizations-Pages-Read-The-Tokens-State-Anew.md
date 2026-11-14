# F576 — The Organization's Pages Read The Token's State Anew

```json
{
  "$schema": "issue-1.json",
  "id": "F576",
  "title": "The Organization's Pages Read The Token's State Anew",
  "state": "Review",
  "size": "S",
  "priority": "High",
  "rank": 21,
  "blockedBy": [],
  "covers": "Story ST361: the organization's own project and machine pages stop saying a machine waits for the token once its Porelo answers the project carried, without a restart."
}
```

**Why this size.** Two pages of the organization and the one answer they read; the reconciling with Porelo's word
exists already for the machine's project page.

**What must be true.** The organization's project page and its machine page say what the machine's Porelo says now
of the token, as the machine's own project page does since [F570](README.md#f570).

## Plan

- `projectWaits` in `organization_token_words.dart`, which the organization's project page, its dialogs and its list
  read, and `organization_host_pages.dart`, the organization's page of a machine, read only what the machine said as
  root (`HostConnections.heard`). That answer is asked once per connection and kept until a reconnect or a Refresh, so
  a token wait the machine has ended since stays on those pages, with *Give token* and refused work: the harm
  [F570](README.md#f570) removed from the machine's project page.
- Read the root answer there through the same reconciling the machine's project page uses
  (`HostProgress.asListedBy`, the later read standing), with the project list of the machine the card names, where
  this window watches it.
- Red first: a widget test on each page with a machine whose root answer says `waiting-for-token` and whose Porelo
  lists the project `carried` afterwards; neither page may say it waits or offer the token, and no root login more.

## Acceptance

- Both tests red before the change and green after; the organization page tests green.

## Built

- **Cause:** as found, every page of the organization read the root answer through `HostConnections.heard`, which
  only the machine's own project page reconciled with what the machine's Porelo lists.
- `HostConnections.heard` now does the reconciling itself (`HostProgress.asListedBy`, the later read standing) with
  the project list of the machine the host's card names for this person, which the window hands it (`listedOn`, set
  by the shell). So every reader of it follows: `projectWaits` (the organization's project rows, dialogs and list), the
  organization's machine rows and machine page, and the machine's own pages, which no longer reconcile a second time.
  The root answer kept stays as it was said; no root login is added.
- Tests in `test/ui/machine_own_pages_test.dart`, both red before the change: *a project its machine's Porelo answers
  carried no longer waits in the organization's projects* and *a project its machine's Porelo answers carried no
  longer waits on the organization's machine row*.
- The list is taken only from the one machine whose card is the organization's machine as the connection knows it
  (address, port and host key, `HostConnections.isTheMachine`), under this person's login (`cardMachineOf`); where
  none or several are, nothing is read into the root answer. `test/app/card_machine_test.dart`, both red first; and
  *a card that is not the organization's machine any more reads nothing into its word*, red first. The window itself
  refuses a second machine under a card's name, so two such machines cannot be listed at once.
- A machine's own page takes its own Porelo's list again, whatever login its card names the host under: *a machine's
  own page under another login takes its own Porelo's word on the token*, red first.
- The organization's pages follow a list read anew: the shell tells the connections when a card's machine read its
  projects (`listedAnew`), and their listeners redraw. *a list read anew is followed by the organization's row, with
  nothing else changed*, red first; *a list read before the machine's answer leaves the organization's row waiting*,
  seen red without the guard on when each was read.
- `heard` answers the same object while neither the root answer nor the list changed, and the machine page's *Give
  token* tells an answer heard since by the root answer itself (`heardAsSaid`), never by the reconciled one: *a press
  that gave no token asks the machine, though its Porelo's list stands in part of its word*, red first.
