# F168 — The Locked-Vault Row Says Which Vault And Project

**Status:** Backlog; blocked by `porelo` [B276](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b276).
**Size:** S - one row's words and one more way out on it, from two new fields of the daemon.

**What must be true.** A *Messages wait* row for a locked vault says whose vault it is (the vault
on this computer, or on a named machine) and that what it holds up are projects, by name, with
when each was last used; its unlock button stands first, and a project no longer used offers to
stop following it.

## Plan

- **Today**, read in the code: `Attention.messagesWaiting` groups the daemon's `messages.waits` and
  `waitsOn` per machine (`attention.dart`); the row shows the daemon's text and
  `Held up: <names>` (`attention_view.dart`). *Unlock the vault on <machine>*
  (`unlockWaitingMessages`, `commands.dart`) already opens the vault in a terminal for
  `waitsOn == "vault"`. Stopping to follow exists as `project.delete` with its preview
  (`project_deletion.dart`, `Unfollow`).
- **From [B276](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b276):**
  `ProjectMessages.vault` (the path of the vault the daemon checked) and `Project.lastUsed`. The row
  reads *The vault on this computer is locked* for the local machine, *on <machine>* otherwise,
  shows the path in small type, and lists *Projects held up:* with each name and its last use in
  words (*last used 1 day ago*, *never used here*). An older daemon without the fields keeps
  today's words.
- **Way out:** the unlock command is the row's first button. Each held project gets *Stop
  following <project>…*, a `Command` with `home: Home.attentionRow` opening the existing preview for
  that project on that row's machine; nothing is removed before its confirmation.
- **Tests, their harm, red first:** on a row holding two projects, stopping one opens the preview
  for that project on that machine and calls `Unfollow` only after confirmation (another project or
  unreviewed work removed). Words get no test.

## Acceptance

- In the guided walk, the row names the vault and the projects as above, unlocks through its
  first button, and *Stop following* opens the preview of the chosen project only.
