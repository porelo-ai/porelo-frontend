# F269 — The Registry Read For Every List

**Status:** Accepted.
**Size:** M - the organisation's registry repository kept in a private checkout, read through Core, and the source of every person, host and admission list.

**What must be true.** The interface asks once for the organisation's registry repository (an `git@` or `https` address) and reads it with the person's own access: SSH through the agent, or a token from the vault through Core's credential helper. It keeps a private checkout, fetched at start and on *Refresh*. Every list of persons, hosts, admitted project admins and projects comes from Core's `registry read` of that checkout: each person with login, name, email, fingerprint and state (trusted, first seen, refused with why). A refused card is shown in red, naming the login and why, and is never offered. A commit Core refuses is named, and the last good state stays shown. The registry's `owners.yml` (its owners and the host admins) is shown as Core reads it, with who signed it; the "who may" lines take registry owners and host admins from it. Writes go through Core's `registry file`, never through the forge's contents API.

## Why

One-click joining from signed state (operator, 2026-10-30), building block 3: the state lies signed in Git on the central forge, and Porelo reads instead of asking.

## Plan

- `lib/src/app/registry_checkout.dart`, built as `access_checkout.dart` keeps the access repository (private folder, the person's git, signed commits).
- A model with the read answer, refreshed on fetch, for the pages ([F278](README.md#f278)) and the actions ([F271](README.md#f271), [F272](README.md#f272), [F273](README.md#f273)).
- The "who may" line: for an action the person may not do, the persons who may, each with *Write* (`mailto:`) and *Copy*.
- **Red first:** a test that a refused card is never offered in a pick list; a test that a refused commit keeps the last good state and names it.

## Test

Only the change: tests against a fake Core and a local bare repository. No VM run.

## Estimate

`F269 size=M est=60 basis=median M 61 (24 records)`
