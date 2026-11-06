# F405 — A Host Is Given The Vault's Token For The Organization

**Status:** Accepted (operator, 2026-11-06).
**Size:** S - the machine page's *Give it my token…* finds the declaration matching the organization's forge address,
names it, and has Porelo hand it on; blocked by porelo's verb for that.

**What must be true.** Where the machine's vault holds a token declared for the Porelo organization's forge address,
*Give it my GitHub token…* on a machine's page offers that one, named by its declaration and never shown, beside
pasting another; the window never reads its value, and says which one it gives.

## Why

The operator's walk on the rehearsal VM (2026-11-06): on rehearsal's page, *Give it my GitHub token…* answered at once
"No GitHub token is kept on this computer, so rehearsal was given none", though the machine's vault holds a token
declared for `https://github.com/porelo-ai/` by the command line. It blocks a person who set up by the command line;
the workaround is signing in under *My forges* with the same token. The window looks only in its own token store
(`ForgeConnections.hasToken`) and the secrets file, never at Porelo's declarations.

## Plan

- Which declaration: `Credentials().connections`, kind `TOKEN`, purpose `git` or `any`, whose `match` is the longest
  prefix of the organization's address (`organizationForgeAddress`), present now; the daemon serves this already.
- Giving it: **a part in porelo**, since no value may leave Porelo and the window has no way to hand on a vault entry:
  a command that pipes the vault entry a declaration names to `org refresh` on the host, over the host card's pinned
  ssh, as root, the way the window feeds its own kept token now (`organizationRefreshFeedCommand`), answering what the
  host said with the value taken out. Its form is Core's to name.
- `lib/src/ui/shell.dart` (`_giveHostToken`): where such a declaration exists, the confirmation names it ("the token
  declared on this machine for https://github.com/porelo-ai/, in its vault") and runs Porelo's command; pasting
  another stays offered; where none matches, as today.
- **The test that goes red first:** a widget test of the machine page with a machine whose connections declare a token
  for `https://github.com/porelo-ai/` and no token in the window's store: *Give it my token…* names that declaration
  and runs Porelo's command with its id, never "No GitHub token is kept". It guards a host left with no token, and a
  value read by the window that it does not need.

## Blocked by

- porelo's command that hands a declared vault token to a host's `org refresh` (to be filed by Agent Core).

## Done

Built against Agent Core's local commit 7be32f40 (branch `work-b478-codex`, porelo's `org host refresh HOST --json`
answering `handedOver`), read only by `git show`.

- `host_token.dart`: `declaredOrganizationToken` picks the declaration for the organization's repository address,
  kind `TOKEN`, purpose `git` or `any`, present, longest match, with `git@host:path` and `ssh://` read as https;
  `declaredTokenWords` names it and says Porelo hands it on, never this window.
- `OrganizationSource.handTokenTo`, run by `PoreloOrganizationSource` as `porelo org host refresh HOST --json`; a
  refusal stands in porelo's words.
- `shell.dart` `_giveHostToken`: where the vault declares one, the confirmation names it, *Give it* has Porelo hand it
  on, and *Give another…* goes on to the window's kept token or the secrets file as before.

Red first: none of it existed, so the two tests (the declaration chosen, the verb and its refusal) did not compile
against the old code. The dialog in the shell has no test of its own: the shell's machine page needs the whole window
standing; the operator's walk on rehearsal checks it.

