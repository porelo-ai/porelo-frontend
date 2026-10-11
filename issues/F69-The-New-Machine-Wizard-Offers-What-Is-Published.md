# F69 — The New-Machine Wizard Offers What Is Published

**Status:** Review; to be walked.

**What must be true.** The wizard offers what the package index has today, says what it installs in
today's words, and lets a step be left only once it is done.

## Why

In place: the preparing step lists the index's packages as the setup script does, each with its
kind and description; the homeserver is a choice of its own (`kind: homeserver`) and the filter
comes with the transport by its package's dependency; once the machine answers, the wizard says
whether it can carry messages from `sokar doctor`'s transports line and the homeserver unit; the
vault step asks for the vault as it opens.

## Acceptance

- **The words name what is installed**: Sokar, its filter, and the transports the index offers; no
  retired transport. Seen to fail: a widget test against an index stand-in, and the wizard walked on
  a fresh machine.
- **The local homeserver is a choice of its own beside Matrix**, for a machine that carries a
  project's messages alone: chosen, it is installed and enabled in the work user's account in one
  step, and a second work user on the same machine gets a port of its own. Seen to fail: a walk
  adding two work users with the homeserver on one machine.
- **A choice that would leave the machine unable to talk is said** before anything runs: no
  transport and no homeserver, or the transport without the homeserver (then only a project naming
  its own homeserver can talk); the homeserver alone is enough. Seen to fail: widget tests of each
  combination.
- **Whether the machine can carry messages is shown**, as `sokar doctor` reports it; with the
  transport and no homeserver it says one is needed. Seen to fail: tests with each `doctor` answer,
  and the walk.
- **The vault step cannot be left before the vault exists.** Seen to fail: a widget test where the
  machine says there is no vault and *Next step* stays disabled.

## To be checked

- **Messaging between the users of one machine** was to be offered as a step of its own, never
  ticked (`sokar-setup.sh --between-users on|off`), when messages went over a transport that stayed
  on the machine. Whether it still applies now that they go over Matrix is `sokar`'s answer.
