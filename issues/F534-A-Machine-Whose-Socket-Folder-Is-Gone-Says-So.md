# F534 — A Machine Whose Socket Folder Is Gone Says So

```json
{
  "$schema": "issue-1.json",
  "id": "F534",
  "title": "A Machine Whose Socket Folder Is Gone Says So",
  "state": "Backlog",
  "size": "S",
  "priority": "Low",
  "rank": 105,
  "blockedBy": [],
  "covers": "A saved machine whose endpoint lies in a folder that no longer exists says that the folder is gone and how to connect again, rather than that the folder is not the person's alone."
}
```

**Why this size.** S: one more case in the card's connect check, its words, and a test; and the rehearsal of a rented
host removes the machine it added.

Found in walks of an idea to a finished story on a test machine (2026-11-13, runs 29 and 30).
- The account kept a machine `rented` from an earlier rehearsal against a rented host. Its endpoint,
  `/tmp/tmp.<x>/run/porelo-tunnel-rented.sock`, lay in that rehearsal's temporary runtime folder, which was removed
  when the rehearsal ended.
- The window showed it under *My machines* as "Machine rented cannot connect: the folder of …/porelo-tunnel-rented.sock
  is not yours alone." The folder does not exist at all, so the words send the person looking for another user.

**What must be true.**
- Where the folder of a machine's endpoint does not exist, the card says that the folder is gone, names it, and says
  how to connect again (for instance by connecting the machine anew, which makes its endpoint in the window's own
  runtime folder). It makes nothing at a path outside a folder that is the person's alone, as before.
- "Not yours alone" is said only where the folder exists and another user can write to it.
- A rehearsal that adds a machine with an endpoint in a temporary folder removes that machine again at its end.
