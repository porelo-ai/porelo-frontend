# F71 — The Sign-In Terminal Shows Where Typing Goes

**Status:** Review; to be walked.

**What must be true.** A terminal that waits for the person's input shows where it goes.

## Why

A code pasted into the sign-in terminal worked, but no cursor showed where it went. In place: the
sign-in terminal and the vault's passphrase terminal always show the cursor while they wait,
whatever runs in them hides. The terminal of a piece of work keeps honoring what runs in it: Claude
Code hides the cursor and draws its own, and a second cursor there would point at the wrong place.

## Acceptance

- **The cursor is shown** in the sign-in terminal while it has the keyboard, and in every terminal
  this interface opens where the program in it does not draw its own. Seen to fail: a widget test of
  the sign-in and passphrase terminals after the program hides the cursor, and the sign-in walked
  with a pasted code.

## To be checked

- **Whose cursor is missing.** Claude Code hides the terminal's cursor and draws its own, and the
  terminal here honors that. If Claude Code's own was not drawn while the code was pasted, the cause
  is Claude Code's, and this requirement is withdrawn.
