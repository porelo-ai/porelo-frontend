# F397 — A Repository Of Its Own Works In Default

**Status:** Implementing.
**Size:** L - a new step in every start from the window on a contract the machine still has to serve, its stand-ins,
and the words of six views.

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
  unsigned change as that refusal, naming the file and the commit, and offers no way to allow it here.
- The first start in a checkout offers to write `porelo.yml` with what was detected, and the work starts in
  `default`; it no longer offers to write or approve a `project.yml` that makes the checkout a project.

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
   stays off and the start shows the changed settings; *Allow and start* sends the hash that was shown, asks
   `CanStart` again, and starts only on its `READY`. A `CHANGED` answer shows the new list. The several-agents start
   asks once per repository, not per agent.
3. The view (`lib/src/ui/start_work_view.dart`): the list of changed settings with their source words and a no that
   starts nothing; `Command` entries for allow and decline, with the reason when they cannot run.
4. The first start (`lib/src/ui/first_start_view.dart`, `lib/src/ui/default_view.dart`): the question names
   `first.file` (`porelo.yml`), and a yes whose answer is `default` goes on through `onStartWork` with the checkout's
   repository rather than `onStartProject`.
5. Words that place a setting in `project.yml` alone: `image_settings_view.dart` (`imageSourceWords` learns
   `porelo.yml` and a removed entry), `egress_view.dart` ("a repository only ever adds" is no longer true: it may
   remove), `default_view.dart` ("Porelo's own settings"), `repositories_view.dart` and `forges_page.dart` ("has a
   project.yml" for a repository in `default`), `start_work_view.dart` (credentials "in project.yml"), and the
   features that drive them.

**The test that goes red first:** a feature in `test/features/`: a start in `default` whose machine answers
`SETTINGS_NOT_ALLOWED` with two changed settings shows both and leaves *Start it* off; *Allow and start* sends exactly
the hash shown and starts only after the machine answers `READY`. It guards a task reaching hosts or credentials the
person never allowed, and allowing a text other than the one shown; it is seen red against a start that ignores the
new outcome. A client test sends `AllowSettings` over the mock daemon's socket and reads `CHANGED` as a refusal, not
as allowed.

## Acceptance

- In `default`, a start whose repository's settings changed shows only what changed, starts nothing on a no, and
  after a yes starts with exactly what was shown; a file changed in between asks again.
- In a project of an organization, a start refused for an unsigned `porelo.yml` names the file and the commit and
  offers nothing that starts the work.
- The first start in a checkout writes `porelo.yml` and starts in `default`; no new project appears in the machine's
  list.
- Every source the image and egress views show names `porelo.yml` where the repository set the value, and a removed
  entry is shown as removed.
- An older machine that answers none of this starts as today, and an unknown outcome is shown with the machine's
  words.

## Open questions

- [F142](README.md#f142) shows the machine's proposal before the first task on a repository in `default` and offers
  to keep a `project.yml` draft. With this decision the draft's target is `porelo.yml`, which the first start writes,
  and a kept project draft has no use. Is [F142](README.md#f142) folded into this issue - its proposal becomes the first start's
  question for a repository started from the Default list, its draft choice dropped - or kept apart and reworked after
  it? The size above holds without it; folded in, it stays L and grows by about half of its M.

- Does the window offer to sign a changed `porelo.yml` in a project of an organization, as it signs a project's first
  `project.yml` today, or does the person sign it with their own commit in their checkout, the window only showing the
  machine's refusal? The design above takes the second: it adds no signing, and a developer signs where they commit.
- Is the allowance asked only at a start, or can it also be given beforehand from the Default dialog's list of
  repositories? The design above asks only at a start.

## To be checked

- The calls above against what the machine serves, parameter by parameter; what differs changes the plan before
  building, and what is missing goes into `doc/Contract-Gaps.md`.
- What the window shows for a checkout that already became a project of its own through an earlier first start, once
  the machine says what becomes of it.
