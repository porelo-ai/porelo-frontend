# F123 — Where A Machine And A Project Stand In Their Organisation's Tree

**Status:** Accepted.

**What must be true.** A person sees where a machine and a project stand in their organisation's tree,
and which settings bind them, before a start fails on one.

## Why

Porelo is to let an organisation pass settings down to its teams and projects, and make some of them
binding: a lock is `fixed`, or `narrow-only`, where a value below may only get stricter. A machine
follows one organisation file, pinned by its administrator; a project's settings come from its one
path through the tree, organisation, team, sub-team and its own `project.yml`. A project that breaks
a lock starts no task. Without this a person learns of a binding setting only from a refused start.

## Acceptance

- **The machine** shows which organisation it follows, and whether that chain of files is verified and
  current. Nothing is shown where there is none.
- **A project** shows its path in the tree - organisation, team, sub-team - and the settings in force,
  each with the file it comes from and whether it is `fixed` or `narrow-only`: the counterpart of
  `porelo project show --resolved`.
- **A refusal** caused by a lock names the file and the key. A project in no team, under
  `unlisted: refuse`, says so, and who could list it.
- **Where the interface lets a person set a value**, a locked one is shown as locked, and a
  `narrow-only` one shows its bound, before anything is sent.

## Relation

[F62](README.md#f62), an organisation's policy shown, becomes one case of this, since its policy
becomes a locked setting in the organisation file. It is to be folded in at analysis; until then
[F62](README.md#f62) stays as it is.
