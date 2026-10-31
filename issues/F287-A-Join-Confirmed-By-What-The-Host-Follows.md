# F287 — A Join Confirmed By What The Host Follows

**Status:** Idea.

**What must be true.** A first Join of a project succeeds when the host follows it as verified. A registry with one
refused commit still offers its healthy hosts. The rows follow each refresh and each registry chosen. No credential
in Core's answer is kept or shown. An unconfirmed join takes down only what it raised itself. Every refusal reaches
the person. Each harm is guarded by a test that goes red when it is there.

Found on 2026-10-31 by the second and last independent reading of [F273](README.md#f273). Each point is to be checked
against the code before it is fixed.

## To be fixed

1. **A first Join always fails:** the join checks the daemon's `Follow` answer for the access commit and the signers,
   but `Follow` answers neither; only `Following` does. So every project the host did not already follow is refused
   after the host recorded it, and its tunnel is taken down.
2. **One refused commit closes every host:** `registry read` answers an accepted revision beside a `refused_commit`.
   The shell and discovery then treat the registry as not read, so no row is offered and a refused host is never
   shown as its own row.
3. **Rows that do not follow the registry:**
   - With no registry chosen, the shell never says so.
   - After switching to a registry whose read fails, the old registry's rows stay.
   - A row Core answers anew after a refresh (new revision, signers, source or card) keeps its old join, which then
     refuses for good.
4. **Identity:**
   - `identity show` names a contact without an accepted card with `name` and `email` null; reading it throws, and the
     join says that Porelo knows no identity.
   - A local login that fails the login rule gets the same wrong words.
   - A watched card machine whose key the person has since rotated is used with the old key.
5. **A watched card machine whose tunnel is not up** (waiting for the key, down or idle) refuses the join instead of
   raising it.
6. **Credentials and malformed addresses kept or shown:**
   - The homeserver is never checked for a credential.
   - A refused row's access repository passes a query, fragment or user part after the host in the user@host:path and
     path forms.
   - A source with `@` after the host, or a bad port, is offered.
7. **Teardown of an unconfirmed join:**
   - Two joins on one host can both skip the release, which leaks the tunnel, its owner and its files.
   - `unpublish` runs after the tunnel queue, so a raise queued meanwhile can lose its live files.
   - A watched card machine under another display name is missed by the same-name check, and its files are removed.
8. **Stored records and words:**
   - A save failure in adding the machine leaves it watched while the join says nothing was saved.
   - The set-aside notice is spoken before the last machine is restored, and is overwritten at once.
   - A stored card record with a stale socket other than `/run/user/` is never moved to the login's socket.
   - The vault unlock's refusal (another port, IPv6, another key) is written where nothing reads it.
9. **Tests that stay green with their harm present:**
   - the fakes answer `follow` with an access commit and signers;
   - the identity fake has no `who_may` contact;
   - the refused host test calls `readJoinable` alone;
   - the unlock refusal test never looks at what the app shows;
   - the shell row test bypasses `appJoins` and the registry.

## Idea

Each point gets a test that goes red with its harm first. These are the fixes in view:
- After `Follow` answers `APPLIED` or `UNCHANGED`, the join confirms by `Following`.
- A refused commit beside an accepted revision is read as read.
- The rows are replaced on each read.
- Teardown runs inside the tunnel queue, owned by the join that raised it.
