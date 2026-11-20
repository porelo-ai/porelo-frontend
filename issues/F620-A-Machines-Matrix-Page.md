# F620 — A Machine's Matrix Page

```json
{
  "$schema": "issue-1.json",
  "id": "F620",
  "title": "A Machine's Matrix Page",
  "state": "Estimated",
  "size": "M",
  "priority": "High",
  "rank": 3,
  "blockedBy": [],
  "covers": "Under each machine a Matrix page: its state, Open in the Matrix client, Uninstall…, tiles and lists of what agents ask, unread, agents present and project rooms, and who can reach it"
}
```

**Why this size.** M: a new page over the per-project room data the window reads today (held messages, peers, the
project's room), summed per machine, plus two values the daemon does not give yet (unread, presence).

**What must be true.** On a machine's Matrix page the person sees how its homeserver stands, opens it in their Matrix
client, and sees what agents ask of them (and answers), the project rooms (and opens them), and who can reach the
homeserver: this computer only, no federation.

## Plan

- New `lib/src/ui/matrix_part_page.dart`, routed from `MachineSection.matrix`. Head: state, *Open in the Matrix client*
  (`ElementDesktop` with the machine's homeserver through `HomeserverForwards`, as projects open their room today),
  *Uninstall…* ([F621](README.md#f621)). Not installed: what installing it brings and *Install…*, nothing else.
- Tiles and lists, summed over the machine's projects:
  - asked of you: held messages of kind question (`Held`), each with *Answer*, as *Needs you* answers them;
  - project rooms: projects whose `messages.conversation` is set, each with *Open*;
  - agents present: no daemon value says who is present (`peers` gives sent and received today) — a contract gap;
  - unread: no daemon value — a contract gap; both gaps go into `doc/Contract-Gaps.md` and to the daemon's owner, and
    until they stand each tile says it cannot be read, never 0;
  - who can reach it: the homeserver's own reach, read from the machine (this computer only, no federation).
- The tree's count ([F618](README.md#f618)) is the number of questions asked of the person.
- Tests, unit level first, red first: the per-machine summary over `FakeBackend` (questions, rooms, a project without
  a room, held messages refused), and the unknown unread and presence (harm: a question goes unseen, or unknown reads
  as none).

## To be checked

- Which daemon call can give unread counts and agents present per room, with the daemon's owner.
- Where the homeserver's reach (local only, no federation) is read from.
