# F84 — A Signing Key Found Or Made From The Window

**Status:** Estimated.
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
- **Remembered across restarts:** the window keeps the key's path in `frontend.json`
  (`lib/src/app/settings.dart`). When the agent does not hold it, the key's choice offers
  `ssh-add <path>` in a terminal, so its passphrase is typed once a session.
- **At GitHub:** a new key is added there by the person. The window shows its public half with a
  Copy button and the link to GitHub's page for a new signing key; the token needs no
  `write:ssh_signing_key`.
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
- After a restart, a remembered key the agent no longer holds is offered for `ssh-add` in a terminal.
  Seen to fail: a scenario that restarts with the path kept and the agent empty, and finds no offer.
- A new key's public half is shown to copy, with the link to add it at GitHub. Seen to fail: a
  scenario that makes a key and finds neither.

## To be checked

- Where does a new key lie by default, and what is it called? (Agent Frontend's)
- What does the file dialog refuse: a public half, a key this window made to log into a machine
  (`~/.ssh/sokar-*`), a key type git cannot sign with? (Agent Frontend's)
- **What runs the terminal on Windows**, where `ssh-add` talks to the OpenSSH Authentication Agent
  service. (Agent Frontend's)
