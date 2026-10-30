# F236 — Root Reached On A Rented Server

**Status:** Idea. Held as an Idea (operator, 2026-10-30, after walk 23): wizard changes wait until he has gone through the whole flow again.
**Size:** S - root's login allowed in the rental's cloud-config, and the "login as" answer refused at once with words that name it.

**What must be true.** A server prepared with no project (`up --host-name … --login-user root`) on Scaleway's Ubuntu takes the person's key for root, so *Wait for the server to accept SSH* ends as soon as sshd answers. Where a server still refuses root with "Please login as the user …", `up` stops at once on that answer and says which user the image offers, instead of waiting out its twenty minutes.

## Why

Operator's walk 23, step 2-7 (2026-10-30): `up --login-user root` waited 18 minutes in *Wait for the server to accept SSH* on a ready host. Scaleway's Ubuntu 26.04.1 install writes `/etc/cloud/cloud.cfg.d/92-scaleway-baremetal.cfg` with `disable_root: True`. So root's `authorized_keys` holds only `Please login as the user "ubuntu" rather than the user "root".`, and the ssh loop in `host_run.dart` asks again until `sshWithin`, because `_keyRefused` knows only "Host key verification failed".

Root is the login only of the server-only path, since [F211](README.md#f211) on 2026-10-29. A project's host logs in as `ubuntu`, the default.

## Plan

- `_create`'s cloud-config gains `disable_root: false`, so cloud-init gives root the person's key. User data outranks `/etc/cloud/cloud.cfg.d`.
- The ssh wait stops at once when ssh's answer holds `Please login as the user "<name>"`, and reports: "The server refuses root; its image offers <name>. Nothing was changed on it." The words name the user it read.
- **Red first:** a test that the cloud-config carries `disable_root: false`; a test with a remote stand-in answering the "Please login as" line, where `up` ends at once with those words and does not wait.

## Test

Only the change: the two tests above, and `porelo_host`'s own tests. No VM run: the cloud-config takes effect only on a real rental, so it is seen on the next walk's rental.
