# F571 — An Import On The Host Says What It Found

```json
{
  "$schema": "issue-1.json",
  "id": "F571",
  "title": "An Import On The Host Says What It Found",
  "state": "Review",
  "size": "S",
  "priority": "Highest",
  "rank": 16,
  "blockedBy": [],
  "covers": "Story ST361: a remote machine's Import what the agent already has on the host says what it imported, that the agent there holds nothing to import and what to do instead, or the error of a failing call; never nothing at all."
}
```

**Why this size.** One button on a machine's Agents & providers page and the answer it is given; porelo is asked if its answer is silent.

**What must be true.** A press always answers, and its words say which computer it reads.

## Plan

Found live on a test machine, Agents & providers → Anthropic (not authenticated): *Import what the agent already has
there* did nothing on a click: no message, no change. On a fresh server no agent has a sign-in yet, so an import may
find nothing.

- On a remote machine the button reads *Import what the agent already has on the host*. On this computer's own
  page it keeps words that fit there.
- An import that finds nothing says so, e.g. "Claude Code on <machine> holds no Anthropic sign-in to import", and
  says what to do instead (sign in there, or carry one from this computer once ST362 is built).
- A failing call shows its error where the button stands.
- If porelo's answer does not say what it found, Agent Core is asked for that.

## Acceptance

- Guards for found, found nothing and refused, each red first. The authentication view tests green.

## Built

The import did answer, but out of sight: its words stood below the whole *Providers* card, far below the opened row
and its button, and a refused import set the page's own problem, so the providers it had read showed as not read.
Now the answer stands under the button that was pressed (`import-says <provider>`): what was stored, that nothing was
there to import with the next step, that the vault is shut, or the refusal in the error colour. The providers stay
read. The button names where it reads: *Import what the agent already has on the host* on a remote machine, *… on
this computer* on this one, and it waits while an import runs. The authentication scenarios hold each, at the button
and in view; three were red on the old code.
