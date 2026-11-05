# F380 — Default On My Projects

**Status:** Review.

**What must be true.** *Default* stands on the main *My projects* page beside the organization's projects, with a row and a page like any other, and the header and the side bar count it.

## Why

`doc/decisions.md` says so. The page of the organization's projects has listed only its own and those of source `local` since it was built, so *Default* stood only behind *All projects on your machines*, a second page also titled *My projects*.

## Acceptance

- One list holds both, and both counts say so. Seen to fail first.
- The row keeps its words and menu, and opens its page.

## Decided while building

- **One row of *Default* for each machine listed,** as on the second page: each has its own, with its own words.
- **While the organization has not been read,** *Default* still stands.

- **The second page stays,** by the operator's word: it lists every project on every watched machine. Whenever the main page stands before it, as it does also for a person of no organization, it is titled *Projects on my machines*, with its back link *My projects*. Only a window with no organization's source at all, where it is the one page, calls it *My projects*.
