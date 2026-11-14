# F372 — An Unattended Agent's Console Reads What It Did

```json
{
  "$schema": "issue-1.json",
  "id": "F372",
  "title": "An Unattended Agent's Console Reads What It Did",
  "state": "Idea",
  "size": "-",
  "priority": "Medium",
  "rank": 6,
  "blockedBy": [],
  "covers": "An unattended agent's console reads its text and what it did, in summaries, in place of one line per tool."
}
```

**What must be true.** An unattended agent's console reads as a terminal does: its text and what it did, in summaries such as "Read 4 files", in place of `[Bash]`-style lines.

## Why

The drawn console of the redesigned work cards shows these summaries, and today's log gives one line per tool. That page is built on today's lines and does not wait for this.

## To be checked

- With the agent adapters' repositories: how the console gets its text and what the agent did.
