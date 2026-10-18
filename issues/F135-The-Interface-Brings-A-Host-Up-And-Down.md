# F135 — The Interface Brings A Host Up And Down

**Status:** Backlog; blocked by [F131](README.md#f131), [F133](README.md#f133), [F134](README.md#f134) and porelo
[B209](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b209).
**Size:** M - one page that runs the command, reads its lines and answers its one stop.

**What must be true.** In a project, a person chooses *Put on a server* and sees the steps of
`porelo-host up` as they come. When it stops for them, the interface asks for the Tresorit login
and the vault's passphrase, and goes on. *Take off the server* runs `down` the same way. No step
needs a terminal, and no secret is written anywhere.

## Plan

- A page beside the project's, which starts the shipped `porelo-host` ([F134](README.md#f134)) by its path with
  `Process.start`. It reads stdout line by line into a list of steps in the shape of
  `lib/src/ui/prepare_view.dart`'s, and shows stderr's words under a refused step with its `fix`.
- **Exit 75:** a form for the Tresorit e-mail and password and the vault's passphrase. Then a
  second `up` is started and the three are written to its stdin, held in memory only and cleared
  after.
- **The provider's key:** asked once on the page and kept by [F133](README.md#f133)'s store.
- **The red test first:** a widget test with a fake process that emits the lines, the stop and
  then done. It holds that the secrets reach stdin and never the arguments, and it is run red with
  the passphrase put in an argument.

## Acceptance

- The page runs `up`, the stop and `down` against the test VM through `GivenMachine`, measured.
  On Windows, the same page with a fake process in the Build's Windows job.
- Seen to fail: a wrong passphrase is shown as the vault's words, and the form asks again.

## To be checked

- How a second factor on the Tresorit account is asked, once porelo-host's HO06 has measured it.
