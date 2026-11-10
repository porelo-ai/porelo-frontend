# F434 — The Gate's Fetch And Where It Went

```json
{
  "$schema": "issue-1.json",
  "id": "F434",
  "title": "The Gate's Fetch And Where It Went",
  "state": "Review",
  "size": "S",
  "priority": "Medium",
  "rank": 21,
  "blockedBy": [],
  "covers": "The gate's fetch line works from the person's shell; a forwarded push says where its commit stands."
}
```

**Why this size.** the review page's fetch line works from this computer's own shell, and a forwarded push says where its
commit stands.

**What must be true.** For a machine this window reaches through its own ssh config, the fetch line on the gate's
review page carries that config, so the person's shell resolves the machine. Once a push is forwarded, the window says
the branch it went to and where the commit stands under `refs/porelo/forwarded/`, where Approve's answer says so.

## Why

The second move (2026-11-08), finding 16 b and c: the line named `ssh://porelo-move-2`, which nothing on the laptop
resolved; after the forward the incoming ref was gone and nothing said where the commit was. Decided for the third move
(E8); the commit details (16 a) are Core's requirement first.

## Plan

- `lib/src/ui/gate_view.dart` `_OwnClone` and `PendingPush.fetchFrom`: the `GIT_SSH_COMMAND='ssh -F <config>'` prefix
  for such a host.
- Approve's answer read in the IDL; what it names said after the forward.
- Red first: the fetch for a host behind the window's config carries it; the forwarded words.

## As built

Approve answers `forwarded` (the incoming name), `branch` and `pullRequest`, and neither the commit nor the ref
under `refs/porelo/forwarded/`: the window says the branch and the pull request, and the missing ref is a line of
[doc/Contract-Gaps.md](../doc/Contract-Gaps.md). The config is carried only for a machine reached through its card's
own config whose `Host` is the name the line logs in to.

## Acceptance

- The fetch line runs as shown from the person's shell.
- A forwarded push names its branch and its forwarded ref.
