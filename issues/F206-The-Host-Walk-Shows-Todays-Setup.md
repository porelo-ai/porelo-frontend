# F206 — The Host Walk Shows Today's Setup

**Status:** Idea.

**What must be true.** The guided walk of putting a project on a server (`doc/walks/17-the-host-flow.json`, the
walk's part of `doc/guided-walk.md`, and the stand-ins `tool/host_standin.dart` and `tool/ssh_standin.dart`) walks
through the setup as it is: the step *Your secrets file* and its terminal, a host that mounts no drive, and a stop fed
from the secrets file on standard input, after one master password; no Tresorit e-mail, password or one-time code at
the stop.

## Why

Found by the harm reading of [F201](README.md#f201)'s first part (2026-10-28): the walk was written before
[F198](README.md#f198), [F199](README.md#f199) and [F201](README.md#f201), shows no secrets file, and its stand-ins
still stop for the drive's login, which a host set up with `porelo-host`
never asks.

## Plan

- **Read in today's code:** what the stand-ins print for `up`, and which terminal commands the ssh stand-in accepts;
  the secrets file's terminal needs a `keepassxc-cli` the walk may stand in for.
- **Red first:** the walk's own check that every key it names is in the interface, against the steps as they are.
