# F622 — A Machine Page That Says How Each Part Stands

```json
{
  "$schema": "issue-1.json",
  "id": "F622",
  "title": "A Machine Page That Says How Each Part Stands",
  "state": "Estimated",
  "size": "S",
  "priority": "High",
  "rank": 5,
  "blockedBy": [],
  "covers": "A machine's page shows one line per part (state, short summary, a link to its page), and the lists move to the parts' pages"
}
```

**Why this size.** S: the two machine pages lose their lists and gain one row per part, over the per-part summary
the tree reads already.

**What must be true.** A machine's page says in one line per part (Porelo, Forge, Matrix and the others it has) how
each stands, with a short summary and a link to the part's page; what waits is read on the part's page, never twice.

## Plan

- `lib/src/ui/organization_host_pages.dart` (`OrganizationHostPage`) and the plain machine page (`_machineFacts`,
  `_managingPage` in `lib/src/ui/shell.dart`): a part row each, from the same `PartState` the tree shows
  ([F618](README.md#f618)); *Open its forge* moves to the Forge page ([F619](README.md#f619)).
- The projects list stays where the machine page shows it today; the lists that belong to a part move to its page.
- Tests, widget level: a row per part with its state, an unknown part shown as unknown (harm: a part not read reads
  as fine).
