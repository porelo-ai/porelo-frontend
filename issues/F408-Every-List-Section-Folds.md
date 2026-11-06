# F408 — Every List Section Folds

**Status:** Accepted (operator, 2026-11-06).
**Size:** S - the shared list section folds unless a dialog says otherwise, so every page's lists fold and a new page
cannot miss it; the nine sections that do not fold today follow without a change of their own.

**What must be true.** Every box holding a list, on every page, folds and unfolds, and stays as the person left it;
only a list inside a dialog may stand open without folding.

## Why

The operator's walk on the rehearsal VM (2026-11-06): porelo's 17 repositories fill the project page and its
*Repositories* cannot be folded, unlike other sections. Every list box should fold. Of 20 `FilteredListSection`s in
`lib/src/ui`, ten pass `collapsible: true`; the others do not fold:

- `organization_project_pages.dart`: *My projects*, *Repositories*, *Members*.
- `organization_host_pages.dart`: *Projects on this machine*, *Machine Admins*.
- `projects_page.dart`, `work_page.dart`, `machines_page.dart`: their one list each.
- `forges_page.dart`: one of its two.
- `organization_dialogs.dart`: one, inside a dialog.

## Plan

- `lib/src/ui/filtered_list_section.dart`: `collapsible` defaults to true, so the rule is the section's own and holds
  for a page added later without a test to remember it; each section's state is already kept by its `storageId`.
- `lib/src/ui/organization_dialogs.dart`: its list in a dialog passes `collapsible: false`.
- The explicit `collapsible: true` elsewhere goes, as it says the default.
- **The test that goes red first:** a `FilteredListSection` built with no `collapsible` shows its fold control. It
  guards a page whose list cannot be folded, the rule the operator asked for.

## Acceptance

- Every page's list sections fold; the dialog's does not.

## Done

The shared section folds unless it says otherwise (`collapsible` defaults to true); the organization's section passes on what it is given, and no list is in a dialog, so none opts out. An empty list starts folded, as the folding sections did before; a project page's test opens it to read its words. Red first: a section built without saying showed no fold control.
