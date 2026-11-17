# F608 — A Refused Pull Request Watch Says the Machine's Reason

```json
{
  "$schema": "issue-1.json",
  "id": "F608",
  "title": "A Refused Pull Request Watch Says the Machine's Reason",
  "state": "Implementing",
  "size": "S",
  "priority": "High",
  "rank": 128,
  "blockedBy": [],
  "covers": "When the machine answers a pull request watch with an error of its own, Needs you shows the reason the machine gave and says Refused, instead of saying the machine stopped answering; only a watch that really ended without a word or lost its connection is said that way"
}
```

**Why this size.** S: `PullRequestsRefusedRow.words` and the state chip in `attention_view.dart` tell a machine's
error from a watch that ended without a word. There is a widget test for each.

**What must be true.** A person who sees that a machine's pull requests cannot be read is told why, in the machine's own
words, and is never told that the machine stopped answering when it did answer.

## Found

On 2026-11-17, in a live test on a rented host. The daemon answered `WatchPullRequests` at once with
`org.fuin.porelo.Tasks1.Failed` and the message `no project 'porelo' here. This machine has: default`. *Needs you*
showed "the machine stopped answering about them. They are asked for again." with the state *Not answered*. The
reason the machine gave was nowhere to be seen.

## Plan

- Today: `HostPullRequests._ended` (`lib/src/app/host_pull_requests.dart`) keeps any error as the refusal.
  `PullRequestsRefusedRow.words` speaks only of `MissingHostForgeToken` and `HostPullRequestsRefused`; every other
  error, a plain `VarlinkException` included, falls to "the machine stopped answering about them". In
  `attention_view.dart`, the state chip says *Not answered* for all of them.
- Change: a `VarlinkException` that is not one of the two typed refusals is said as "the machine refused: <its
  `message` parameter>" with the state *Refused*. Only an end without a word (the `StateError` that `_ended` makes) and
  a lost connection keep "stopped answering" and *Not answered*.
- Red first: a test of `PullRequestsRefusedRow.words` with `VarlinkException('org.fuin.porelo.Tasks1.Failed',
  {'message': 'no project ...'})`. Today it says "stopped answering"; after the change it names the message.

## Acceptance

- A watch refused with a plain varlink error shows the machine's message and *Refused*.
- A watch that ends without a word, or whose connection is lost, still says the machine stopped answering.
- The test above fails without the change.
