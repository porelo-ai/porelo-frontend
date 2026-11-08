# F443 — Forge Token Handed Over When The Machine Asks

**Status:** Idea; waits on the daemon's wire for the hand-over.

**What must be true.** When a machine needs a forge token to start or go on with work, the window says so where the
person is, and the token goes to that machine by the machine's own way of taking one, never through a form of this
program; the work then goes on without a host shell.

## Plan

- Built once the daemon names on its wire how a machine asks for a forge token and how the window hands it over;
  until then nothing here guesses that shape.

## Acceptance

- A start that waits for a forge token says which machine and which forge, and goes on once the machine says it has
  the token; no token is shown, kept, logged or sent over the socket by this program.

## Open questions

- None yet.

## To be checked

- The daemon's wire for the hand-over, field by field, once it is agreed in the channel.
