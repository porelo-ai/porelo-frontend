# F367 — A Connect That Ends Unconnected Says Why

**Status:** Idea. Nothing is built before the foo test.

**What must be true.** A person who presses *Connect* is told what came of it, and where to look. In the foo test, *Connect* on the organization's machine row greyed for a moment and returned to the same state, with no words, no log and nothing in *Needs you*. A machine waiting for its token leaves the person with the one button that cannot help.

## Why, by reading

- **`connect()` returns silently in that case.** `OrganizationConnections.connect` treats a failed `raiseFor` as no fault while `_waitsForToken` holds: "a new host makes no account before it has a token", and the connection's files stay for that. This is deliberate, but nothing tells the person. A refusal is thrown only when it does not hold.
- **The step exists, on another page.** *Give it my GitHub token…* stands on the machine's page, and the row does not lead there.
- **Two places read the state differently.** A row said "not connected yet" while the machine's page said "Connected". That page's "Connected." comes from `connected()`, which means a machine is kept here, whether or not its connection is up. The page's own next sentence is the one that names the token, and only in passing.

## The shape

- **While a machine waits for the token,** its row and *Needs you* name that step and lead to *Give it my GitHub token…*, not to *Connect* or *Try again now*, for the Machine Admin who can give it. Anyone else reads who it waits for.
- **Every *Connect* that ends unconnected says why beside the button.**
- **The last attempt can be opened,** as *Prepare* does with its protocol.
- **The row and the page say one thing,** from one reading of the state, and "Connected" means the connection is up.

## Acceptance

- A *Connect* on a machine waiting for its token ends with words beside the button naming that step. Seen to fail first.
- That machine has a row in *Needs you* for its Machine Admin, leading to the token, and the row goes once it is given.
- A *Connect* refused for any other reason says it beside the button, and the attempt can be opened.
- The row and the page agree in each state: not connected, waiting for the token, connected.

## To be checked

- Which row said "not connected yet" in the foo test: the words also stand on the *Machines* page and in *Needs you*'s list of machines, each from its own reading.
- What *Needs you* holds today for a machine that waits, and whether it comes without being connected.
- What the last attempt can hold, since `connect()` keeps no protocol today.
