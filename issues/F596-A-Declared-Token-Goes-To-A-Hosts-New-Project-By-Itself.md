# F596 — A Declared Token Goes To A Host's New Project By Itself

```json
{
  "$schema": "issue-1.json",
  "id": "F596",
  "title": "A Declared Token Goes To A Host's New Project By Itself",
  "state": "Backlog",
  "size": "S",
  "priority": "High",
  "rank": 116,
  "blockedBy": [],
  "covers": "Where a host this person administers waits for their forge token for a project, and this computer's Porelo-Vault declares a token for that forge and organization, the window hands it on by itself, once per wait, as the setup's token step already can; it asks only where no declared token is found or one handed on did not help."
}
```

**Why this size.** S: the hand-over without the page exists (`HostTokenStep.giveAtOnce`, `_giveHostTokenNow` with
`atOnce`); what is new is starting it by itself where a host is heard waiting for a project, once per wait and never
twice at once, the placing dialog and the rows saying it, and tests of the declared, not declared and still waiting
cases.

**What must be true.** A Machine Admin who gave a host their token at its setup, from a token their Porelo-Vault
declares, is not asked again when a project is put on that host: the window hands the same declared entry on, Porelo
handing it over without the window reading it, and says that it did. The host still keeps no token.

## Found

The operator's second live test on a rented host (window snapshot.418, porelo snapshot.553): at the host's setup the
token step showed this computer's Porelo-Vault declaring the organization's token for the GitHub organization, and
the host took it. *Put porelo on <host>* then asked again: *<host> has no account at GitHub and keeps no token, so it
needs your GitHub token once for porelo … Give it my GitHub token…*, and the project's row said *waits for your
GitHub token: The host needs the person's forge token once per new repository to add its read key and copy it; the
host keeps no token.*

## Decision

The operator's word (2026-11-15): the window hands the token on from the Porelo-Vault where the Vault declares one for
the forge and organization, and asks only where no source holds one. Taking the project's repositories at the host's
setup is out: a host is set up before any project is put on it.

- The declared entry is the person's own statement that this token serves that forge and organization, and Porelo
  hands it on (`porelo org host refresh <host>`) without the window ever reading it; the kept token and the secrets
  file stay a choice made on the token's page, which opens where nothing is declared.
- Nothing is needed of Agent Core: the host asking per new repository stays. To be checked with Agent Core: whether
  one `org host refresh` serves every project the host waits on at once, so one hand-over per host and not per
  project is enough.

## Plan

- **Today**, read in the code:
  - `PlacingProjectDialog` (`lib/src/ui/placing_project_dialog.dart`) says `organizationTokenWords` and offers
    *Give it my … token…*, which calls `onGiveToken(host, atOnce: true)` only on the press.
  - `_giveHostTokenNow` (`lib/src/ui/shell.dart`) with `atOnce` gives the declared entry through
    `HostTokenStep.giveAtOnce` and opens the token's page only where none is declared; `TokenGiving` keeps it to one
    at a time per host.
  - The project's row and the machine's page (`waitingWords`, `giveTokenCommand`, `organization_host_pages.dart`)
    show the wait and the button, and nothing starts by itself.
- **Steps.**
  - In the shell, where a host this person administers is heard waiting for their token for a project
    (`HostProjectProgress.waitsForToken`), give at once through `_giveHostToken(host, atOnce: true)` once per host
    and wait: a wait already answered by a declared hand-over is not answered again by itself, so a token that did
    not help is not handed on in a loop.
  - `giveAtOnce` without the page where nothing is declared: a self-started hand-over that finds no declared entry
    opens no dialog, and the row and the placing dialog ask as today.
  - The placing dialog starts the same hand-over when it hears its project wait, shows it running (*Handing on the
    token your Porelo-Vault declares for <forge>…*), and after it says either that the host has the token and takes
    the project, or the button with why, as today.
  - The project's row says *handed your <forge> token on from this computer's Porelo-Vault* while the host has not
    yet taken the project.
- **Red first:** a widget test of the placing dialog with a stand-in source declaring the token and a host waiting
  for the project, red today (the button waits for a press); a shell test that a heard wait gives once and not again.

## Acceptance

- A project put on a host that waits for the person's token, where the Porelo-Vault declares one for its forge and
  organization, is handed it without a press, and the placing dialog and row say so. Seen to fail: today's dialog
  asks.
- With no declared token, or after a declared one did not help, the dialog and row ask as today, the token's page
  naming each source; no hand-over repeats by itself.
- Two waits heard together for one host give once at a time (`TokenGiving`).

## To be checked

- With Agent Core: one `org host refresh` serves every project waiting on the host.
