# F260 — The Join Log Without Ansible's Noise

**Status:** Accepted.
**Size:** XS - the join's run has no "no provider … is declared" note and no Ansible localhost warnings in its log.

**What must be true.** The join's log shows its own steps and real failures. Ansible's `[WARNING]` lines about localhost and the empty inventory, and the "no provider … is declared" note, are not in it: what causes them is set so they do not arise. A real warning still shows.

## Why

Walk 23, step 9-6 (2026-10-30): the join log showed a "no provider … is declared" note and Ansible's localhost `[WARNING]` lines, which looked like failures.

## Plan

- Find each line's source. Where the interface starts the run (`lib/src/app/project_join.dart`), give the run an explicit local inventory and `ANSIBLE_LOCALHOST_WARNING=False`. The "no provider" note: if the join asks for a provider it does not use, it stops asking; if the line is the host collection's, it goes to Agent Machines as theirs.
- **Red first:** a test that the join's run carries the inventory and environment.

## Test

Only the change: the test above. On VM B: one look at a join log.

## Estimate

`F260 size=XS est=10 basis=median XS 10 (8 records)`
