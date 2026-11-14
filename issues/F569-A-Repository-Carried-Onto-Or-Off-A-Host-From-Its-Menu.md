# F569 — A Repository Carried Onto Or Off A Host From Its Menu

```json
{
  "$schema": "issue-1.json",
  "id": "F569",
  "title": "A Repository Carried Onto Or Off A Host From Its Menu",
  "state": "Backlog",
  "size": "M",
  "priority": "Medium",
  "rank": 40,
  "blockedBy": [],
  "covers": "A not-carried repository's menu on a machine's project page offers carrying it onto that machine, and a carried one's menu offers taking it off, as the machine page's repository row already does."
}
```

**Why this size.** Two menu entries, each a run on the host, and what porelo and porelo-host offer for them. Taking one off exists on the machine page already.

**What must be true.** A person who sees a repository on a machine's project page can move it onto or off that machine from there.

## Plan

An operator wish, not part of ST361. It waits for a Medium story.

- A not-carried repository's ⋮ offers *Carry it on this machine…*. What porelo must offer to take one repository onto
  a host is to be named with Agent Core.
- A carried repository's ⋮ offers *Take it off this machine…*, the same run as the machine page's repository row
  (`organization_host_pages.dart` ~1090).

## Acceptance

- Both entries with their runs and guards, each red first. Agreed with Agent Core what porelo offers for carrying one repository.
