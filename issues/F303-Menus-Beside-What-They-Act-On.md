# F303 — Menus Beside What They Act On

**Status:** Idea.
**Severity:** medium.
**Size:** M - the item list rows, section headings and page titles with their ⋮ menus, with their golden and widget
tests; no contract with another repository.

**What must be true.** Each ⋮ menu sits visibly with the row, section or page title it acts on, so on a wide window a
person sees at once which thing a menu belongs to.

## Why

`ProjectDetailsPage` in `lib/src/ui/project_details_page.dart` puts the page's ⋮ after an `Expanded` title, at the
far right on a wide window. `ItemListRow` in `lib/src/ui/expandable_list_row.dart` uses a full-width `ListTile` with
`trailing: menu`, without a bounded width. These files do not keep the menus visibly beside their titles on a wide
window, as promised above.

## The shape

- The page's ⋮ directly after the page title.
- A row's ⋮ at the end of a row whose width is bounded (a readable maximum width for lists), or shown with the row's
  hover and focus highlight across its full width so the connection is visible.
- A section's actions beside its heading, as *Persons* already does for its buttons.

## Plan

- `lib/src/ui/expandable_list_row.dart` (`ItemListRow`), `lib/src/ui/command_menu.dart`, the page headers in
  `lib/src/ui/project_details_page.dart`.
- **Red first:** a widget test on a 1600-pixel-wide window: the page ⋮ lies within a short distance of the title's
  end, and each row's ⋮ within the row's bounded width.

## Acceptance

- On every window width, a ⋮ lies next to, or highlighted with, the thing it acts on.
- Keyboard order and screen reader labels stay as they are.
