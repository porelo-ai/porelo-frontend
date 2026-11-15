# F602 — Tokens Used Says Input And Output Apart From Cache

```json
{
  "$schema": "issue-1.json",
  "id": "F602",
  "title": "Tokens Used Says Input And Output Apart From Cache",
  "state": "Backlog",
  "size": "S",
  "priority": "High",
  "rank": 122,
  "blockedBy": [],
  "covers": "A task's Tokens used says the input and output tokens a person can judge, and the cache read and written apart and named, instead of one sum of every kind that reaches 1.5 M within a minute; agreed with Agent Smith on what each agent's input holds."
}
```

**Why this size.** S: the tile's one number becomes input and output with cache named apart, from the totals porelo
already sends; what each agent's `input` holds is agreed first, and tests of each kind's sum and of *at least*.

**What must be true.** A person reading *Tokens used* can tell what the task cost them in fresh input and output,
and sees how much was read from or written to the cache without it swelling that number.

## Found

The operator's read-only runs of 15 November (PI68 *In analysis* and *Under estimation*, tasks `pi` and `pi-2` on a
host): *Tokens used: at least 605 k* after less than a minute, *at least 1.5 M* after one minute; the estimation
51 k at its start.

## Plan

- **Today**, read in the code: `UsageTotals.tokens` (`lib/src/client/models.dart`) sums every kind porelo's `Usage`
  reports (`input`, `cacheRead`, `cacheWrite`, `output`, `reasoning`), and `_WorkFacts`
  (`lib/src/ui/attention_view.dart`) shows that sum, *at least* where any kind has requests that reported no value. An agent reading its context from
  the cache on each request makes `cacheRead` the bulk of it.
- **To agree with Agent Smith** before building: for each agent porelo runs (claude, pi, codex, opencode), whether
  `input` excludes what `cacheRead` and `cacheWrite` count (as Anthropic's usage does) or includes them (as OpenAI's
  prompt tokens do), and whether `reasoning` is counted inside `output`. The window sums only what is apart.
- **Steps.**
  - `UsageTotals` gives fresh input (input less cache where the agent counts it inside), output (with reasoning where
    apart), and cache read and written.
  - The fact reads *12 k in · 3 k out*, with *cache 1.5 M read, 40 k written* beside it in smaller words or its
    tooltip; *at least* only on the kind that missed a value.
- **Red first:** a test of the fact with the live run's shape (cache read far above input), red today on one sum.

## Acceptance

- *Tokens used* says input and output apart from cache, and names the cache. Seen to fail: today's one sum.
- *At least* stands only beside a kind that had requests without a value.
- An agent whose input includes the cache does not count it twice.

## To be checked

- Agent Smith's answer on each agent's fields, cited here.
