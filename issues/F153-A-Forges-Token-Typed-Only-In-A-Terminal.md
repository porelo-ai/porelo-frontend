# F153 — A Forge's Token Typed Only In A Terminal

**Status:** Idea.

**What must be true.** The interface takes no secret into a form of its own; a secret is typed into
a terminal on the machine it is for. Adding or replacing a forge's personal access token opens a
terminal on the machine where the token is typed directly, never into a form field of the
interface.

## Why

The forges view (`forges_view.dart`) asks for a forge's personal access token in a form field of
its own, which breaks the rule set in [F152](README.md#f152) that secrets are typed only into a
terminal on the machine they belong to.

## Acceptance

- Saving a forge's personal access token opens a terminal on the target machine where the token is
  entered, and updates the forge list once the command succeeds.
- Seen to fail: the forges view has no text field that takes a personal access token, and a
  canceled or refused terminal command leaves the stored token state unchanged.

## To be checked

- How `forges_view.dart` hands the token to the daemon today, and which command on the machine
  reads the token from a terminal.
