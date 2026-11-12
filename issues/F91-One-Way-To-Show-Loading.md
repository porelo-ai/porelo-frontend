# F91 — One Way To Show Loading

```json
{
  "$schema": "issue-1.json",
  "id": "F91",
  "title": "One Way To Show Loading",
  "state": "Backlog",
  "size": "M",
  "priority": "Medium",
  "rank": 10,
  "blockedBy": [],
  "covers": "Every view shows the same way that it is reading."
}
```

**Why this size.** M: one small shared widget, used by the shared list section and by seven views that read in a way
of their own, three models that keep another project's answer while they read, one slower answer in the test
backend and a scenario per view; no contract changes. The reads beyond those seven are a follow-up (below).

**What must be true.** Every view that reads something when it opens shows, the same way, that it is reading and
what, so a person never takes an empty view for a finished one, nor another project's answer for this one's.

## Why

Most of the window already reads one way: the shared list section (`FilteredListSection`, used by the machine's
page, Connections, Agents, the vault, the forges, the organization's pages and about twenty more) draws a bar while
`busy` (`lib/src/ui/filtered_list_section.dart:556`), keeps the rows it had, and says "not read" in its card before
the first answer (`:508`, `:608`). The views that do not use it each read their own way, and some say something false
while they read:

- **What a project may reach** (`lib/src/ui/egress_view.dart`) shows nothing that it reads, and says "None is
  installed. That is a state, not a failure." (`:110`) while the sets are still being asked for. `Egress.lookAt`
  (`lib/src/app/egress.dart:51`) keeps the previous project's hosts and sets, so a second project's view lists the
  first one's under its own title until the answer comes.
- **Backups** (`lib/src/ui/backups_view.dart:149`) says "Asking the machine…" without a bar, and only while nothing is
  listed: `Backups.look` (`lib/src/app/backups.dart:52`) keeps the previous project's backups, so they stand under the
  new project's name, with nothing that says they are being replaced.
- **The gate** (`lib/src/ui/gate_view.dart`): its list shows a spinner and "Reading the gate…" (`_Reading`, `:824`)
  and at the same time "Nothing is waiting. Everything this project pushed has been decided." (`:61`), the list's
  empty message. `Gate.lookAt` (`lib/src/app/gate.dart:106`) keeps the previous project's `waiting`. A push's page
  shows a large centred spinner with no words (`:270`).
- **The start form** (`lib/src/ui/start_work_view.dart:311`), **Messages** (`lib/src/ui/messages_view.dart:158`),
  **the destinations** (`lib/src/ui/destinations_view.dart:151`, `:212`) and **the Default dialog**
  (`lib/src/ui/default_view.dart:346`) say "Asking the machine…" in words alone, with nothing that moves, so a slow
  machine reads as a stuck window. The Default dialog says it twice on opening: its `_busy` line (`:346`) and its
  unread line (`:347`) both stand.

## The shape

- While a view reads, a thin bar stands at the top of its content. In a dialog the bar sits at the top of the
  dialog's content; the dialog gets no header of its own.
- Until the first answer for what the view shows, one sentence stands under the bar, in the place of the answer,
  saying what is read and from where ("Asking vm which backups of foo are recorded…"), never the view's empty words.
- Then the answer, or why there is none. Reading the same thing again keeps the answer under the bar, as the list
  section does today; a view opened for another project or repository drops the previous answer before it reads.
- A button's own spinner while its action runs is an action, not a read, and stays as it is.

## Plan

- **The widget.** `Reading` in a new `lib/src/ui/reading.dart`: a `LinearProgressIndicator` of
  `Sizes.progressBar` and, where given, one sentence under it, keyed `reading`. `FilteredListSection` draws its bar
  with it (`:556`), without a sentence; its card says "Reading…" instead of "not read" while `busy` and unread, and
  "not read" stays for a source that has not answered and is not being asked. The bar thins from the indicator's
  default to `Sizes.progressBar`, as the machine's facts (`facts_page.dart:176`) and the status line already draw it;
  the section's callers change nothing else.
- **The models.** `Egress.lookAt`, `Backups.look` and `Gate.lookAt` drop what they hold before they read when the
  project or the repository differs from the one held (`Egress` and `Backups` carry a repository beside the project);
  a re-read of the same keeps it. All three are one instance each in the shell (`shell.dart:266`, `:272`, `:317`),
  opened before they read, which is why the previous answer shows today. `Egress` gets a `read` flag, cleared with the
  rest and set by its first answer, as `Backups` has `_read` (`backups.dart:49`); a project not on this machine keeps
  its problem's words, which stand in place of the reading.
- **The views, in order.**
  - `EgressView`: `Reading` under the header while `busy` ("Asking <machine> what <project> may reach…"); the
    reachable list, "None is installed" and the sets only once `read`.
  - `BackupsView`: `Reading` while `busy`; the sentence in place of the list until the first answer.
  - `GateView` (the list): `Reading` in place of `_Reading`, keeping its count ("Reading the gate of <project>…", "…
    of 3 repositories…"); the list's empty message only once `reading` is 0. The push's page: `Reading` ("Reading what
    this push changes…") in place of the centred spinner.
  - `StartWorkDialog`: `Reading` in place of the bare words, which stay "Asking the machine what it has…", since
    `task_creation.feature` finds them.
  - `MessagesDialog`: `Reading` at the top of the dialog's content while `members` is null and nothing was refused.
  - `DestinationsView` (both places): `Reading` while `widget.answering` and nothing is read.
  - `DefaultDialog`: one `Reading` while the first read runs, its `_busy` line only for an action.

  The sentences name the machine and the project where the model holds them.
- **Holding an answer back.** `FakeBackend` in `test/features/support/world.dart` slows one read with `agentsTake`
  (`:224`), which "the machine has answered" outwaits on the fake clock (it pumps 4 s). It gets `readsTake` (3 s),
  awaited at the start of `egressOf`, `backups`, `gateOf`, `reviewOf` (a push's files), `messageMembers`,
  `destinations` and `defaultRepositories`, and a step "the machine is slow to answer" that sets it. Not in
  `egressSets`: `Egress.lookAt` awaits it after `egressOf`, and two waits in a row outlast the 4 s. The gate's
  repositories are read side by side (`Future.wait`), so one wait covers them all. "The machine has answered" sets
  `readsTake` back to zero after its pump, so a scenario's later reads answer at once; the backend is made anew for
  each scenario. `destinations` is also read by the start form (`start_work.dart:1142`); no scenario here slows
  both. No socket is involved, so the fake clock holds, and `World.settle` pumps a fixed time, so the moving bar never
  holds a step.
- **Red first.** In `test/features/project_configuration.feature`: "while the machine is asked, the view says what
  it is reading": slow, open what the project may reach, find `reading` and its sentence and no "None is installed";
  the machine has answered; find the hosts and no `reading`. Then one scenario of the same shape in `backups.feature`,
  `work_handover.feature` (the gate's list and a push), `task_creation.feature` (extending the scenario there),
  `project_messages.feature`, `destinations.feature` and `work_without_a_project.feature` (the Default dialog). Two
  scenarios prove the dropped answer: backups of one project, then another's opened slowly, finds none of the first's;
  the same for the gate. One widget test in `test/ui/leaf_page_look_test.dart` finds "Reading…" on a busy, unread
  section and "not read" on an idle one; the test there that finds "not read" twice on a busy, empty section
  (`leaf_page_look_test.dart:311`) changes with it. The other tests that find "not read"
  (`test/ui/work_and_attention_counts_test.dart`, `repository_on_the_machine_test.dart`,
  `organization_host_pages_test.dart`, `forge_pages_test.dart`) are run before the change; one that finds it while a
  section is busy is changed with it. No test finds the gate's `gate-reading` key.
  The "one widget" criterion is checked by every scenario finding the same key.

## Acceptance

- One shared widget shows the reading, and the list section and each view above use it. Seen to fail: a view in the
  list that builds its own progress or none.
- Each view, its answer held back, shows the bar and its sentence and none of its empty words, then the answer once
  it comes. Seen to fail: a scenario per view that finds no `reading`, finds the empty words while reading, or still
  finds `reading` after the answer came.
- A view opened for another project shows none of the previous project's answer while it reads. Seen to fail: the
  backups and gate scenarios that find the first project's rows under the second's name.

## After this

A follow-up issue, filed once this one is estimated, takes the reads that still show words alone or a spinner:
`clearing_view.dart:52`, `grant_view.dart:67`, `emergency_stop_view.dart:173`, `authentication_view.dart:86`,
`organization_dialogs.dart:758` and `:1075`, `project_init_dialog.dart:127`, `image_settings_view.dart:121`,
`log_view.dart:214`, `discussion_start_dialog.dart:124`, `start_agents_view.dart:122` and `:160`, and
`identity_view.dart` (`:212`, `:399`, `:624`, `:1203`, `:1438`, `:1493`), `peers_view.dart:92`,
`held_message_view.dart:295`, `project_deletion_view.dart:57`, `repositories_view.dart:99`, `:206` and `:299`,
`connection_wizard.dart:539` and `:630`, `wsl_machine.dart:117`, `organization_page.dart:1659`,
`organization_project_pages.dart:570` and `:572`, `host_dialog.dart:475` and `:999`, `messages_view.dart:392`; and
`ProjectForgeDialog`
(`project_forge_view.dart:44`), which shows nothing while it opens the workspace and reads the signing keys, and whose
`keys.first` throws on an empty key list inside `setState`, so it never says that no key was found. Its workspace
runs git and the SSH agent, so it needs a stand-in first, which is why it is not in this one.
