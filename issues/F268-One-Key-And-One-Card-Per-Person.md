# F268 — One Key And One Card Per Person

**Status:** Accepted.
**Size:** M - the person's one Ed25519 key made at first start, their card filed in the registry, the key changed or replaced when lost, and a backup key for a single project admin.

**What must be true.** At first start the interface has Core make the person's one Ed25519 SSH key, kept in their KeePassXC file and served by its SSH agent, and their card (login, name, optional email, key, created, expires). *File my card* commits `people/<login>.card` to the registry when the person may write there; otherwise it names who may, with their email (Write, Copy). *Change my key* runs Core's rotation and shows, per registry and host, whether the new card arrived (done, pending, refused) with Retry. *I lost my key* says plainly that the person's vault on each host is deleted and made again and the agents' sign-ins are made once more, lists those hosts and does it on one confirmation; a host vault that answers "made with another key" leads to the same offer, never to "wrong passphrase". A project with a single project admin and no backup key is warned about, with *Make a backup key…*, which runs Core's `identity backup-key`, opens the folder of the written file and says to keep it offline. No private key is shown, logged or put on a command line.

## Why

One-click joining from signed state (operator, 2026-10-30), building block 1 and the decisions on a lost key and the backup key (operator, 2026-10-30).

## Plan

- An *Identity* place under Settings (the pages' layout is [F278](README.md#f278)): the own card, fingerprint, the three actions and their published rows.
- Calls Core's `identity` verbs only; the interface makes and signs nothing itself.
- **Red first:** a test that a lost-key confirmation lists the hosts and runs Core's clear and init per host; a test that a single-admin project without a backup key shows the warning.

## Test

Only the change: widget and app tests against a fake Core. No VM run.

## Estimate

`F268 size=M est=60 basis=median M 61 (24 records)`
