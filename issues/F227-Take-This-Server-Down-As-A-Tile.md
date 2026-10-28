# F227 — Take This Server Down As A Tile

**Status:** Implementing; built, not yet published.
**Size:** XS - the server page's *Take this server down* drawn as a tile among the others, its text red, and its widget
test; about 30 minutes.

**What must be true.** On a rented server's page, *Take this server down* is an ordinary tile in the row of the page's
other tiles (*Open the host protocol*, the VPN's, …), the same size and shape, with its label and icon in the theme's
error colour. Its tooltip, its unavailable reason and the confirmation it opens stay as they are.

## Why

Seen in the operator's round (6i): on the server's page *Take this server down* is a small text button below a divider,
under the tiles, and easy to miss. The operator: it should be a tile like the others, with red text; the confirmation
that follows stays.

## Plan

- `shell.dart`, the server page: drop the divider and the `TextButton.icon` for `machine.takeDown`, and let the tile
  loop draw it with `Icons.delete_outline`; `CommandTile` gains an optional `danger` flag that colours its label and
  icon with `colorScheme.error`.
- **Red first:** the server page shows a `CommandTile` for `machine.takeDown`, its label in the error colour, and
  pressing it opens the same confirmation as before; unavailable, it says why as the other tiles do.

## Acceptance

- *Take this server down* sits among the server page's tiles, red, and opens the same confirmation.
