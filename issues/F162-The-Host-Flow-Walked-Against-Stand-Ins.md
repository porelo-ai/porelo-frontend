# F162 — The Host Flow Walked Against Stand-Ins

**Status:** Accepted.

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

## To be checked

- How the reported host's entry points at the mock daemon without a kind of machine that exists
  only for the walk.
