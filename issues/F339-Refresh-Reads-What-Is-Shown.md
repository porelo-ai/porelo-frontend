# F339 — Refresh Reads What Is Shown

**Status:** Review.

**What must be true.** *Refresh* in the rail brings up to date the page a person is looking at, and two buttons of one name on one
page do not do different things.

In a walk the operator clicked *Refresh* at the foot of the rail on a host's page, and the page went on saying a person was locked,
although the host had long said otherwise. Going back and opening the page again showed the new state. The page has a *Refresh* of
its own at the top.

## What each reads

Read from the code, not run.

| | *Refresh* in the rail | *Refresh* on a host's page |
|---|---|---|
| Who sees it | everyone, on every page | a host admin of that host |
| Asks | the standings, the organization, the person's identity, and every connected machine's Porelo | the host's root helper over its own ssh, `org refresh` |
| Does | reads | reads, and first makes the host fetch and apply the organization at once |
| Reaches this page's line | no | yes |

The line about a locked person comes from `_progress`, the page's last answer from the host's root helper. The page asks for it once
when it opens and on its own button, and `_askedProgress` keeps it from asking again. The rail's button never reaches that helper, so
nothing changes and nothing says so.

The kept fields of [F337](README.md#f337) are not the cause, as this is the page's own state, and clearing those would not change it
unless the page was also left.

A project's page has the same gap by another way. It reads again only when a change ends, and the rail's *Refresh* re-reads the
organization without one, so its members and repositories stay as they were.

Later in the walk the journal on the host showed a fetch off the follow's beat, 23 seconds before a click was reported, inside a root connection of two seconds; nothing else at that time fits it. So the page's button does fetch, even with nothing new, in about a second. In the minutes before, three root connections held no fetch, though the walk asked for that click: either it was not made, or it did not reach the host. The page shows nothing either way while it runs and after, so a person cannot tell a click that worked from one that did not.

## The shape

- The rail's *Refresh* reaches the page shown: a host's page asks `org status` again, which only reads, and a project's page reads
  again. A signal on `Organization` that its answers were asked for again would serve both.
- The page's button says what more it does, such as *Fetch now*, with a tooltip: the host fetches the organization now rather than
  at its next follow.
- The page says when the host last answered, so that a click shows even when nothing changed.
- The quiet refresh stays out of this: it goes on leaving the store and the host alone.
- A test for each page, seen red first.

## To be checked

- Whether other pages hold an answer the rail's *Refresh* does not reach, such as the *Organization* page's sections and a project's
  list from `project list`.
