# F249 — The Restored Identity Filled On A Recorded Host

**Status:** Accepted.
**Size:** XS - the bring's and join's identity field filled with the identity this machine restored for the host, and a public key file refused there.

**What must be true.** On a host this machine has recorded, the bring's and the join's *Your SSH identity file* holds the identity restored for that host (`/run/user/<uid>/porelo-join-<host>/identity`) without being typed. A `.pub` file, or any file that is a public key, is refused in that field before anything connects: "This is a public key; the identity is its private half."

## Why

Operator's walk 23 on VM A (2026-10-30): the identity field took `/home/walkadmin/.ssh/walk6-signing.pub`, and the bring's ssh answered "Permission denied (publickey)", which did not say what was wrong.

## Plan

- The bring (`lib/src/ui/project_bring_dialog.dart`) and the join (`lib/src/ui/project_join_dialog.dart`) fill the field from `JoinKeys` for the recorded host, restoring the identity when it is not in the runtime folder yet, as the first bring does.
- The field's check refuses a path ending in `.pub` and a file whose first line is an OpenSSH public key.
- **Red first:** a widget test that a recorded host fills the restored identity; a test that a `.pub` file is refused with those words and nothing connects.

## Test

Only the change: the tests above and the dialogs' own tests. No VM run.
