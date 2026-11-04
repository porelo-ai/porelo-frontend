# F359 — An Empty List Starts Folded

**Status:** Review.

**What must be true.** A list with nothing in it starts folded on a first visit, and folds when it is emptied, so the page shows what holds something; a fold the person chose is kept, and an action on the list's head stays usable while it is folded.

## The shape

**The rule:**

- **A first visit:** a foldable list with no rows starts folded, with its count 0 in its head; one with rows starts open.
- **A list that is emptied** folds, and **one that gets its first row** opens, unless the person folded or opened it themselves.
- **The person's choice wins:** a list they folded or opened stays so for as long as the window keeps it, today until it is closed.
- **On a narrow window** the lists that start folded there go on doing so, with rows or without.
- **The head stays whole:** its title, count and actions, such as adding a machine, while the list is folded.

## Why

`FilteredListSection` starts open by `initiallyOpen`, true for all of them, and a narrow window folds those marked `openWhenCompact: false`: on the organization page *Projects*, *Machines*, the owners and the Admins. The row count plays no part. So the window opens all on a wide one and folds those four on a narrow one, while what was seen in the foo test, *Projects* and *Machines* folded and *People*, the owners and the Admins open, is not what a first visit gives by this code. Most likely a fold kept from earlier in that session; that is read, not seen.

## Acceptance

- On a first visit, an empty list is folded and shows 0, and its action works while it is folded; a list with rows is open. Seen to fail first.
- Removing a list's last row folds it; adding a first row opens it; neither overrides a fold the person chose.
- A narrow window behaves as it does today for a list with rows.

## Checked

- **No foldable list holds an action in its body:** each of the ten has its actions in its head; the body of an empty one holds only the words that nothing is supplied, which the count 0 says while it is folded.
- **A list loading its rows** reads as empty for that moment, such as a forge's repositories. It folds and opens again with its first row, and nothing of it is remembered, since only a press of the person, or a row the window was asked to show, counts as a choice.
