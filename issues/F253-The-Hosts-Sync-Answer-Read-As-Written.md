# F253 — The Host's Sync Answer Read As Written

**Status:** Accepted.
**Size:** XS - `DeveloperSyncAnswer.read` takes the host's `unchanged` as the boolean the host writes.

**What must be true.** The dialog reads every answer `porelo-host-person sync` gives: `unchanged` is a boolean, `true` when the project and access commits were already applied, with empty `added`, `dropped`, `laptops_added` and `laptops_dropped`. The dialog then confirms the published change by the answer's `access_commit`. A developer the answer does not name shows as "unchanged at last sync" when the answer says `unchanged: true`, else "not reported by last sync".

## Why

The host answers `"unchanged": true` (and `false` after a change), whereas `DeveloperSyncAnswer.read` (`lib/src/app/project_developers.dart`) requires `unchanged` to be a list of account names. Every answer is treated as malformed and the dialog says "The host sync did not confirm the published access change", even when the sync ran.

The boolean is the host's contract: its own timer play reads it (`changed_when: not (... | from_json).unchanged` in porelo-host's `roles/porelo/tasks/own_sync.yml`), and its unit and molecule tests check it. So the interface changes, not the host.

## Plan

- `unchanged` is read as a `bool`; anything else is refused as before. `true` with any non-empty list is refused.
- `state(account)` uses it as above; nothing else in the dialog changes.
- **Red first:** the two answers the host writes (`porelo-host-person`, both return shapes) read without refusal; `"unchanged": ["a"]` refused.

## Test

Only the change: the tests above. No VM run; the walk already showed the host's answers.

## Estimate

`F253 size=XS est=10 basis=median XS 10 (8 records)`
