# F162 — The Host Flow Walked Against Stand-Ins

**Status:** Estimated.
**Size:** M - a choice in the app, two tools beside the mock daemon, a walk and their tests.

**Order.** Before the host flow ([F152](README.md#f152), [F154](README.md#f154) to
[F157](README.md#f157)), whose walks need it.

**What must be true.** In a development build, the guided walk drives the whole host flow on this
computer with no rented host: a stand-in `porelo-host` answers with the steps, stops, refusals and
`down` a person may meet, the host it reports is reached like any machine, and its terminal steps
ask as the real ones would. A release build has none of it.

## Why

A flow the person steps through is walked with the operator in its Review before it goes to a VM or
a rented host. Today the host dialog runs a fixed `porelo-host` (`shippedPoreloHost`,
`host_session.dart`), and the only stand-in is a small `sh` script inside `host_dialog_test`, so
the host flow can be tried only on a real host.

## Plan

- **The command the dialog runs.** `shippedPoreloHost()` (`lib/src/app/host_session.dart`)
  becomes `poreloHost({environment, release = kReleaseMode})`: in a development build with
  `PORELO_HOST_STANDIN` naming an executable it returns that path, otherwise the shipped one.
  `HostDialog._newSession` and `ShellState._poreloHostIsHere` (`lib/src/ui/shell.dart`) both take it,
  so *Put on a server* is offered when the stand-in is there and nothing is installed. Red first: a
  unit test naming a stand-in with `release: false` expects its path and gets
  `/usr/lib/porelo-frontend/porelo-host`; the same with `release: true` keeps the shipped path.
- **The stand-in `porelo-host`, `tool/host_standin.dart`.** Built with `dart compile exe`, like the
  real one. It writes its lines with `package:porelo_host`'s own `Step.toLine()` and ends with its
  `Exit` codes, so the interface reads it as the real command. Its situation and state are in one
  file, `host-standin.json` in the walk's folder, which it reads at each run and which can be
  changed between two runs of a walk: `clean` (every step, then `up` done naming the host),
  `stop` (stops with `needs`, exit 75; the second `up` goes on), `refused` (a step refused with its
  `fix`, exit 65), `slow` (one step taking a minute), and `down` with its `give-back`. The answers
  that come on standard input are read and dropped, never written. It already writes the `text`
  and `seconds` of `porelo-host`
  [HO21](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho21) on each started
  step, which today's reader ignores, so the walks of [F154](README.md#f154) and
  [F161](README.md#f161) need no new stand-in.
- **The host reached through the mock daemon, without a kind of machine for the walk.** The host
  `up` reports is added as today: kind `host`, `account@address` (address `192.0.2.10`, a
  documentation address), a socket under `/run/user/`. What stands in is the transport: a stand-in
  `ssh`, `tool/ssh_standin.dart`, first on the interface's `PATH` in the walk only. For `-N -L
  local:remote` it listens on `local` and joins each connection to a second mock daemon
  (`dart tool/mock_daemon.dart empty <socket>`), whose socket `PORELO_WALK_HOST_SOCKET` names; it
  answers `-G` as ssh would. Any other form ends non-zero saying which form it does not stand in
  for. The terminal steps of [F152](README.md#f152) and [F157](README.md#f157) add their `-t` forms
  to it when they are built.
- **The walk.** `doc/walks/17-the-host-flow.json` walks today's dialog: up to the stop, on, the host
  in *Machines*, then down; `test/walks_test.dart` already holds its keys. `doc/guided-walk.md` gets
  the commands that build both stand-ins and start the interface with them.
- **Tests,** each naming its harm: the release build never runs a named stand-in (work leaving for a
  fake host, or an executable from the environment run by a shipped build); every line of each
  situation is read by `Step.fromLine` with the exit code `HostSession` expects (a contract the
  interface reads); an answer never reaches the state file (a secret written to disk); the stand-in
  `ssh` carries bytes both ways and refuses a form it does not know (a hang or a silent wrong
  command).

## Acceptance

- A development build started with the walk's folder and a stand-in named runs that stand-in in
  place of the shipped `porelo-host`; a release build ignores it, and a test holds both.
- The stand-in is a tool beside `tool/mock_daemon.dart`, with situations to choose: a clean `up`,
  a stop that needs the person, a refusal with its fix, a slow step, `down` and its give-back. It
  writes the same JSON step lines as `porelo-host`, so the interface cannot tell it apart.
- The host the stand-in's `up` reports is reached through the mock daemon's socket, so it stands
  in *Machines* and takes work with no ssh.
- The terminal steps of [F152](README.md#f152) and [F157](README.md#f157) run a stand-in command
  that asks as the real one would; built with those issues, not before.
- A walk file for the host flow is in `doc/walks/`, held to the interface's keys by the existing
  test.
- Seen to fail first: today the dialog runs `/usr/lib/porelo-frontend/porelo-host` whatever is set,
  so the test naming a stand-in goes red.
