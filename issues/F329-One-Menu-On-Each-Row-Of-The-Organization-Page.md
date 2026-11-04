# F329 — One Menu On Each Row Of The Organization Page

**Status:** Review.

**What must be true.** The rows of the organization page look alike and read in one line of actions, whichever roles a
person holds and however wide the window is.

Read from the code, not run. `_Row` in `lib/src/ui/organization_page.dart` puts its actions in one
`CommandMenu`. Its machine rows use `OrganizationMachineRow` in `lib/src/ui/organization_host_pages.dart`,
with *Connect* visible while not connected and one menu for the other actions.
`OrganizationPage._hosts` adds `takeOff` once to each machine's commands.

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
