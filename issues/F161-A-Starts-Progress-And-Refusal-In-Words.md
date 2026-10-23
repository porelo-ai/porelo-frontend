# F161 — A Start's Progress And Refusal In Words

**Status:** Idea.

**What must be true.** While *Start it* runs, the interface says in plain words which step is
running and what it waits on, and ends with the cause when something it waits on (such as the
room's homeserver) has failed. When a start is refused for the repository's own `porelo.yml`, the
interface says that the file belongs to the repository, who changes it, and that nothing was
started.

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
