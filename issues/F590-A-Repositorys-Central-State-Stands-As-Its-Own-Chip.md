# F590 — A Repository's Central State Stands As Its Own Chip

```json
{
  "$schema": "issue-1.json",
  "id": "F590",
  "title": "A Repository's Central State Stands As Its Own Chip",
  "state": "Implementing",
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

## Acceptance

- The tests above, each seen red first; `test/ui` and `test/features` green.
