# F431 — The Setup Wizard After The Second Move

**Status:** Review.
**Size:** M - the wizard shown as the one dialog it is, a *Run it for me* button for the bootstrap line, and the
machine's row asked again once its token was given.

**What must be true.** *Set up a machine* is one card, not a card in an empty frame. On *Hand the login over* a person
can press *Run it for me*: the window runs the bootstrap line itself, logged in as the first login through the compared
key, and tries root's login right after; where `sudo` wants a password or the login cannot be made unasked, it says so
and the terminal is the way, as today. After a token was handed over, the machine's row says what the machine now says,
without *Refresh*.

## Why

The second move (2026-11-08), findings 3, 5 and 7. The operator decided: a button, never by itself (E5); the small
fixes (E10).

## Plan

- `lib/src/ui/shell.dart`: the wizard shown bare by `showDialog`, as `FirstStartWizard` and `StartAgentsWizard` are;
  `Wizard.build` already is the `AlertDialog`.
- `lib/src/app/server_first_login.dart` / `server_setup.dart`: `runBootstrap()` runs the line with each `sudo` as
  `sudo -n`, over ssh as the first login through the pin, `BatchMode=yes`; its answer is ran, needs a password, or
  could not log in, in words; on ran it tries root's login.
- `lib/src/ui/server_setup_wizard.dart`: *Run it for me* (filled) beside *Open a terminal on the server*, busy while it
  runs; its words under the buttons.
- `lib/src/ui/shell.dart` `_giveTokenFrom`: after a hand-over that succeeded, `connections.progress(host)` once.
- Red first: the wizard is not inside a `Dialog`; *Run it for me* runs the `sudo -n` line and then root's login; a
  password asked is said with the terminal offered; the row leaves "waits for a first token" after the hand-over.

## Acceptance

- One dialog, no empty frame.
- *Run it for me* runs only on a press, and root's login follows it; a password wanted is said, the terminal offered.
- The row follows the machine after the token, no *Refresh* needed.
