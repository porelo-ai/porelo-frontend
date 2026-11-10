# F282 — The Providers' Usage In A Status Line

```json
{
  "$schema": "issue-1.json",
  "id": "F282",
  "title": "The Providers' Usage In A Status Line",
  "state": "Idea",
  "size": "-",
  "priority": "Medium",
  "rank": 28,
  "blockedBy": [],
  "covers": "A status line with one traffic light for the providers' usage, a popup per provider, and a *Needs you* warning past a set threshold."
}
```

**What must be true.** A status line at the bottom of the window shows the usage of the providers in use as one
traffic light for all of them. A click opens a popup with the exact status: one line per provider, each with its own
traffic light. When a provider enters its critical range, a warning is also put in *Needs you*. The thresholds can be
set. The exact design is worked out in the specification.

## Idea

- First display of a new status line: the providers' usage. The single traffic light shows the worst provider.
- The popup lists one line per provider with its numbers: what is left, the window it counts over, and when it
  resets.
- The critical thresholds can be set, per provider or for all. Crossing one adds a *Needs you* entry, which goes away
  once the provider is out of the range again.
- Possibly the popup also lists the running agents that use that provider right now.

## Where the numbers come from

- Today a local script reads them by hand, on the machine it runs on:
  - agy: the *Limit Remaining* lines of `agy -p /usage`;
  - Codex: the last `rate_limits` entry in its newest session file under Codex's session folder;
  - Claude Code: the session and week lines of `claude -p /usage`.
- The interface reads no tool's output or session files itself. It reads Core through `--json`.
- So this needs a Core verb that answers the usage per provider in one form: provider, window, part left, reset
  time, and when it was read. It must say which machine and account each number is for, as the agents can run on
  more than one machine.
- Agents running per provider can come from the agent rows the interface already reads, if those name their provider.
  Otherwise the verb names them as well.

## To be decided

- How often the usage is read. Each read runs the providers' tools and costs time, and for some of them quota too.
- The traffic light's colors, and its state when a provider cannot be read.
