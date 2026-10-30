# F241 — A Project Followed From A Connected Forge

**Status:** Accepted.
**Size:** M - *Follow a project* chooses from the connected forges' repositories, reads name and signers from the project file, and gives the daemon the forge's kept token without typing it again.

**What must be true.** *Follow a project* offers the forges connected on this computer. After one is chosen, a searchable list shows the repositories its token reaches, those holding a `project.yml` first. The project name and the signers come from the chosen repository's `project.yml`, and the signing key to pin is chosen from those signers. The machine's follow uses the forge's kept token: it reaches the machine's vault as `git.token.<forge host>` from the system secret store, with no second typing and no typed address. Typing an address stays, for a repository on no connected forge.

## Why

Operator's finding in walk 23, step 6-1 on VM A (2026-10-30): "I set up a forge with my personal token. Then I should be able to choose everything in the GUI. Why type everything by hand again when the forge can deliver it directly (with a nice dropdown and maybe a search)?"

Today the forge list (`lib/src/ui/repositories_view.dart`) already lists the token's repositories and marks those with a `project.yml`. But it leads only to *Work on it on <machine>*, which needs push access, commits to `machine-signers`, and asks the person to type the token into the machine's vault in a terminal (`MachineBinding`, `lib/src/app/machine_binding.dart`). *Follow a project by its address* asks for name, address and key by hand.

## Plan

- *Follow a project* starts with *Your forges*: one connected forge preselected, then the searchable repository list (`Forge.repositories`, `hasProjectFile`), projects first. "Follow a project by its address" stays below it.
- On choosing, the interface reads `project.yml` through the forge's API with the kept token. It takes the project's name and `project.signers` and offers the signers as a list, the one matching the person's own signing key on that forge (`signingKeys`) preselected. The follow itself verifies the tip against the pinned key, as today, so a file read here only proposes.
- The token: `porelo-host` gains `key give <forge>`, which writes a kept forge token to standard output only when that is a pipe, never a terminal. A terminal on the machine runs `porelo-host key give <forge> | porelo vault put git.token.<forge host>`; `porelo vault put` already reads a piped value (`VaultPutCommand.valueFrom`). The value never passes through the interface, an argument, a log or the socket. The interface then checks the vault entry by name only, as `MachineBinding.hasToken` does, and follows with `Follow` and its `signedBy`/`signers`. An entry already there is kept, never replaced without asking.
- A daemon on another machine gets the pipe through the machine's ssh connection, the token on the remote command's standard input.
- *Work on it on <machine>* uses the same token step instead of the typed one.
- **Red first:** a widget test that choosing a forge repository with a `project.yml` fills name and signers and follows with the chosen pin; a test that `key give` refuses a terminal on standard output; a test that the pipe command holds no value in its arguments.

## Between the interface's token and the daemon's vault

The forge token lives in the system secret store (`porelo-host key set <forge>`); the daemon reads `git.token.<host>` from its own vault. They meet only in that terminal pipe on the daemon's machine. Core needs no change: `Follow` takes the name, address and pins, and `porelo vault put` takes a piped value.

## Test

Only the change: the tests above and the follow dialog's own tests. A VM test covers only *Follow a project* from a connected forge on one VM, against the real forge, with no rental.
