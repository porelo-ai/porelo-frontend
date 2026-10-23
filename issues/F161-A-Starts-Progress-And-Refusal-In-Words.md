# F161 — A Start's Progress And Refusal In Words

**Status:** Accepted; blocked by `porelo` [B268](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b268), which reports a task's start step by step,
and by `porelo-host` [HO21](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho21), which gives each step a plain-words text.

**What must be true.** While *Start it* runs, the interface says in plain words which step is
running and what it waits on, and ends with the cause when something it waits on (such as the
room's homeserver) has failed. When a start is refused for the repository's own `porelo.yml`, the
interface says that the file belongs to the repository, who changes it, and that nothing was
started.

The interface only shows these texts. Each comes from where its step is defined, never written a
second time here: a task's start from porelo's daemon, a host's steps from the collection through
`porelo-host`'s JSON step lines. The interface writes texts only for its own actions.

## Why

While *Start it* runs, the person sees only a trailing line such as `snippet…`, with no plain-words
step and nothing saying it waits on a homeserver that has already failed. When a start is refused
for `porelo.yml` (such as `'image.env.LANG' is set by Porelo and cannot be set here`), the
interface shows only `porelo`'s words without saying whose file it is or whether anything started.

## Acceptance

- During a start, the view shows the current step and what it waits on in plain words, stops with
  the cause when a required service has failed, and on a `porelo.yml` refusal states that the file
  belongs to the repository, who changes it, and that nothing was started.
- Seen to fail first: a start whose homeserver fails today shows only the last output line until
  it times out; the test that holds the named cause goes red on it.

## To be checked

- Which progress events or lines the daemon sends during `Start` while waiting on the room's
  homeserver, and how `porelo.yml` refusals arrive from the daemon.
