# F575 — A Carried Credential Seen End To End

```json
{
  "$schema": "issue-1.json",
  "id": "F575",
  "title": "A Carried Credential Seen End To End",
  "state": "Backlog",
  "size": "S",
  "priority": "High",
  "rank": 20,
  "blockedBy": [],
  "covers": "Story ST362: carrying a credential from this computer to a host is held by a feature scenario across two stand-in machines and checked once against porelo with B774 and B775."
}
```

**Why this size.** The feature world gains a second machine's backend; the window's code is [F572](README.md#f572)'s.

**What must be true.** The carry is held from the row's button to the host's providers read again.

## Plan

Left from [F572](README.md#f572).

- The feature world has one backend. A second stand-in machine, which carries credentials, lets one scenario press
  *Import from this computer…* on a host's row, pick a source, carry it, and see the host's provider authenticated.
- Once B774 and B775 are on porelo's main, the wire shapes are compared with the interface file, and the client is
  corrected where they differ.

## Acceptance

- The scenario, red first; the wire shapes match porelo main.
