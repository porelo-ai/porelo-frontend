# F434 — The Gate's Fetch And Where It Went

**Status:** Backlog.
**Size:** S - the review page's fetch line works from this computer's own shell, and a forwarded push says where its
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

## Acceptance

- The fetch line runs as shown from the person's shell.
- A forwarded push names its branch and its forwarded ref.
