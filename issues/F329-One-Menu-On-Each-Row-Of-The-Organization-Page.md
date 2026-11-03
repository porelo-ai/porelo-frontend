# F329 — One Menu On Each Row Of The Organization Page

**Status:** Review.

**What must be true.** The rows of the organization page look alike and read in one line of actions, whichever roles a
person holds and however wide the window is.

In a walk the operator found the row actions scattered: they sit at different widths, wrap to two lines in some rows and
not in others, and differ from row to row. The operator asks for a redesign, perhaps with only a ⋮ menu on each element.
The cause is in the row: each action is a button of its label's width, in a `Wrap` sharing the row's width with the words.

## The operator's decision

Only a ⋮ on each row, except *Connect*, which stays visible while not connected, and *Push the approved main…*, visible while commits wait, by [F340](README.md#f340). The machine's and the project's pages are the same. This drops the rule *not behind ⋮*.

## What it changes

- **These go:** the rule *Every action stands visibly in its row*, *not behind ⋮*, the walk step's failure line, and the same sentence in the description of the organization, which is not
  this repository's to change.
- **The page joins the rest of the interface:** *Machines*, *Projects* and *Forges* already give each row one `CommandMenu`, because a row with five actions is wider than the pane.
- **These stay:** a person sees only the actions of their roles, so a row with none shows no menu; a refusal is shown in the store's words; a removal still asks first. `CommandMenu` keeps what
  cannot be run grayed with its reason, which is right for an action a person holds and not for another role's.
- **What it costs:** an action is two clicks instead of one and cannot be seen at a glance. *Add me*, and the buttons that add to a section, are not on a row and stay visible.

Beside it, [F303](README.md#f303) places a row's ⋮ near its text on a wide window; a menu here should follow it. How a section looks around these rows is [F344](README.md#f344).
