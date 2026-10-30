# F263 — The Give-Back Confirmation Says What Is Lost

**Status:** Accepted.
**Size:** XS - *Take the server down?* shows only the server's name and what is lost, and keeps still while shown.

**What must be true.** The confirmation of taking a server down names the server and says what is lost (the server, its disk, the projects on it, and its VPN on this computer). It shows none of the host's public values (address, keys, `ca_sha256`) and no copy buttons. Its layout does not change while it is open.

## Why

Operator's walk 23, step 12-15 (2026-10-30): the confirmation showed the host's public values with copy buttons, and the list jumped while shown.

## Plan

- The confirmation in `lib/src/ui/` (server page's take-down) gets its own fixed content; the public values stay only where they are copied for a bring.
- **Red first:** a widget test that the confirmation shows the name and the loss sentence and no public value; a test that it keeps its size across the host's refreshes.

## Test

Only the change: the tests above. No VM run.

## Estimate

`F263 size=XS est=10 basis=median XS 10 (8 records)`
