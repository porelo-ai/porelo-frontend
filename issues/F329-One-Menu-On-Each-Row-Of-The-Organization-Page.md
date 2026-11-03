# F329 — One Menu On Each Row Of The Organization Page

**Status:** Idea.

**What must be true.** The rows of the organization page look alike and read in one line of actions, whichever roles a
person holds and however wide the window is.

In a walk the operator found the row actions scattered: they sit at different widths, wrap to two lines in some rows and
not in others, and differ from row to row. The operator asks for a redesign, perhaps with only a ⋮ menu on each element.
The cause is in the row: each action is a button of its label's width, in a `Wrap` sharing the row's width with the words.

## What the wish changes

The page was built to the rule *Every action stands visibly in its row*, *not behind ⋮*, and the walk's step counted an action
behind ⋮ as a failure. The first sentence comes from the description of the organization, drawn on a canvas and agreed with the
operator, which gives no reason for it; the words *not behind ⋮* were added when the page was filed. So it is the operator's own
earlier choice, and the operator can change it. If this is built:

- **These go:** that rule, the walk step's failure line, and the same sentence in the description of the organization, which is
  not this repository's to change.
- **The page joins the rest of the interface:** *Machines*, *Projects* and *Forges* already give each row one
  `CommandMenu`, because a row with five actions is wider than the pane.
- **These stay:** a person sees only the actions of their roles, so a row with none shows no menu; a refusal is shown in
  the store's words; a removal still asks first. `CommandMenu` keeps what cannot be run grayed with its reason, which is
  right for an action a person holds and not for another role's.
- **What it costs:** an action is two clicks instead of one and cannot be seen at a glance, which is what the first
  sentence was there to give. *Add me*, and the buttons that add to a section, are not on a row and can stay visible.

Beside it, [F303](README.md#f303) places a row's ⋮ near its text on a wide window; a menu here should follow it.

## Open questions

- Only a ⋮ on every row, as the operator suggests, or the one most used action visible beside it? Recommended: only the ⋮,
  which is what makes the rows alike.
- The project's and the host's pages have rows of buttons too: do they change with this page? Recommended: yes, so the
  three pages stay one design.
