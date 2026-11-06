# F414 — A Long Choice Filters As One Types

**Status:** Accepted (operator, 2026-11-06).
**Size:** S - the shared choice field opens a small dialog with a filter field where its list is long, used by every
choice that grows with what is listed (repositories, machines, people).

**What must be true.** A choice from a long list - more than a few entries - opens a dialog no taller than it needs,
with a text field at the top that narrows the list as one types; Enter takes the only one left, and the chosen one
says what it means under the field as today. A short list stays a drop-down.

## Why

The operator's walk on the rehearsal VM (2026-11-06): *Start work*'s repository choice was a plain drop-down of all 17
of porelo's repositories, as tall as the window. The same holds for every long choice, such as the machine and
person pickers.

## Plan

- `lib/src/ui/choice_field.dart` (`ChoiceField`, used by *Start work*'s *Which repository*): above a threshold (eight
  entries) the field opens a dialog with a filter field over the choices' labels, the same keys per entry
  (`Choice.id`) so the walks and tests find them.
- `lib/src/ui/organization_dialogs.dart` (`OrganizationPickDialog`, the machine and person pickers) and the
  `DropdownButtonFormField`s that list repositories, machines or people use the same dialog; fixed short lists
  (modes, policies) stay drop-downs.
- **The test that goes red first:** a choice of twenty repositories opens a dialog with a filter; typing "sluice"
  leaves one entry, and Enter chooses it. It guards a person who cannot find a repository in a list taller than the
  window.

## Acceptance

- Every choice from a long list filters as one types; short fixed lists are unchanged.

## Built

- `ChoiceField` keeps its drop-down up to `ChoiceField.filterAbove` (eight) choices; above that the field (still keyed by
  its `id`) opens a dialog no taller than `Sizes.finderHeight` with a filter field (`<id>-filter`) over the labels,
  each entry keyed by its `Choice.id` as before, and Enter takes the only one left. *Start work*'s repository choice
  uses it without a change of its own.
- `OrganizationPersonDialog`, the person and machine picker, now uses `ChoiceField` (`organization-person`, entries
  `organization-person-<login>`), so a long list of people or machines filters the same way.
- Left as drop-downs: the fixed short lists (roles, modes, review policy), *Start work*'s agent and credential choices
  and the preparation's machine name in `host_dialog.dart`.
- `test/ui/choice_filter_test.dart` went red on the old code (no filter field: "Bad state: No element") and passes now.
