# F553 — A Row's State Stands Beside Its Menu

```json
{
  "$schema": "issue-1.json",
  "id": "F553",
  "title": "A Row's State Stands Beside Its Menu",
  "state": "Review",
  "size": "XS",
  "priority": "Highest",
  "rank": 8,
  "blockedBy": [],
  "covers": "In every list row drawn by LeafListRow, the state chip stands to the left of the row's ⋮ menu or buttons, on one line with them and centered in the row, as ItemListRow's rows already have it, instead of stacked above them in the row's top corner."
}
```

**Why this size.** One widget's layout in one file; no contract, one widget test.

**What must be true.** On a project's page, a repository's *review required* chip stands left of its ⋮ menu, on one
line with it and centered in the row's height, as on *My projects* and a machine's rows; so does every other row
drawn the same way.

## Plan

- **Where it comes from.** `LeafListRow` (`lib/src/ui/expandable_list_row.dart`), where the card is wide enough
  (`WindowSize.chipBeside`) and `chipFirst` is not set, draws its right side as a `Column` with `StateChip` above
  `trailing`, aligned to the end; so the chip sits in the top corner over the menu. `ItemListRow` in the same file
  puts the chip and the menu in one `Row`, which is the look wanted.
- **The rows it reaches**, every `LeafListRow` without `chipFirst`: a project's repositories and the organization's
  *My projects* rows (`organization_project_pages.dart`), *My hosts* rows (`organization_host_pages.dart`), a host's
  readiness probes (`host_readiness_view.dart`), a machine's agents and their errors (`agents_view.dart`), its
  connections (`connections_view.dart`) and destinations (`destinations_view.dart`). The machines' and the machines'
  projects rows are `ItemListRow` and already stand right.
- **The change.** On a wide card the row is laid out by a render box of its own: the chip, a `Space.small` gap, then
  `trailing`, at the row's right, centered in its height, each with the width it needs on one line, and the words
  take the rest. A `Row` sharing the row's quarter cut the chip and broke buttons letter by letter, so the right side
  takes its intrinsic width instead. Where chip and operations need more than `Sizes.rowActionsShare` of the row, the
  chip stands under the words and the operations under both, at the right, never squeezed. Operations that offer
  nothing (an empty `Wrap`, a menu with no entries) leave no gap. Narrow cards keep today's layout (chip under the
  words, actions below). Spacing from `tokens.dart` only.
- **Test** (widget, `test/ui/leaf_row_state_beside_test.dart`). Harm: a state or a button's name cut so it cannot be
  read or found. At cards 480, 620 and 1280 wide, with a menu, a connect button and a menu, two buttons and nothing
  offered: the chip's words whole, each button on one line, no overflow, and beside the words the chip left of the
  first operation on its line. The window is looked at in the debug build at 1280 and 390 wide on a project's page
  and a machine's *Connections*.

## Acceptance

- On a project's page, *review required* stands left of the ⋮ menu, on its line, centered in the row; the same on
  the other rows named above; at 390 wide nothing overflows.
