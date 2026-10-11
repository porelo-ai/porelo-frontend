# F84 — A Signing Key Found Or Made From The Window

**Status:** Analyzed.
**Size:** M - two dialogs, the workspace's key list, a terminal and two desktop dialogs here, with
scenarios; how a key is kept across restarts is still to be decided and may add to it.

**What must be true.** A person whose signing key the ssh agent does not hold can choose it from a
file, or make a new one, from the window; its passphrase is only ever typed in a terminal.

## Why

The window offers only the keys the ssh agent holds, and a desktop keyring loads only the keys
directly in `~/.ssh`. A key in a subdirectory is not offered, and loading it takes `ssh-add` in a
terminal and knowing where to look.

## The shape

- Under the key's choice, the help says where the keys come from and offers two ways on: "Shown keys
  are from ssh-agent. Is your key missing, or do you want to create a new signing key now?", with
  "key is missing" and "create a new signing key" as links.
- "Key is missing": a file dialog chooses the key. A key with a passphrase opens a terminal
  (`ssh-add`), as the vault does; one without is added to the agent directly. Either way, it is then
  chosen in the list.
- "Create a new signing key": the window asks where it goes (path and file name in a field, the
  folder chosen in a directory dialog). The pair is made in a terminal (`ssh-keygen`), so its
  passphrase is typed there. The new key is then chosen.

## Plan

- **Where the key is chosen:** `_BindingDialogState` in `lib/src/ui/binding_view.dart` and
  `_ProjectForgeDialogState` in `lib/src/ui/project_forge_view.dart`, under the dropdown
  `binding-key`. The help and its two links go under it, and also where it is not shown: with one
  key, and where `ProjectWorkspace.signingKeys` refuses because the agent holds none.
- **Key is missing:** `pickWithTheDesktop` in `lib/src/ui/pick_a_file.dart` chooses the file,
  starting in `~/.ssh`. A new method on `ProjectWorkspace` (`lib/src/app/project_workspace.dart`)
  asks `ssh-keygen -y -P '' -f <file>` whether it opens without a passphrase, as
  `MachineSetup.publicKeyOf` in `lib/src/app/machine_setup.dart` does; without one it runs
  `ssh-add <file>` here, with one it hands `ssh-add <file>` to a terminal.
- **The terminal:** `runInATerminal` in `lib/src/ui/unlock_terminal.dart`, whose `Session` runs the
  command given to it on this computer, as the vault's terminal does.
- **Create a new signing key:** a field for the path and file name, a folder from the desktop's
  directory dialog (`getDirectoryPath` of `file_selector`, beside `openFile` in `pick_a_file.dart`),
  then `ssh-keygen -t ed25519 -f <path>` in the same terminal, and `ssh-add <path>` after it.
- **Then chosen:** after each way, `signingKeys` is read again and the key whose public half matches
  the file's `.pub` is chosen.
- **Red first:** a scenario in `test/features/project_from_repository.feature`, "a missing signing
  key is found from the window", that looks for the help and its two links under the key's choice.

## Acceptance

- The help and its two links show under the key's choice. Seen to fail: a scenario in
  `project_from_repository.feature` where either link is missing.
- A chosen key without a passphrase is added to the agent and chosen in the list. Seen to fail: a
  scenario where it is not in the list afterwards.
- A chosen key with a passphrase, and a new key, are handled in a terminal, and the passphrase never
  passes through the window. Seen to fail: a scenario where `ssh-add` or `ssh-keygen` runs outside a
  terminal, or the window has a passphrase field.
- A new key is made where the person said and is then chosen. Seen to fail: a scenario where the key
  lies elsewhere or is not chosen.
- Further criteria follow from the answers below.

## Open questions

- How is such a key remembered across restarts? After a restart the agent no longer holds a key added
  with `ssh-add`. Ways to weigh: the window remembers the key's path and asks `ssh-add` in a terminal
  when it is not in the agent; git's own `user.signingkey` set to the file, so git signs with it
  directly where it has no passphrase; an `IdentityFile` with `AddKeysToAgent yes` in `~/.ssh/config`,
  which loads it only when ssh uses it, not for signing. (the operator's)
- Is a new key uploaded to GitHub as a signing key from the window (it has the token, but needs the
  scope `write:ssh_signing_key`), or does the person add it there? (the operator's)

## To be checked

- Where does a new key lie by default, and what is it called? (Agent Frontend's)
- What does the file dialog refuse: a public half, a key this window made to log into a machine
  (`~/.ssh/sokar-*`), a key type git cannot sign with? (Agent Frontend's)
- **What runs the terminal on Windows**, where `ssh-add` talks to the OpenSSH Authentication Agent
  service. (Agent Frontend's)
