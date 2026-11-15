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
  projects heard waiting and joins a hand-over to that host that runs already. A project's wait counts as answered only
  once a hand-over ran: the host took the token, Porelo said nothing waits (exit 65), Porelo or the host refused it,
  or the Porelo-Vault declares none. Until the host reports the project taken it is not handed on again by itself,
  whatever state it passes through (cloning, checking), and asking again answers what that hand-over came to
  (`HandOn.earlier`). `taken` takes the projects the host reports `carried` each time it is heard; a later wait of one
  of them (a repository added, say) is a new wait and handed on once more. A hand-over that could not run (`notRun`:
  the host not reached, the Porelo-Vault not asked, a press giving to that host meanwhile, the step busy) answers
  nothing; the next is tried for that host at most once per minute (`retryAfter`, clock injectable, the shell's read
  from `declaredHandOnClock`), and meanwhile the one that could not run is answered again as `earlier`.
- **Shell:** `_handOnDeclaredTokens` (`lib/src/ui/shell.dart`) listens to the host connections and the organization,
  and for each host this person administers that was heard (as the machine's own list corrects it) gives
  `DeclaredHandOn.taken` the projects it reports carried and, where any wait for the token, calls `forWaits`.
  `_handOnDeclaredNow` runs as one of `TokenGiving` (`run`, never beside another giving to that host; busy is
  `notRun`) and uses `HostTokenStep.handOnDeclared` (`lib/src/app/host_token_sources.dart`), which now answers
  `DeclaredGiving` (`given`, `refused`, `notDeclared`, `notRun`): it connects and asks only this computer's Porelo-Vault
  (`HostTokenSources.askDeclared`), so nothing opens and no other source (the kept token, the secrets file) is touched
  without a press. A step already giving or hearing, a Porelo-Vault that could not be asked, or a `give` that threw
  is `notRun`, never a hand-over with no words; only a refusal with words is logged as a warning. The declarations
  are read from the shell's `thisComputer` backend, the same socket as before, which tests replace.
- **Exit 65:** `OrganizationRefused.exitCode` (new), set from Porelo's exit; `_giveTokenFrom` answers
  `noTokenWaitedWords` for 65, which the self hand-over takes as nothing to do and a press says as words.
- **What still waits:** after a hand-over the token step asks the host again (`tokenTaken`, as before), and the
  placing dialog reads the host's progress again: a project still waiting was not helped, and is asked for as before.
- **Placing dialog:** `HostConnections.handOnDeclared`, set by the shell, is called once when the dialog hears its
  project wait; while it runs the dialog says *Handing on the token your Porelo-Vault declares for <forge> to
  <host>…* with no button, then the host's word. With nothing declared the button stays; a hand-over that could not
  run says its words with the button, which gives as a press, and the machine's next word tries the hand-over again
  (within the minute, the same words). A token that did not help, handed on now or already by the window for the
  same wait, says *<host> still waits for a token after the one your Porelo-Vault declares…* with the button.
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

- **Box:** the build box's Maven `test` phase (format check, `dart analyze --fatal-infos`, `porelo_host`'s tests and the
  whole `flutter test` suite) at `aea0709`: BUILD SUCCESS, 4640 passed, 37 skipped, 0 failed.

- **After the reading** (a later wait, a hand-over that could not run, the dialog's bare button, a step that gave
  nothing): tests `test/ui/declared_token_hand_on_test.dart` *a project heard waiting again after it stopped waiting
  is a new wait*, *a hand-over that could not reach the host is tried again on the next word*, *a host that waits for
  no token, by Porelo's exit code, is nothing to do* (Porelo's own source run with exit 65 behind the fixture
  organization, through `_giveTokenFrom` to `nothingWaits`); `test/ui/placing_project_dialog_test.dart` *a declared
  token the window already handed on says it did not help*; `test/app/declared_hand_on_test.dart` *a project the host
  stopped reporting waiting waits anew*, *a hand-over that could not run answers nothing* (busy);
  `test/app/token_giving_test.dart` *a run of its own and a pressed give to one machine go one at a time*.
- **Red after the reading**, on the code before the fix: the new wait `Expected: ['build', 'build'] Actual:
  ['build']`; not reached `Expected: an object with length of <2> Actual: ['connect build']`; exit 65 `Expected:
  HandOnOutcome.nothingWaits Actual: HandOnOutcome.answeredBefore`; the dialog `Found 0 widgets with text containing
  still waits for a token`. The `DeclaredHandOn` and `TokenGiving` unit tests use the new outcomes, so they were not
  run on the old code.
- **Runs after the reading** (one file at a time): analyze No issues found; `declared_hand_on_test` 3,
  `token_giving_test` 2, `declared_token_hand_on_test` 5, `placing_project_dialog_test` 18,
  `porelo_organization_source_test` 116, `host_token_sources_test` 10, `server_setup_wizard_test` 16,
  `organization_host_pages_test` 126, `organization_project_pages_test` 91, `machine_own_pages_test` 27: all passed.
- **Second reading** (a loop through a passing state, the retry rate, the dialog's bare button after a hand-over that
  could not run): tests `declared_token_hand_on_test` *a project passing through another state and waiting again is
  the same wait* (waits, given, cloning, waits: one give) and *a hand-over that could not reach the host is tried again
  a minute later*; `placing_project_dialog_test` *a hand-over that could not run says why, and the button gives*;
  `declared_hand_on_test` *a project waits anew only once the host reported it taken* and *… tried again at most once
  a minute*. Red on the code before: the loop `Expected: ['build'] Actual: ['build', 'build']`; the dialog `Found 0
  widgets with text "build could not be reached, so no source was asked."`. Runs (one file at a time):
  `declared_hand_on_test` 3, `declared_token_hand_on_test` 6, `placing_project_dialog_test` 19, `token_giving_test` 2,
  `host_token_sources_test` 10, `organization_host_pages_test` 126, `organization_project_pages_test` 91,
  `machine_own_pages_test` 27: all passed; analyze No issues found.
- **Box at the final code:** the build box's Maven `test` phase at `6206dd8` (both readings' fixes): BUILD SUCCESS,
  4651 passed, 37 skipped, 0 failed (also 460 and 5 passed). `cd492be` before it: BUILD SUCCESS, 4649 passed, 37
  skipped, 0 failed.

## To be checked

- A project not reached in the 300 s pass stays waiting and is not handed on again by itself: its row and the placing
  dialog ask with the button, and a press refreshes again. Whether the window should hand on once more where the host's
  answer says it ran out of time is not built.
- The self hand-over connects to the host as the token's page does on a press; it was not walked against a real host.
- A project that joins a hand-over already running is marked answered with it, although the token went out before that
  project was heard waiting; it is handed on again by itself only once the host reports it taken and waiting anew.
- A project whose wait ends while the host is not heard (`_heardFrom` null) keeps its mark until the host is heard
  reporting it carried; a wait that ends without the project ever being carried (the project removed) keeps it for the
  window's life.
