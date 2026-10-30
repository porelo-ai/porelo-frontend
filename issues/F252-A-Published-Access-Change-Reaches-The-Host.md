# F252 — A Published Access Change Reaches The Host

**Status:** Accepted.
**Size:** S - the access bundle made at publishing is uploaded to the admin's setup folder on the host before the sync runs.

**What must be true.** After *Developers* publishes an access change, the host's sync verifies exactly the access commit just pushed. The bundle `ProjectDevelopers._change` makes is uploaded to the admin's `~/.local/share/porelo-host/setup/<project>/access.bundle` on the host, which `porelo-host-person sync` reads, before the sync is asked for. Only then is the temporary bundle deleted. This holds for every change the dialog publishes: adding a developer, adding or dropping a machine, and removing a developer. An upload that fails stops before the sync, says so, and leaves the change pending, so *Retry* uploads again.

## Why

Operator's walk 23 on VM A (2026-10-30): the dialog made `access.bundle` in a temporary folder and deleted it (`lib/src/app/project_developers.dart`, `commitPushAndBundle` then `temporary.delete`). Nothing uploaded it, so the sync verified the old access commit (96818f8 while GitHub had f01b5cd, then 40f59d1). The coordinator rebuilt the bundle on the host from GitHub by hand and synced, again at every later change (dropping `l2` in 10-10, removing walkdev in 11-1).

## Plan

- `_change` uploads the bundle through the same ssh boundary the sync uses, under the admin's account, written to a temporary name then moved into place, mode `0600`.
- The upload is part of the pending sync, so *Retry* repeats upload and sync together.
- **Red first:** a test with a fake host that the sync is asked for only after the bundle with the pushed commit is on the host; a test that a refused upload asks no sync and keeps *Retry*.

## Acceptance

- Adding a developer and publishing shows the host's answer with `access_commit` equal to the pushed commit, with nothing done by hand on the host.

## Test

Only the change: the tests above and `project_developers`' own tests. On VM A: one publish whose sync names the new access commit.

## Estimate

`F252 size=S est=15 basis=median S 15 (F155 F156 F160 F168 F173 F176 F221 F223 F224 F226 F228, 11 records)`

## Deferred

- Preserve pending upload and sync recovery across closing and reopening Developers, including the retained private bundle's lifecycle.
- Reset `_bundleReady` before rebuilding a missing bundle (`project_developers.dart` ~367), so a rebuild that throws after writing the file is rebuilt again on the next Retry.
