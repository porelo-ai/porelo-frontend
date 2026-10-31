# F287 — A Join Confirmed By What The Host Follows

**Status:** Implementing.

**What must be true.** A first Join of a project succeeds when the host follows it as verified. A registry with one
refused commit still offers its healthy hosts. The rows follow each refresh and each registry chosen. No credential
in Core's answer is kept or shown. An unconfirmed join takes down only what it raised itself. Every refusal reaches
the person. Each harm is guarded by a test that goes red when it is there.

Found on 2026-10-31 by the second and last independent reading of [F273](README.md#f273). Each point is to be checked
against the code before it is fixed.

## Built so far

Each point below has a test that was seen to fail with its harm present, then pass.

1. A `Follow` answering `APPLIED` or `UNCHANGED` is confirmed by reading `Following` and checking the project's entry;
   any other outcome is the refusal in the daemon's words, `VAULT_LOCKED` included. The fakes answer `follow` as the
   daemon does: an outcome and what it pinned, never the access commit or the signers in force.
2. A refused commit beside an accepted revision is read as read: discovery runs on the accepted revision and a host
   whose access file was refused is its own row. A read with no accepted revision, or a fetch or read that failed,
   still offers nothing, with words. The shell no longer gates discovery on the pages' problem; Core's discovery
   decides, read through the app's own registry and `appJoins`.
3. With no registry chosen the status line says so once. A failed read or a switch of registry takes every row and
   join away, and an answer about the registry chosen before never shows under the new one. A row Core answers anew
   gets a new join; one still running is replaced when it ends.
4. `identity show`'s `who_may` contacts with `name` and `email` null are read, named by their login. A login outside
   the host account rule is said in its own words. A watched card account is used only while its card holds the
   person's usable key; otherwise its tunnel and files give way and the tunnel is raised anew with the card now.
5. A watched card account whose tunnel is not up is raised before the join checks it, and refused only if it still
   is not up.
6. Addresses: a user part, query, fragment, `%40` or any `@` after the host is a credential in every form; the
   homeserver is checked as an `https` base URL with no user, query or fragment; a port must be 1 to 65535 and an
   IPv6 host must read as one. A refused row whose access repository may hold a credential names its project instead
   and never keeps or shows the address.
7. Each join holding a tunnel it raised, or shares, is counted per tunnel; the last one to let go of an unconfirmed
   tunnel takes it down, whatever another join on the host does. Removing the published files runs in the host's
   tunnel queue, after a queued raise, and keeps the files of a card the tunnels hold again. A card account watched
   under another name refuses the join with words.
8. A list of machines that cannot be saved after the account was added says so, and a retry saves it. The set-aside
   notice is a row under Needs you, where it stays. A stored card record whose daemon socket is not the login's is
   moved to it. A host vault the tunnel could not unlock is said in the tunnel's words while it is up.
9. Each test the last reading named is now one that goes red with its harm: the follow fakes, the identity fake's
   `who_may`, the refused host read through the registry and `appJoins`, the vault refusal read where the app shows
   it, and the shell rows read through `appJoins` and the registry pages.

## To be checked

- Whether a read ended with a refused commit is told from a failed fetch after it only by the words the registry
  sets (`Porelo refused commit <12> at <path>: `); a flag on the registry's read would say it without them.
- The switch of registry through the dialog is not driven by a test; its rows go through the same path as a failed
  read, which is.
- The whole workflow on the VM, and the operator's walk of a first Join.

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
