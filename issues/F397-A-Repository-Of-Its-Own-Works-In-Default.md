# F397 — A Repository Of Its Own Works In Default

**Status:** Accepted.

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
- In `default`, the light and unsigned project, a machine answers per repository what its `porelo.yml` sets and which
  of it is allowed on this machine, and allows exactly what was set, keeping the allowance outside the repository. A
  start from the window whose settings changed since the last allowance asks before the task starts, listing only
  what changed; a no starts nothing.
- In a project of an organization `porelo.yml` is signed by the project admin or by a developer with access to the
  repository, and a follow checks every commit that changes it. The window shows a repository whose `porelo.yml` is
  not signed as the machine's refusal, naming the file, and offers no way to allow it here.
- The first start in a checkout offers to write `porelo.yml` with what was detected, and the work starts in
  `default`; it no longer offers to write or approve a `project.yml` that makes the checkout a project.
- What the window says today of where a setting lives - "has a project.yml", the image "from the project's
  project.yml", egress "changed only in project.yml", Default's "Porelo's own settings, fixed" - names `porelo.yml`
  where the repository's file adds to it or removes from it.

## To be checked

- The daemon's calls for a repository's composed settings with each value's source and what was removed, the
  allowance in `default` and the first start writing `porelo.yml`, parameter by parameter, once they are designed;
  what is missing goes into `doc/Contract-Gaps.md`.
- Whether the window signs a repository's `porelo.yml` - for the project admin and for a developer with access to the
  repository - the way the organization pages sign a project's first file, and what either sees of a change waiting
  for a signature.
- What the window shows for a checkout that already became a project of its own through an earlier first start, once
  the machine says what becomes of it.
- The places that speak of a checkout's `project.yml`: `first_start_view.dart`, `default_view.dart`,
  `repositories_view.dart`, `forges_page.dart`, `image_settings_view.dart`, `egress_view.dart`,
  `start_work_view.dart`, `organization_dialogs.dart` and the features that drive them.
