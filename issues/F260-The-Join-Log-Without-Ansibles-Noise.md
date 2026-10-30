# F260 — The Join Log Without Ansible's Noise

**Status:** Accepted.
**Size:** XS - the join's run has no "no provider … is declared" note and no Ansible localhost warnings in its log.

**What must be true.** The join's log shows its own steps and real failures. Ansible's `[WARNING]` lines about localhost and the empty inventory, and the "no provider … is declared" note, are not in it: what causes them is set so they do not arise. A real warning still shows.

## Why

Walk 23, step 9-6 (2026-10-30): the join log showed a "no provider … is declared" note and Ansible's localhost `[WARNING]` lines, which looked like failures.

## Plan

- Find each line's source. `lib/src/app/project_join.dart` delegates the run to `ProjectBring.joinUploaded` in `lib/src/app/project_bring.dart`; give only that join run an explicit local inventory and `ANSIBLE_LOCALHOST_WARNING=False`. The "no provider" note: if the join asks for a provider it does not use, it stops asking; if the line is the host collection's, it goes to the host collection's responsible role.
- **Red first:** a test that the join's run carries the inventory and environment.

## Test

Only the change: the test above. On VM B: one look at a join log.

## Source trace

- Without an explicit inventory, Ansible's inventory parser warns when no source is parsed, and its CLI warns when the host list is empty. The join launcher supplies `ANSIBLE_STDOUT_CALLBACK=porelo.host.lines`, `-c local`, `-i localhost,`, and `ANSIBLE_LOCALHOST_WARNING=False`; real warning and failure output is retained.

## Deferred

- The provider note is Core's `apps/app-vault/src/main/java/org/fuin/porelo/app/VaultPutCommand.java:333`, printed at line 457; the host collection's `roles/porelo/files/porelo-host-stop:382` calls `porelo vault put` for project keys, and line 386 does so for identities, leaving stderr visible. Resolution belongs to Core and the host collection.
- The VM B join-log check is not run: this round permits no commands on a host.
- Existing machine-specific home paths in `doc/walks/19-sprints-6e-to-6i-a-rented-server.json`, `doc/walks/21-sluice-tried-on-this-laptop.json`, and `tool/walk_on_this_laptop.sh` are outside this issue's scope.
- The join test asserts the two settings by substring only; a broader warning suppression or a stderr redirect would still pass (`test/app/project_join_test.dart` ~535).

## Estimate

`F260 size=XS est=10 basis=median XS 10 (8 records)`
