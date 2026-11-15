# F590 — A Repository's Central State Stands As Its Own Chip

```json
{
  "$schema": "issue-1.json",
  "id": "F590",
  "title": "A Repository's Central State Stands As Its Own Chip",
  "state": "Review",
  "size": "S",
  "priority": "Medium",
  "rank": 19,
  "blockedBy": [],
  "covers": "A repository's row on a project's page on a host shows how it stands against central as a state chip of its own at the row's end (at central, N ahead of central, central moved on, cannot say), toned by what it asks of the person, with Bring it to central… reachable from a row that is ahead, instead of one clause in the row's grey line."
}
```

**Why this size.** The words exist (`HostRepositoryCentral.words`, `centralWords`); one row's layout takes them out of
its line into the chip `LeafListRow`s already use, with a tone per state and the project's *Bring it to central…*
reachable from the row; tests of each state.

**What must be true.** A person scanning a host's project page sees at once which repository's main is ahead of
central or behind it, the one state there that asks for a decision.

## Found

The operator's live test on a host (snapshot 0.5.1~snapshot.552): a repository row of a project's page read *carried
here alone · central moved on · 1 of 1 task running: pi · 1 waiting at the gate · Up to date, as of 5 minutes ago* in
one grey line; *central moved on* drowned in it.

## Plan

- **Today**, read in the code: the row's line is joined from the carried words, `centralWords` and `workIn`
  (`repositoryOnAMachine` and the row builder in `lib/src/ui/machine_tree.dart`; the shell passes it at
  `lib/src/ui/shell.dart` ~6972). The words for the central state are `HostRepositoryCentral.words`
  (`lib/src/app/host_progress.dart`): *at central*, *N commits ahead of central*, *central moved on*, *cannot say:
  …*, and a later host's word as it comes. *Bring it to central…* is one button for the project
  (`project-bring-to-central`), below the page's head.
- **Steps.**
  - The row's line keeps carried and work; the central state leaves it for a `StateChip`
    (`lib/src/ui/expandable_list_row.dart`) at the row's end, beside the row's menu as every list row has it.
  - Its tone by what it asks: *at central* quiet; *N ahead of central* the attention tone (the person brings it);
    *central moved on* the attention tone (the host follows, or the person looks why); *cannot say* the error tone
    with its reason in the chip's tooltip and the row's details; a later word neutral.
  - A row that is ahead offers *Bring it to central…* in its menu, running the project's command for that
    repository's project, greyed with why where the command is.
  - The other places that say the central state in a line (`host_dialog.dart`, the organization's project pages)
    are listed in *Built*; they follow where they show a row.
- **Red first** (harm: a repository ahead of central or behind it is overlooked and its work not brought): a widget
  test per state of the chip's words and tone, and that the line no longer holds them; a test that an ahead row's
  menu brings it to central; each seen red.

## Built

- `lib/src/ui/machine_tree.dart`:
  - `CentralStanding` holds the machine's word against central and its words (`centralWords` and
    `HostRepositoryCentral.words`, unchanged), whether it is ahead, and its tone by what it asks: ahead and moved on
    *needs you* (the scheme's primary, the attention tone `StateColours` already has), cannot say *failed* (the error
    tone), at central and every other word quiet (the stopped tone), so a later host's word is never toned as one
    this build knows. `not-read` and `not-reported` are its own words for none given, quiet too.
  - `centralOnTheMachine` (a machine a card names) takes the choice between the daemon's and the host's word out of
    `repositoryOnTheMachine` unchanged; `centralOnAMachine` does the same for `repositoryOnAMachine`; `centralOf`
    reads one `Repository`. The two line functions now hold carried and work only.
  - `OnTheMachine` gains `central`; `_standing` keeps its own record type without it.
  - `_RepositoryLine` shows the chip (`StateChip`, key `repository-central <name>`) at the row's end beside the
    menu, up to `Sizes.rowSideShare` of the row, where `WindowSize.chipBeside` says the card is wide enough, and
    under the line where it is not (as `LeafListRow` places its state). The chip's tooltip holds the whole state, a
    reason of cannot say with it; the row has no details of its own, so the reason stands in the chip's words and
    tooltip only.
  - A row whose central state is ahead lists the project's `bringToCentral` command (the same `Command` the page's
    head shows, `bringToCentralCommand`) in its menu while it is visible, greyed with its reason where it cannot run
    (running, not connected); `ProjectHeader` hands it to `_Repositories`.
- `lib/src/ui/shell.dart`: `_onTheMachine` fills `central` from `centralOnAMachine` or `centralOnTheMachine`.
- The other places that say the central state in a line, not changed:
  - `host_dialog.dart` `_daemonCentralBlockers` and the host's own blockers: the central words of each repository
    that keeps a machine from being given back, in the give-back step's list; a list of reasons, no row of state.
  - `organization_project_pages.dart` `_centralWords`: the organization's central state of a project (its forge's
    word and how long ago it was read), one clause of the project row's line; another state (the organization's
    central repository, not a host's copy against it), left for its own issue if wanted.
  - `organization_host_pages.dart`: each taken repository of a host's project as a dense row whose line is its
    central words alone; nothing else drowns it there.
- Tests:
  - `test/ui/repository_central_chip_test.dart` (new) *each central state stands in a chip of its own, toned by what
    it asks, and not in the row's line*. Break A: the central words back in the row's line. Red: `Found 2 widgets
    with text containing 2 commits ahead of central`. Break B: every state toned quiet. Red: the ahead chip's colour
    `Color(... red: 0.4196, green: 0.4510, blue: 0.5882 ...)` where the primary was expected.
  - Same file, *an ahead row's menu brings the project to central, and a row at central offers none*. Break D: the
    row offers it for no state. Red: `Expected: exactly 2 matching candidates ... Found 1 widget with text "Bring it
    to central…"`.
  - `test/ui/repository_on_the_machine_test.dart` *the central state is never in the row's line, on a machine a card
    names or not*. Break E: `repositoryOnAMachine` joins the central words again. Red: `Expected: not contains
    'central' Actual: 'carried, not taken yet · central moved on · 0 of 0 tasks running'`.
  - Adjusted: the two tests there that read the central state from `repositoryOnTheMachine`'s line now read it from
    `centralOnTheMachine`, and the not-read one checks `central: not read` there; `test/ui/project_header_test.dart`
    gives its rows `central: null`. The features' *the repository … says* steps look inside the row, chip included,
    and pass unchanged.
- Not checked: the chip under the line at a phone's width is not measured by a test; `test/ui` and `test/features`
  whole.

## Acceptance

- The tests above, each seen red first; `test/ui` and `test/features` green.
