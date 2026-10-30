# F273 — A Developer Joins At One Click

**Status:** Accepted.
**Size:** S - "in project P on host X" shown from the access files, and *Join* following the project and opening the tunnel.

**What must be true.** A person named in a project's access file, which they find through `hosts/<host>/access.yml`'s access repository addresses, sees "in project P on host X" and *Join*. One click follows the project (verified by its signers), writes the host's ssh config and opens the tunnel ([F270](README.md#f270)). Nothing is pasted or typed. A project whose access file cannot be read is said, naming the repository and who may grant it.

## Why

One-click joining from signed state (operator, 2026-10-30), the flow's step 6.

## Plan

- Replaces today's join wizard; the join's own-account setup on the host is porelo-host's.
- **Red first:** a test that an access file naming the person shows *Join*, and that one click follows and opens the tunnel.

## Test

Only the change: tests against a fake Core. One VM check once porelo-host admits by the card's key.

## Estimate

`F273 size=S est=15 basis=median S 15 (11 records)`
