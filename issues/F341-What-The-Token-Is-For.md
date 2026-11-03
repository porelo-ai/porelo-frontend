# F341 — What The Token Is For

**Status:** Accepted.

**What must be true.** A host admin asked for a token reads which forge's token it is, what the host does with it, what rights it
needs and that the host does not keep it, before anything is asked.

In a walk the operator said: "The connection between the token and the host does not make sense to a user. Why *Give it the token*? What
kind of token is it at all?"

## What happens

Read from the code here and from Agent Machines' reading of the host, with one thing measured on a host, read only.

- **In the window:** a terminal reads the token from the person's secrets file, or from what the instance was started with, and sends it
  to the host on standard input. The window neither sees nor keeps it.
- **On the host:** it has no account at the forge, so it needs someone's token to introduce itself there. The first time it adds its
  own read-only key to the organization's repository. For each project waiting, it adds a read-only key of that project to the central
  repository, and copies the repository to the host's own forge once. From then on it reads with those keys.
- **Kept:** held in memory for that one run, and written to no file and no command line. Measured on a host: the copied repositories
  hold no remote and no address with credentials.
- **Rights:** adding a key takes the repository's Administration, write; the copy takes reading its contents. From the forge's API
  rules, not measured on a narrower token.

## The words

Today the line says `The host waits for your central token before it can go on.`, the button *Give it the token…*, and the terminal's
title `Give <host> your central forge token`.

| Where | Proposed |
|---|---|
| Button | *Give it my `<forge>` token…* |
| Line, for a project waiting | `<host> has no account at <forge>, so it needs your <forge> token once, for <project>: it adds its own read-only key to the repository and copies it here. It does not keep the token. The token must be allowed to administer the repository.` |
| Line, for the organization, the first time | `<host> has no account at <forge>, so it needs your <forge> token once: it adds its own read-only key to the organization's repository. It does not keep the token. The token must be allowed to administer that repository.` |
| Terminal's title | `Give <host> your <forge> token, once` |

`<forge>` is the forge's own name where the address says it, such as GitHub. The line in the dialog that puts a project on a host, and
*Not connected yet. The host makes your account once it has your token.* on the host's page, follow the same words. A token given with
nothing waiting goes unused on some hosts and is refused on others, so no line promises either.

This is not the token a later push asks for, which is in the pushing person's own account. Nothing here should read as if it were.

## To be checked

- That the host's forge keeps no token after the one copy, which Agent Machines reads from its database; the sentence waits for that answer. It was not searched, and that is a recollection of how Forgejo behaves. *It does
  not keep the token* rests on this.
- Which of the three lines the host's answer lets the page tell apart.
- Whether a narrower token does.
