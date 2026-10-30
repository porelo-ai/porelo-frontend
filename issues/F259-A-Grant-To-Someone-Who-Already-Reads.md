# F259 — A Grant To Someone Who Already Reads

**Status:** Accepted.
**Size:** XS - the Developers dialog reads a login's access to the repository before granting, and takes "already reads" as done.

**What must be true.** When a developer's forge login already has read (or more) on the access repository, publishing them shows "already has read access" and grants nothing. Only a login with no access is granted. A forge error is said in the forge's words with the call that failed.

## Why

Walk 23, steps 8-x (2026-10-30): GitHub answered 500 to the grant for a user who already had read access.

## Plan

- `collaborators.grantRead` first reads the collaborator's permission (`GET /repos/{owner}/{repo}/collaborators/{user}/permission`); `read`, `triage`, `write`, `maintain` or `admin` is done.
- **Red first:** a fake GitHub that answers 500 to a second grant and `read` to the permission read: the dialog shows "already has read access" and calls no grant.

## Test

Only the change: the test above. No VM run.

## Estimate

`F259 size=XS est=10 basis=median XS 10 (8 records)`
