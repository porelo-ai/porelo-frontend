# F623 — Central Forges Instead Of My Forges

```json
{
  "$schema": "issue-1.json",
  "id": "F623",
  "title": "Central Forges Instead Of My Forges",
  "state": "Estimated",
  "size": "S",
  "priority": "High",
  "rank": 6,
  "blockedBy": [],
  "covers": "My forges becomes Central forges and lists only central forges; a host's or this computer's own forge appears only under its machine"
}
```

**Why this size.** S: a label and a filter in two files with their tests; the host forges it drops are shown on their
machine's Forge page ([F619](README.md#f619)).

**What must be true.** The person's list of forges is *Central forges* and holds only the forges work is brought to
(GitHub and the like); a host's or this computer's own forge is shown only under its machine, never twice.

## Plan

- `lib/src/app/shell_model.dart`, `lib/src/ui/shell_rail.dart`, `lib/src/app/commands.dart`: *My forges* and *Your
  forges* become *Central forges*.
- `lib/src/ui/forges_page.dart`: lists `forges.entries` only, no longer `allEntries` (which adds `hostEntries`); the
  token a host's forge needs is handed on from its machine's Forge page, as it is reached today.
- Tests, widget level: a host forge set up through a tunnel is not listed under *Central forges* (harm: a host's forge
  is taken for central, or listed twice).

## To be checked

- Every place that reaches a host forge's entry through *My forges* today (the token's page, `hostEntries`), so none
  is left without a way in.
