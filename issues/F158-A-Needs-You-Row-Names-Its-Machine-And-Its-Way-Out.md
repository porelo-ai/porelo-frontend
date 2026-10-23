# F158 — A Needs-You Row Names Its Machine And Its Way Out

**Status:** Idea.

**What must be true.** Every *Needs you* row names its machine in plain words and offers the action
that resolves it right on the row. When a row is resolved, it does not vanish without a trace: it
says briefly *Resolved: \<what\>* and stays readable for a while or in a history.

## Why

A *Needs you* row such as *Vault is locked* does not make clear whether it is for this computer or
for a server, shows only the state without the action that resolves it, and disappears at once when
cleared.

## Acceptance

- Each *Needs you* row names its machine, offers a button or link that starts the resolving action
  on that machine, and shows *Resolved: \<what\>* after it clears.
- Seen to fail: when two machines each have a *Needs you* row, both name their own machine and each
  action runs only against its own machine.

## To be checked

- Every place that builds a *Needs you* row and which action resolves each kind.
