# F397 — A Repository Of Its Own Works In Default

```json
{
  "$schema": "issue-1.json",
  "id": "F397",
  "title": "A Repository Of Its Own Works In Default",
  "state": "Review",
  "size": "L",
  "priority": "Medium",
  "rank": 27,
  "blockedBy": [],
  "covers": "A repository of its own listed and started in Default, its `porelo.yml` allowed at a start, each setting shown with its source; the machine's proposal before a repository's first task there."
}
```

**Why this size.** a new step in every start from the window on a contract the machine still has to serve, its stand-ins,
the words of six views, and the machine's proposal before a repository's first task in `default`.

**What must be true.** A repository worked on outside any project of an organization is listed and started in
`default`, never as a project of its own: the window lists Default's repositories, and when a task is started from
the window it asks the person to allow the settings the repository's `porelo.yml` adds that this machine has not
allowed yet, showing only what changed. Wherever the window shows a setting, it names its source - the project, the
repository or Porelo's default - and what the repository removed.

## The shape

- `porelo.yml` has the project file's form, less what defines a project (its name, organization, repositories and
  members), and adds to the project file's defaults: a mapping merges key by key, a list takes the project's entries
  and then the repository's, and a single value the repository sets wins. `null` removes a key the project set, and a
  quoted `"!entry"` in a list removes that inherited entry, `"!*"` every one. The machine composes the result and names
  each value's source; the window renders that verbatim and derives nothing.
- In `default`, the light and unsigned project, the machine keeps the person's allowance outside the repository,
  bound to exactly what was set. A start from the window whose settings changed since the last allowance asks before
  the task starts, listing only what changed; a no starts nothing.
- In a project of an organization `porelo.yml` is signed by the project admin or by a developer with access to the
  repository, and a follow checks every commit that changes it. The window shows a start the machine refuses for an
  unsigned change as that refusal, naming the file and the commit, and offers no way to allow or sign it here: the
  person signs it with their own commit in their checkout.
- The allowance is asked only at a start, never beforehand from the Default list.
- The first start in a checkout offers to write `porelo.yml` with what was detected, and the work starts in
  `default`; it no longer offers to write or approve a `project.yml` that makes the checkout a project.
- Before the first task on a repository started from the Default list that has no `porelo.yml` yet, the window shows
  the machine's proposal the same way: what it found in the repository's files and where, the hosts it opens with
  those only the repository names marked, and the `porelo.yml` text. A yes writes that file and is its allowance; a
  no starts with Porelo's own settings, keeps nothing, and the next first task asks again. There is no choice of a
  project draft.

## Plan

The window already lists `default`'s repositories (`DefaultRepository`, `defaultRepositories`, `addToDefault`) and
starts work there (`shell.dart` `_startInDefault`). What changes is the first start, a new answer of `CanStart`, one
new call, and the words that place a setting in `project.yml` alone.

**The calls assumed** (to be served by the machine; checked parameter by parameter once served):

- `CanStart` answers a new outcome `SETTINGS_NOT_ALLOWED` in `default`, with `settingsToAllow`: one entry per changed
  setting (`key`, `value`, `was`, `removed`), and `settingsHash`, naming exactly that text. In a project of an
  organization an unsigned change is a refusal of its own (`SETTINGS_UNSIGNED`, with `file` and `commit`). Both are
  read through `StartOutcome`'s open class, so an older window renders them as an unknown refusal with the machine's
  `detail`.
- `AllowSettings(repository, hash)` answers `ALLOWED`, or `CHANGED` when the file moved since it was shown, which asks
  again rather than allowing what nobody saw.
- `FirstStart` keeps its shape: `file` names `porelo.yml`, `project` is `default`, and its yes writes `porelo.yml`.
- A setting's source in `ImageSettings`, `EgressHost.origin` and the dry run names `porelo.yml` where the repository
  set it, with removed entries marked.

**Steps:**

1. Models (`lib/src/client/models.dart`): `SettingToAllow`, `Readiness.settingsToAllow` and `settingsHash`, the two
   outcomes, `SettingsAllowed`; `PoreloClient.allowSettings`, `FleetBackend.allowSettings`, `MockDaemon` and
   `FakeBackend` serving them from what the test tells them.
2. The start (`lib/src/app/start_work.dart`, `lib/src/app/start_agents.dart`): on `SETTINGS_NOT_ALLOWED`, *Start it*
   stays off and the start shows the changed settings; *Allow* sends the hash that was shown and asks `CanStart`
   again, and the person starts on its `READY`. A `CHANGED` answer shows the new list. The several-agents start
   (`start_agents.dart`) is for a project's repositories that name an agent, which `default` has none of: it shows
   the machine's refusal and allows nothing.
3. The view (`lib/src/ui/start_work_view.dart`): the list of changed settings as the machine words them and a button
   that allows exactly them; closing the dialog is the no and starts nothing. Like trusting a host key in the same
   place, it is an answer inside the start's own dialog, not a `Command` of the frame.
4. The first start (`lib/src/ui/first_start_view.dart`, `lib/src/ui/default_view.dart`): the question names
   `first.file` (`porelo.yml`), and a yes whose answer is `default` goes on through `onStartWork` with the checkout's
   repository rather than `onStartProject`.
5. Words that place a setting in `project.yml` alone: `image_settings_view.dart` (`imageSourceWords` learns
   `porelo.yml` and a removed entry), `egress_view.dart` ("a repository only ever adds" is no longer true: it may
   remove), `default_view.dart` ("Porelo's own settings"), `repositories_view.dart` and `forges_page.dart` ("has a
   project.yml" for a repository in `default`), `start_work_view.dart` (credentials "in project.yml"), and the
   features that drive them.

6. The proposal before a repository's first task in `default`: where every start goes through (`shell.dart`), a
   start in `default` on a repository with no checkout here asks `FirstStart(repository)`, which reads the gate's
   mirror and answers `KNOWN` once the repository has its settings, and shows a question in `FirstStartDialog`,
   awaited before the start; a yes is `ConfirmFirstStart(repository, hash)`, which keeps the settings on this machine
   only, never in the repository, and allows them. A machine that takes no repository there starts as today.

**The test that goes red first:** a feature in `test/features/`: a start in `default` whose machine answers
`SETTINGS_NOT_ALLOWED` with two changed settings shows both and leaves *Start it* off; *Allow and start* sends exactly
the hash shown and starts only after the machine answers `READY`. It guards a task reaching hosts or credentials the
person never allowed, and allowing a text other than the one shown; it is seen red against a start that ignores the
new outcome. A client test sends `AllowSettings` over the mock daemon's socket and reads `CHANGED` as a refusal, not
as allowed.

## Declined in the reading

- A `Command` for allowing and declining: the allowance is part of the start's dialog, as trusting a host key there
  is, and closing the dialog declines.
- Deleting the egress scenario's check of the heading "Reachable now": it is not the text that changed, and it is what
  makes the scenario's real check, that the view offers no change of its own, able to fail at all.
- Doc comments said to call an unknown outcome ready: they name `StartReadiness` and `FirstStartOutcome`, which this
  repository does not have; the comments that are there say an unknown outcome is shown with the machine's words.

## Acceptance

- In `default`, a start whose repository's settings changed shows only what changed, starts nothing on a no, and
  after a yes starts with exactly what was shown; a file changed in between asks again.
- In a project of an organization, a start refused for an unsigned `porelo.yml` names the file and the commit and
  offers nothing that starts the work.
- The first start in a checkout writes `porelo.yml` and starts in `default`; no new project appears in the machine's
  list.
- Every source the image and egress views show names `porelo.yml` where the repository set the value, and a removed
  entry is shown as removed.
- A first task on a repository from the Default list with no `porelo.yml` shows the proposal before any task exists;
  a no starts with Porelo's own settings and writes nothing.
- An older machine that answers none of this starts as today, and an unknown outcome is shown with the machine's
  words.

## To be checked

- `FirstStart` and `ConfirmFirstStart` with `repository` against the machine's interface once it serves them, parameter
  by parameter; every other call is read against it already.
