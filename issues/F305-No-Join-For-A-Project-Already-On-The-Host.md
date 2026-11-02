# F305 — No Join For A Project Already On The Host

**Status:** Idea.

**What must be true.** A project the person already reaches on a card host, admitted there and followed by their
daemon on it, is shown under *Projects* as ready on that host; *Join* is not offered for it.

## Why

A project admitted on a card host and followed there is still offered *Join* on the *Projects* page, as if the
person had not joined it. *Join* then reads as a step left to do.

## To be checked

- Which state the *Join* row reads (the registry's joinable list, the access file, the host daemon's follow) and why
  it does not see the follow on the host; whether the row is built before the host's daemon answers.
- Whether *Connect* per host replaces *Join* before this is built; then the same must hold for *Connect*: a host
  already connected offers nothing to connect.
