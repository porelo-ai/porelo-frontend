# F350 — A Project Filled From A Checkout

**Status:** Review.

**What must be true.** A person fills a project from a checkout they already have: they choose its folder, see the draft with where each value came from, and sign it into the project, with no terminal.

## How it stands

Under *Organization*, a project's ⋮ *Fill it from a checkout…*, for an Organization Admin or the project's Project Admin. It runs `project init` and shows the draft read-only.

## To be checked

- Against real Core and a real checkout; only Core's named contract is read, and fixtures stand for it.
- Values can only be read in the window, not changed, and a person who disagrees changes the checkout and reads again.
