# F159 — Work Started From The Project Page

**Status:** Review.
**Size:** S - a start button on each repository row, the start form's repository fixed with *Change*.

**What must be true.** The project page offers a visible start button on each repository row and
one for the project as a whole, not only an item inside each repository row's `⋮` menu. When the
start form is opened from a repository row's start action, the chosen repository is shown as text
with a *Change* action beside it instead of an open *Which repository* dropdown.

## Why

On the project page, starting work is hidden in each repository row's `⋮` menu (*Start work in
\<repository\>*) and missing beside the project title, and opening the start form from a repository
row still shows *Which repository* as an open dropdown.

## Plan

- **Today**, read in the code: each repository row (`machine_tree.dart`, `repository-$name`) has
  *Start work in <name>* only inside its `⋮` (`start-in-$name`); the project page
  (`machine_view.dart`) has the *Start work* tile for the project; the start form
  (`start_work_view.dart`) shows *Which repository* as an open dropdown whenever the project needs
  one (`_WhichRepository`), also when it was opened from a row.
- **On each repository row** a visible *Start work here* button beside its `⋮`, running the same
  command as the `⋮` item, with the item's reason when it cannot run. The `⋮` keeps the item.
- **The project-wide start** is the existing *Start work* tile: with one repository it is that
  one; with several, the form asks *Which repository* as today.
- **Opened from a row**, the form shows the repository as text with *Change* beside it; *Change*
  opens the dropdown. `StartWork` carries the repository it was opened for.
- **Test, its harm, red first:** a start opened from a row starts in that row's repository unless
  *Change* picks another (work started in the wrong repository); today the dropdown can leave a
  different one chosen. Together with [F165](README.md#f165), which puts the project's commands on
  the same page.

## Acceptance

- The project page shows a visible start button for the project and one on each repository row;
  opening the start form from a repository row shows that repository as plain text with *Change*
  beside it.
- Seen to fail: starting from a repository row uses that repository unless the person clicks
  *Change* and picks another.
