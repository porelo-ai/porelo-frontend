# F118 — An Upstream That Cannot Be Read Said Before A Start

**Status:** Idea.

**What must be true.** Where the daemon finds before a start that the repository's upstream cannot
be read, the start dialog says why and what fixes it, the way it says an unknown host key today:
a key the upstream refused, a repository not found, a host not reached, or the upstream unreadable
for another cause. Where a mirror is already there and the start goes on, the warning is shown
beside it, not lost.

## Why

`sokar` [B181](https://github.com/sokar-ai/sokar/blob/main/issues/base/README.md#b181) has the
daemon read the upstream with the clone's own credential before a gated start. `CanStart`'s outcome
grows by `UPSTREAM_KEY_REFUSED`, `UPSTREAM_NOT_FOUND`, `UPSTREAM_UNREACHABLE` and
`UPSTREAM_UNREADABLE`, each with a detail naming the command that fixes it, and `Start` gets the
error `UpstreamUnreadable`. Until the interface knows them, they arrive as an outcome it has no
words for. It waits for Core's commit with the `.varlink` change.
