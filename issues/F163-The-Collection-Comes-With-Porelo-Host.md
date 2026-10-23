# F163 — The Collection Comes With Porelo-Host

**Status:** Accepted; blocked by `porelo-host` [HO13](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho13), which attaches the
tarball and its `SHA256SUMS` to each release.

**What must be true.** The person never chooses the porelo-host collection. `porelo-host` brings the
collection it was built against, or fetches it from that porelo-host release, and checks its digest
as [F137](README.md#f137) says; the host dialog has no field for it. A chooser exists only in a
development build, to try a collection built from a clean clone.

## Why

The host dialog asks for the collection's tarball as a path, which a person cannot know and which
lets any tarball reach the host's installer. With the collection fixed by the release and its digest
pinned, the field is not needed.

## Acceptance

- In a release build the host dialog shows no collection field, and `up` installs the collection of
  the release the interface was built against, its digest checked.
- In a development build a chooser offers another tarball, named as a test's in the protocol.
- Seen to fail first: today's dialog cannot start `up` with the collection field empty; the test
  starting it without one goes red.

## To be checked

- Whether `porelo-host` carries the tarball in the interface's package or fetches it from the
  release on first use, and where a fetched one is kept.
