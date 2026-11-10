# F308 — The Needs You Header Counts What It Lists

```json
{
  "$schema": "issue-1.json",
  "id": "F308",
  "title": "The Needs You Header Counts What It Lists",
  "state": "Idea",
  "size": "-",
  "priority": "Medium",
  "rank": 14,
  "blockedBy": [],
  "covers": "The *Needs you* header, the rail's badge and the rows agree on what needs the person."
}
```

**What must be true.** The *Needs you* page's header, the rail's badge and the rows on the page agree: two tasks
waiting for review are listed, counted "2 need you" in the header and badged 2 in the rail, never "nothing needs
you" above them.

## Why

With two tasks waiting for review on a card host, the page listed both and the rail's badge said 2, while the
header said "nothing needs you". The header counts `needingSomebody` in `lib/src/app/attention.dart`, which takes a
task's row only for a question or an end, not for a push waiting at its gate; the badge counts every open row.

## To be checked

- Whether a push waiting for review is to count as needing the person (then the header takes it too), or is listed
  apart and counted by neither; the page, the header and the badge follow the one answer.
