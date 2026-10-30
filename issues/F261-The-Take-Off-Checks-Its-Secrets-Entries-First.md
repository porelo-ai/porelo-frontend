# F261 — The Take-Off Checks Its Secrets Entries First

**Status:** Accepted.
**Size:** XS - the take-off checks that the secrets file holds every entry it needs before the master password is used for the stop.

**What must be true.** Before *Take the project off* runs anything on the host, it checks under the one master password prompt that the secrets file holds every entry the take-off will feed (such as `shared/forge-central-token`). A missing entry is named, with the way to add it, and nothing is run on the host until it is there. No value is shown, logged or put on a command line.

## Why

Operator's walk 23, step 12-1 (2026-10-30): the take-off asked the master password, then failed with "no entry shared/forge-central-token" on the host admin's laptop.

Taking the project off from its own menu is [F267](README.md#f267), held as an Idea with the other GUI changes.

## Plan

- The take-off's feed (`lib/src/app/host_stop_feed.dart`) knows its acts' entries; the terminal run lists them with `keepassxc-cli ls` before the stop and stops with the missing entry's name.
- **Red first:** a test that a run whose file lacks `shared/forge-central-token` names it and starts no stop on the host.

## Test

Only the change: the test above and the feed's own tests. No VM run.

## Estimate

`F261 size=XS est=10 basis=median XS 10 (8 records)`
