# F164 — Putting A Project On A Server, Step By Step

**Status:** Implementing.
**Size:** L - a wizard frame of its own, the host dialog as its first wizard, its words, its walk and the headless walk.

**Order.** After [F161](README.md#f161), before [F155](README.md#f155), [F157](README.md#f157) and
[F154](README.md#f154), which build on the same dialog.

**What must be true.** *Put this project on a server…* asks one thing at a time: each step on its
own screen with what it is for and where its value is found, a step indicator, *Back* and *Next*,
and a summary before anything is rented. It runs on a wizard frame of the interface's own, which
other wizards use as well. The person's own words: the drive named as Tresorit, its tresor's name
apart from its folder on this computer, the project named as a project, and a public key given as
the private one caught before it is used.

## Why

In walk 1 the operator stopped at the dialog's form: one scrolling form of explanation-hungry
fields, where some are always out of view. "Tresor" read as a word of Porelo's or a local vault,
the chosen folder and *The project's tresor* read as the same thing, the title *Put checkout on a
server* read as a verb, nothing said where the Scaleway project id is found, and the two ssh keys
were given swapped with nothing catching it.

## Plan

- **Today**, read in the code: two wizards, each hand-built. The connection wizard
  (`connection_wizard.dart`) keeps an index and a `switch` over three panels, with *Back*
  (`wizard-back`), *Next* (`wizard-next`) and its own last button; the new machine's steps
  (`new_machine.dart`) are six numbered titles in one scrolling column, most of them actions run on
  a machine. Neither shares anything with the other.
- **The frame, `lib/src/ui/wizard.dart`.** A wizard is declared as a title and a list of steps; the
  frame owns everything a person meets the same way in every wizard:
  - the line *Step n of N — <title>* and the step's words under it;
  - *Back*, which keeps every value given, *Next*, enabled only when the step's check passes, and
    *Leave*, which asks before dropping values given;
  - the reason a step cannot go on yet, said under *Next*, from the step's check;
  - a last step *Check and start*, made by the frame from every step's summary lines, whose button
    names the action (*Put it on a server*);
  - one step's panel at a time, scrolled only within itself, and the first field focused.
- **A step provides:** its `title`; its `words` (what it is for and where its value is found); its
  `panel`, the widget with its fields; its `check`, null when it may go on, else the reason in
  words; and its `summary`, the lines it adds to *Check and start*. A step keeps its own values, so
  *Back* and *Next* lose nothing.
- **A step that waits on something outside** is an action step: it runs (`porelo-host up`, a
  login), shows its progress in its panel, and reports *running*, *waiting* (a stop, with the
  panel showing what is needed, such as the host's terminal of [F152](README.md#f152)), *done* or
  *refused* with its words. While it runs, *Back* and *Leave* ask first; *Next* follows *done*. The
  host's steps, stop and *Done* are such a step after *Check and start*, until
  [F154](README.md#f154) moves them to *Machines*.
- **What moves onto it:** the host dialog now. The connection wizard (three panels) and the new
  machine's steps (six, action steps) move later, each as an issue of its own, so the walks of 15
  and 16 are walked again with each. The keys `wizard-back` and `wizard-next` stay, so walks and
  tests that use them keep working.
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
- **The frame's tests, their harm, red first:** *Next* is disabled while a step's check fails
  (nothing started on half an answer); *Back* keeps every value; *Leave* asks before dropping
  values; an action step that is running cannot be left without asking (a rented host forgotten
  mid-`up`). The indicator, the words and the summary's look get no test.
- **The host dialog's tests, their harm, red first:** *Next* stays disabled while a step's value is missing or
  invalid, so nothing is rented on half an answer (a rented host that bills and cannot be set up);
  a `.pub` given as the private key is refused before `up` (the same, found only after renting
  today); *Back* keeps every value. The words get no test.

## Acceptance

- The dialog shows one step at a time with *Step n of N*, *Back* and *Next*, and a summary before
  *Put it on a server*; the drive is named Tresorit, its tresor's name and folder apart.
- The host dialog is declared on `wizard.dart`'s frame, and the frame holds nothing of the host:
  a second wizard can be declared on it with steps of its own.
- Seen to fail first: today a public key given as the private key reaches `porelo-host up`; the
  test holding its refusal goes red on it.
