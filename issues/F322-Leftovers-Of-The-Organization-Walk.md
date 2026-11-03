# F322 — Leftovers Of The Organization Walk

**Status:** Review.
**Size:** S - one small change per point, no Core change.

**What must be true.** Small things a walk of the organization's pages in the window found, none of them wrong:

- *Make a backup key…*: the terminal shows Core's raw JSON before *Done*. The window needs the answer, the person does
  not.
- A write takes seconds, and the page shows nothing until it is read back. Controls are off during a lock, while the
  *Remove* links stay on. One mark that a change is under way would say so everywhere alike.
- *Choose another organization*: a refusal stays under the field while the person types another address. The answer to
  an empty repository names `porelo org create`, which this dialog offers no way to.
- *the organization has moved on*, under a change someone else's write overtook: the page has read the new state and the
  same choice then goes through, but the words do not say to ask again.
- The list under *Projects* calls a person *member* where the project's own page calls them *developer*.

**Plan.** One change per point. What only reads wrong gets no test; the terminal's answer has one seen red, since a wrong erase would wipe all a failure said.

## From the reading of the rework

- Two refused changes on one project hide one another on the organization's project list: `withOrganizationChanges` keys them by the row's name, so the later refusal covers the earlier, which stands on the project's page or shows once the later is dropped.
- `Organization.write` has no `finally` around asking: an `Error`, not an `Exception`, leaves `busy` true and the row running. No path to one was found.
- *Open the project* hands the token of the organization's forge, not of the project's central repository. It matters only where the two differ, and Core then refuses for lack of a token.
