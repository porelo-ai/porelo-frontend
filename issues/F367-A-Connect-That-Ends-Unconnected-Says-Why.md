# F367 — A Connect That Ends Unconnected Says Why

**Status:** Review.
**Size:** M - one reading of the state for row and page, words beside *Connect*, a row in *Needs you*, and a kept attempt.

**What must be true.** A person who presses *Connect* is told what came of it, and where to look. In the foo test, *Connect* on the organization's machine row greyed for a moment and returned to the same state, with no words, no log and nothing in *Needs you*. A machine waiting for its token leaves the person with the one button that cannot help.

## Why, by reading

- **`connect()` returns silently in that case.** `OrganizationConnections.connect` treats a failed `raiseFor` as no fault while `_waitsForToken` holds: "a new host makes no account before it has a token", and the connection's files stay for that. This is deliberate, but nothing tells the person. A refusal is thrown only when it does not hold.
- **The step exists, on another page.** *Give it my GitHub token…* stands on the machine's page, and the row does not lead there.
- **Two lists read the state differently.** In the foo test the row under *Organization*, *Machines* said "not connected yet", while the machine's page reached from *Machines* said "Connected". The row asks `up()`, whether the connection stands. The page's "Connected." asks `connected()`, which means a machine is kept here, whether or not its connection is up. That page's sentence is also the one that names the token, and only in passing.

## The shape

- **While a machine waits for the token,** its row and *Needs you* name that step and lead to *Give it my GitHub token…*, not to *Connect* or *Try again now*, for the Machine Admin who can give it. Anyone else reads who it waits for.
- **Every *Connect* that ends unconnected says why beside the button.**
- **The last attempt can be opened,** as *Prepare* does with its protocol.
- **The row and the page say one thing,** from one reading of the state, and "Connected" means the connection is up.

## Plan

1. `HostConnections.waitsForToken` says what the last *Connect* found. The row names the step and leads to the token, for the Machine Admin; anyone else reads who it waits for; *Connect* goes meanwhile.
2. The page says *Connected* only with the connection up, as the row does.
3. A connection closed before login says to wait, in ssh's forms of it, without saying why for certain.
4. The row in *Needs you*, for the Machine Admin, leading to the machine's page, in place of the row saying it cannot be reached.
5. The last attempt's protocol: what `connect()` did and was told, kept in this run for each machine.

## Acceptance

- A *Connect* on a machine waiting for its token ends with words beside the button naming that step. Seen to fail first.
- That machine has a row in *Needs you* for its Machine Admin, leading to the token, and the row goes once it is given.
- A *Connect* refused for any other reason says it beside the button, and the attempt can be opened.
- The row and the page agree in each state: not connected, waiting for the token, connected.

## Decided while building

- **The row goes once the token is given,** and stands under no *Recently resolved*: the connection coming up says so.
- **The last attempt holds this run's steps and what ssh said,** not ssh's full output, which the tunnel does not keep. It is shown while the machine is not connected, on its row, its page and the project's row after a refusal; a disconnect puts it away, and it is lost with the window.
- **A page whose read of the machine fails says that, and offers no token.** The row still leads there, where the refusal stands.

## To be checked

- The same words on the *Machines* page and in *Needs you*'s list of machines, each from its own reading.
- What *Needs you* holds today for a machine that waits, and whether it comes without being connected.
