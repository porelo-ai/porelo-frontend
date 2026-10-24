# F173 — Action Tiles That Read As Buttons

**Status:** Analyzed.
**Size:** S - one shared tile component in a style the operator picks from three, and *Its work, under Work* made a tile.

**What must be true.** Every action on a project's page is a tile of one size and form, *Its work,
under Work* included, and the tiles read as buttons, not as information panels, in a style the
operator chose from two or three shown variants.

## Plan

- **Today**, read in the code: `CommandTile` is an `OutlinedButton` of token width and height
  (`machine_view.dart`, `tokens.dart`); *Its work, under Work* is a separate small
  `OutlinedButton.icon` (`shell.dart`).
- **Variants first:** three variants of `CommandTile` behind a development switch, shown as
  screenshots of the same project page from a walk step: (a) tonal cards, filled with the
  secondary container colour, big outlined icon above the title; (b) raised surface cards with a
  stronger border and elevation on hover; (c) outlined cards with a big icon at the left and a
  pressed colour. All with hover and press feedback and the disabled look. The operator picks one;
  only that one is built, the switch goes.
- **Its work:** a `Command` with `home: Home.startTile`, rendered as a tile.
- Every new spacing, radius and colour in `tokens.dart`.
- **Tests:** none: layout and colour only.

## Acceptance

- The operator picked a variant from the screenshots; in the guided walk every action on the page
  is a tile of that style and one size.

## Open questions

- **Which of the three styles:** shown as screenshots before it is built. Recommended: (a), tonal
  cards.
