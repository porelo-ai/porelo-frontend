# F611 — A Rebuilt Host Set Up Again Replaces Its Old Files

```json
{
  "$schema": "issue-1.json",
  "id": "F611",
  "title": "A Rebuilt Host Set Up Again Replaces Its Old Files",
  "state": "Backlog",
  "size": "S",
  "priority": "High",
  "rank": 131,
  "blockedBy": [],
  "covers": "Setting a machine up again under a name whose SSH files the window wrote for an earlier setup replaces those files once the person accepted the new host key, so the setup goes on without removing files by hand; files the window did not write are still refused"
}
```

**Why this size.** S: `HostCardSsh.publish` (`packages/porelo_host/lib/src/host_card_ssh.dart`) refuses any of its
three files that differs. It needs to know the files of the card it replaces, as `unpublish` already compares them.
A unit test in the package and one in the setup.

**What must be true.** A person who rents a host again under the same name, or whose host was rebuilt, sets it up
again in the window alone, without deleting files in the window's SSH folder by hand.

## Found

On 2026-11-17, in a live test. The rented host was rebuilt under the same address with a new host key. The setup
stopped at step 9 on its `.conf.known_hosts` file. With that file removed by hand, *Ask again* stopped again:
`publish` checks all three files before it writes any, so the next file, `.conf`, then differed. Only leaving the
setup, removing `.conf` and `.pub` too, and starting over helped.

## Plan

- Today: `publish` calls `HostFileWriter.check` for `.known_hosts`, `.pub` and `.conf`, and every file that differs
  throws `HostFilesRefused`. The error names one file at a time.
- Change: where the setup replaces a machine of the same name, it hands `publish` the card it replaces. A file that
  holds exactly what that old card wrote is replaced. A file holding anything else is still refused, and the refusal
  names every such file at once.
- The new host key is still compared and accepted by the person first, as today. Nothing is replaced before that.
- Red first: a test that publishes card A, then publishes card B under the same name, with A named as replaced. Today
  it is refused; after the change B's files are written. A second test: a hand-edited `.conf` is still refused.

## Acceptance

- Setting up a rebuilt host again under the same name runs through without touching files by hand.
- A file the window did not write is never replaced, and the refusal names all files in the way.
- The tests above fail without the change.
