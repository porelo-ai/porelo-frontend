# F164 — Putting A Project On A Server, Step By Step

**Status:** Analyzed.
**Size:** M - the host dialog's form becomes a wizard, its words, its walk and the headless walk.

**Order.** After [F161](README.md#f161), before [F155](README.md#f155), [F157](README.md#f157) and
[F154](README.md#f154), which build on the same dialog.

**What must be true.** *Put this project on a server…* asks one thing at a time: each step on its
own screen with what it is for and where its value is found, a step indicator, *Back* and *Next*,
and a summary before anything is rented. The person's own words: the drive named as Tresorit, its
tresor's name apart from its folder on this computer, the project named as a project, and a
public key given as the private one caught before it is used.

## Why

In walk 1 the operator stopped at the dialog's form: one scrolling form of explanation-hungry
fields, where some are always out of view. "Tresor" read as a word of Porelo's or a local vault,
the chosen folder and *The project's tresor* read as the same thing, the title *Put checkout on a
server* read as a verb, nothing said where the Scaleway project id is found, and the two ssh keys
were given swapped with nothing catching it.

## Plan

- **The pattern** is the connection wizard's (`connection_wizard.dart`): a step index, *Back*
  (`wizard-back`) keeping every value, *Next* (`wizard-next`) enabled only when the step's own
  values are complete and valid, and a line *Step n of 5 — <title>* at the top.
- **The steps** of `HostDialog`:
  1. *Where it is rented* — the Scaleway project id, with where it is found (the Scaleway console,
     *Project*, *Settings*) and that the provider's key is the one `porelo-host key set scaleway`
     kept; the account on the server.
  2. *The drive* — "Tresorit, the one drive available today" ([F139](README.md#f139) and
     `porelo-host` [HO16](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho16)
     bring OneDrive); *The tresor's name in Tresorit*, and apart from it *Its synced folder on this
     computer* (picker, remembered), into which the host's files are written; the repository
     address and the signing key, shown once the folder is known.
  3. *Your ssh keys* — the private key first, then the public one, each with *Choose…*; a private
     key whose name ends `.pub`, or whose file begins as a public key, is refused in words.
  4. *The setup file* — the collection, with *Choose…*.
  5. *Check and start* — every value as given, then *Put it on a server*. The steps, the stop and
     its terminal, and *Done*, follow in the same dialog as today, until
     [F154](README.md#f154) moves them to *Machines*.
- **Words:** the title *Put the project <name> on a server*; each step's line says what the value
  is for. `~` expansion, the pickers and the remembered values stay as [F156](README.md#f156) and
  [F155](README.md#f155) build them.
- **The walk:** walk 17 follows the wizard, and its step that opens the project says *Projects* in
  the rail; `integration_test/host_walk_test.dart` follows the same steps headless before any walk.
- **Tests, their harm, red first:** *Next* stays disabled while a step's value is missing or
  invalid, so nothing is rented on half an answer (a rented host that bills and cannot be set up);
  a `.pub` given as the private key is refused before `up` (the same, found only after renting
  today); *Back* keeps every value. The words get no test.

## Acceptance

- The dialog shows one step at a time with *Step n of 5*, *Back* and *Next*, and a summary before
  *Put it on a server*; the drive is named Tresorit, its tresor's name and folder apart.
- Seen to fail first: today a public key given as the private key reaches `porelo-host up`; the
  test holding its refusal goes red on it.
