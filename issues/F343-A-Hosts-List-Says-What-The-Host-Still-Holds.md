# F343 — A Host's List Says What The Host Still Holds

**Status:** Accepted.

**What must be true.** The list of projects on a host's page shows a project being taken off until the host has let it go, and says why if it
holds on to it.

**The operator:** also on the project's row.

In a walk a project was gone from the owner's list while the host still carried it, and the check of the host failed twice.

## Why

Read from the code, not run. The rows are `host.projects` from `porelo org`, the organization's word. The host's own answer only adds words to a
row that stands there. So a project leaves the list when the take-off is written to the organization, and the host follows up to five minutes
later, or not at all where unpushed commits hold it.

The page has words for that, `held: <why>` and `taken off`, and they can never show: the project they speak of has no row by then. A host
admin cannot see from the page that a project is held, which is the one thing they could act on.

## The shape

For a host admin who is connected, the rows are the organization's projects together with those the host names, each with what the host says:

- the organization no longer names it and the host still carries it: `being taken off, which can take up to five minutes`;
- `held`: `held: <why>`, naming the repositories with unpushed commits;
- `gone`: no row.

Not connected, or no host admin: the organization's word as today, and the line saying so stays.

A test with a host answer naming a project the organization does not, seen red first.

## To be checked

- That the host's answer keeps a taken-off project in `projects` as `held` or `gone`.
- How it fits [F342](README.md#f342), which makes this list read-only.
