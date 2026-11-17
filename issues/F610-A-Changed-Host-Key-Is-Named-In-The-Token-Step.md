# F610 — A Changed Host Key Is Named in the Token Step

```json
{
  "$schema": "issue-1.json",
  "id": "F610",
  "title": "A Changed Host Key Is Named in the Token Step",
  "state": "Backlog",
  "size": "XS",
  "priority": "Medium",
  "rank": 130,
  "blockedBy": [],
  "covers": "Where the window cannot write a machine's SSH files because one it wrote before differs, the token step says that the files of an earlier setup are in the way and which, instead of saying the machine could not be reached"
}
```

**Why this size.** XS: `HostTokenSources.ask` and `handOnDeclared` (`lib/src/app/host_token_sources.dart`) wrap every
error from `connect()` in the same words. A `HostFilesRefused` gets words of its own. One unit test.

**What must be true.** A person whose machine setup stops on files from an earlier setup is told that, not that the
machine could not be reached.

## Found

On 2026-11-17, in a live test, setting up a rented host again after it was rebuilt under the same address. Step 9
said "<host> could not be reached, so no source was asked: …conf.known_hosts already exists and differs
or is not a regular file". The machine was reachable; the window's own pin of the old host key was in the way.

## Plan

- Today: both `catch` blocks in `host_token_sources.dart` (around lines 272 and 307) say
  "$host could not be reached, so no source was asked: $error" for any exception.
- Change: a `HostFilesRefused` from publishing the card's files is said as "The SSH files of an earlier setup of
  $host are in the way: <its words>". Only a failed connection keeps "could not be reached".
- Red first: a unit test whose `connect` throws `HostFilesRefused`. Today the problem says "could not be reached";
  after the change it does not.

## Acceptance

- A refused file write is not said as an unreachable machine.
- A connection that fails still says the machine could not be reached.
- The test above fails without the change.
