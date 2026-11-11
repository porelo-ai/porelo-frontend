# F489 — The Fallback Ubuntu Mirror Removed After The Outage

```json
{
  "$schema": "issue-1.json",
  "id": "F489",
  "title": "The Fallback Ubuntu Mirror Removed After The Outage",
  "state": "Idea",
  "size": "XS",
  "priority": "Medium",
  "rank": 11,
  "blockedBy": [],
  "covers": "Once Canonical's Ubuntu archive answers again, cached-apt no longer points Ubuntu's sources at a fallback mirror after giving up on Canonical's, and a miss fetches from Canonical's archive alone, as before the outage of 2026-11-11."
}
```

**Why this size.** One block and one variable in `.github/actions/cached-apt/action.yml`, proven by a Build whose
cache misses.

**What must be true.** The build takes Ubuntu's packages from Canonical's archive only, with no mirror of another
operator named in the workflows.

## Why

- On the operator's order of 2026-11-11, during Canonical's outage (status.canonical.com, from 11:06Z), the miss path of
  `cached-apt` was given a fallback: once `pinned_retry` gives up on Canonical's archive, Ubuntu's sources are rewritten
  to `https://mirrors.edge.kernel.org/ubuntu/` and the fetch is tried again. It was marked temporary.

## Plan

- Delete the `fetch || { … }` fallback block and `FALLBACK_MIRROR` from the step *Fetch Ubuntu's packages from the
  mirror*; `fetch` alone stays.

## To be checked

- That Canonical's incident is closed before this is built.
