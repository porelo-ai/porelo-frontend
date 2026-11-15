# F596 — A Declared Token Goes To A Host's New Project By Itself

```json
{
  "$schema": "issue-1.json",
  "id": "F596",
  "title": "A Declared Token Goes To A Host's New Project By Itself",
  "state": "Review",
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
- Nothing is needed of Agent Core: the host asking per new repository stays. One `org host refresh` serves every
  project the host waits on at once, so one hand-over per host is enough (Agent Core's answer, under *Plan*).

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
- **Agent Core's answer** (to the question that stood under *To be checked*): one `porelo org host refresh <host>`
  serves every project the host waits on in that pass, so one hand-over per host. Its limits: the pass is bounded at
  300 s, so a project or repository not reached stays waiting for the token and needs a second refresh; with no project
  waiting, the host refuses the token with exit 65 (*no project waits for a token*), so it is sent only while a wait
  shows and 65 is nothing to do; and what still waits is read from the host's answer afterwards rather than assumed
  gone. The window never reads or logs the token: the declared path hands it on through Porelo.
- **Red first:** a widget test of the placing dialog with a stand-in source declaring the token and a host waiting
  for the project, red today (the button waits for a press); a shell test that a heard wait gives once and not again.

## Acceptance

- A project put on a host that waits for the person's token, where the Porelo-Vault declares one for its forge and
  organization, is handed it without a press, and the placing dialog and row say so. Seen to fail: today's dialog
  asks.
- With no declared token, or after a declared one did not help, the dialog and row ask as today, the token's page
  naming each source; no hand-over repeats by itself.
- Two waits heard together for one host give once at a time (`TokenGiving`).

## Built

- **Once per wait:** `DeclaredHandOn` (`lib/src/app/declared_hand_on.dart`) hands a host the declared token for the
  projects heard waiting, joins a hand-over to that host that runs already, and never hands on again by itself for a
  project it was handed on for; a project heard waiting later is a new wait. Outcomes: handed on, not declared,
  nothing waits, answered before, refused with words.
- **Shell:** `_handOnDeclaredTokens` (`lib/src/ui/shell.dart`) listens to the host connections and the organization,
  and for each host this person administers whose word (as the machine's own list corrects it) has a project waiting
  for the token calls `forWaits`. `_handOnDeclaredNow` runs as one of `TokenGiving` (`run`, new, never beside another
  giving to that host) and uses `HostTokenStep.handOnDeclared` (new, `lib/src/app/host_token_sources.dart`), which
  connects and asks only this computer's Porelo-Vault (`HostTokenSources.askDeclared`): nothing opens, no other source
  (the kept token, the secrets file) is touched without a press. The declarations are read from the shell's
  `thisComputer` backend, the same socket as before, which tests replace.
- **Exit 65:** `OrganizationRefused.exitCode` (new), set from Porelo's exit; `_giveTokenFrom` answers
  `noTokenWaitedWords` for 65, which the self hand-over takes as nothing to do and a press says as words.
- **What still waits:** after a hand-over the token step asks the host again (`tokenTaken`, as before), and the
  placing dialog reads the host's progress again: a project still waiting was not helped, and is asked for as before.
- **Placing dialog:** `HostConnections.handOnDeclared`, set by the shell, is called once when the dialog hears its
  project wait; while it runs the dialog says *Handing on the token your Porelo-Vault declares for <forge> to
  <host>…* with no button, then the host's word; with nothing declared the button stays, and a token that did not help
  says *<host> still waits for a token after the one your Porelo-Vault declares…* with the button.
- **Row:** the project's row (`_waitWords`) says *handing your <forge> token on from this computer's Porelo-Vault*
  while the hand-over runs.
- **Tests:** `test/ui/placing_project_dialog_test.dart` (*handed the declared one without a press, and says so*; *a
  declared token not found, or not helping, leaves the button as before*), `test/ui/declared_token_hand_on_test.dart`
  (*handed the declared one by itself, once per wait*; *where nothing is declared, nothing is handed on and nothing
  opens*), `test/app/declared_hand_on_test.dart` (once, joined, a new project a new wait, per host),
  `test/app/porelo_organization_source_test.dart` (*keeps the exit code that says so*); the fixture organization
  takes an `address`.
- **Red:** the dialog `Expected: ['build demo']  Actual: []` and no *still waits … after the one your Porelo-Vault
  declares*; the shell test on the unchanged `lib/` `Expected: ['build']  Actual: []`. `DeclaredHandOn`'s own test
  is new with its class, so it was not seen red.
- **Runs** (one file at a time): `dart analyze lib test integration_test tool` No issues found.
  `placing_project_dialog_test` 17, `declared_token_hand_on_test` 2, `declared_hand_on_test` 1, `token_giving_test` 1,
  `machine_own_pages_test` 27, `organization_host_pages_test` 126, `organization_project_pages_test` 91,
  `organization_carry_choice_test` 6, `repository_on_the_machine_test` 18, `porelo_organization_source_test --plain-name
  token` 2: all passed.

## To be checked

- A project not reached in the 300 s pass stays waiting and is not handed on again by itself: its row and the placing
  dialog ask with the button, and a press refreshes again. Whether the window should hand on once more where the host's
  answer says it ran out of time is not built.
- The self hand-over connects to the host as the token's page does on a press; it was not walked against a real host.
