# F576 — The Organization's Pages Read The Token's State Anew

```json
{
  "$schema": "issue-1.json",
  "id": "F576",
  "title": "The Organization's Pages Read The Token's State Anew",
  "state": "Backlog",
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
