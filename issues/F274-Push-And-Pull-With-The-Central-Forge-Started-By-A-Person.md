# F274 — Push And Pull With The Central Forge Started By A Person

**Status:** Accepted.
**Size:** S - the gathered push and the pull from the central forge started on purpose from the project, with the person's own token sent through the tunnel.

**What must be true.** A person admitted to push sees *Push the approved main…* and *Take the central state…* on the project. Each runs porelo-host's push or pull on the host with the person's own token on standard input through the tunnel, read from their vault without asking, never written on the host, never on a command line. The answer is shown in the host's words.

## Why

One-click joining from signed state (operator, 2026-10-30), building block 3: the central forge's token never lies on the host.

## Plan

- **Red first:** a test that the token reaches only standard input of the host's command and no argument or log.

## Test

Only the change: the test above. One VM check with porelo-host's push.

## Estimate

`F274 size=S est=15 basis=median S 15 (11 records)`
