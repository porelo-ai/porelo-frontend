# F190 — Approved Work Brought To The Central Forge

**Status:** Idea.

**What must be true.** From the interface, a person approves a task's work waiting on the host's forge and brings
approved work on to the central forge, without a terminal on the host.

- **Approve:** the pull request `porelo/<task>` → `main` on the host's forge is shown with its build's verdict, and
  merged from the interface, as the person would merge it in Forgejo's own interface.
- **Bring it on:** the gathered push
  (`porelo-buildtools` [BT06](https://github.com/porelo-ai/porelo-buildtools/blob/main/issues/README.md#bt06)) is
  started from the interface. The central forge's token is asked for hidden and kept nowhere.
- **Its result per repository:** pushed, or refused because the central forge moved, naming the commits and that
  they come to the host's forge as the branch `central/main`.
- A project `offline` offers neither.

## Why

The approval and the gathered push are the operator's two decisions on every piece of work. Today they are made in
Forgejo's interface and by a command over ssh on the host; the interface is where the operator follows the work.

## To be checked

- Whether the gathered push is started through the broker from the interface, so that the interface needs no ssh to
  the host.
