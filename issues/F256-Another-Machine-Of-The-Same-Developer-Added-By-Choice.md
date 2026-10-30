# F256 — Another Machine Of The Same Developer Added By Choice

**Status:** Accepted.
**Size:** S - the Developers dialog's machine step names what a person adds (a machine's VPN and SSH keys), lists the machines already added, and offers adding another or going on as one clear choice.

**What must be true.** In *Add developer* and *Change developer*, the step that takes a developer's keys is called *Machines*, not *Laptops*: an entry is one machine's VPN peer and SSH key, whatever the machine is. After a machine's keys and address are taken, the step lists the machines added so far, each with its address and a *Remove this machine* action, and offers two buttons of equal weight: *Add another machine of this developer* and *Next*. No label says "keep". The words in the dialog and its refusals say "machine" throughout. A refusal stands in the dialog ([F255](README.md#f255) is built with this).

## Why

Operator's walk 23 (2026-10-30), *Add developer*, Step 3 of 5, and step 10-10: "Keep laptop and add another" was not understood and far too small, a text button below the address field. It was unclear why he should "keep" his laptop. "Remove laptop…" confused the same way, and a developer's entry is a VPN peer plus an SSH key, not necessarily a laptop.

## Plan

- `lib/src/ui/project_developers_dialog.dart`: the step's title, labels, the list of added machines, the two-button choice; every user-facing "laptop" of the dialog becomes "machine". The access file's keys and the host's `laptops_*` fields are not renamed.
- **Red first:** a widget test that after one machine the step shows the list and the two buttons and no "Keep" label; a test that *Add another machine of this developer* clears the key fields and proposes the next address.

## Test

Only the change: the tests above and the dialog's own tests. No VM run.

## Estimate

`F256+F255 size=S est=20 basis=median S 15 (11 records) + XS 10 (8), less one shared build and review`
