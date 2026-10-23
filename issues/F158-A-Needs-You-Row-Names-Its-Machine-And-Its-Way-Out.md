# F158 — A Needs-You Row Names Its Machine And Its Way Out

**Status:** Accepted.

**What must be true.** Every *Needs you* row names its machine in plain words and offers the action
that resolves it right on the row. A resolved row, and a message once read, does not vanish at
once: it stays a while, newest first, greyed but readable, its actions no longer clickable, a
longer text still opening on a click. How long it stays is a setting, an hour by default.

## Why

A *Needs you* row such as *Vault is locked* does not make clear whether it is for this computer or
for a server, shows only the state without the action that resolves it, and disappears at once when
cleared.

## Acceptance

- Each *Needs you* row names its machine and offers a button or link that starts the resolving
  action on that machine.
- A resolved row and a read message stay greyed, newest first, their actions disabled, a longer
  text still opening on a click, and go after the set time; the setting's default is one hour.
- Seen to fail: when two machines each have a *Needs you* row, both name their own machine and each
  action runs only against its own machine.

## To be checked

- Every place that builds a *Needs you* row and which action resolves each kind.
