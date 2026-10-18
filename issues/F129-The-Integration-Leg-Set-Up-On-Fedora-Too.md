# F129 — The Integration Leg Set Up On Fedora Too

**Status:** Implementing; the leg green 23 of 23 on `fedora` and on `ubuntu26.04` on the commit that
builds it, Review once it is pushed and published.
**Size:** S - three set-up steps that unpack a package taking the `.rpm` where the machine has
`rpm`, and one run of the leg against the `fedora` VM.

**What must be true.** The integration leg runs whole against a Fedora machine: every scenario
whose set-up fetches a Porelo package gets it in the machine's own format, so none fails before it
tests the interface.

## Why

Run against `fedora` on 2026-10-18, 21 of 23 scenarios passed through the interface's forward on an
enforcing SELinux. The two that failed, "a message held for a person ... refused for good" and "a
person joins a project's conversation ... through the forward", stopped in their set-up with
`dpkg-deb: command not found`: their steps fetch `porelo-message-sluice-filter` and the Matrix
transport from `porelo-dist-deb` and unpack them with `dpkg-deb`, which Fedora has not. The stub
agent's step unpacks the same way. The Build's leased leg is `--os ubuntu`, so the Build does not
see it.

## Plan

- **One shell function, `unpackPorelo` in `support/remote.dart`,** used by the three steps that
  unpack a package (`the_test_machine_has_a_task_with_a_message_held_for_saying.dart`,
  `support/matrix.dart`, `the_test_machine_has_porelos_stub_agent.dart`): on a machine with
  `dpkg-deb`, the newest `.deb` from `porelo-dist-deb`'s index, checked against the digest it
  publishes; otherwise the `.rpm` through the machine's own Porelo source with
  `dnf download --refresh`, checked against that source's metadata, unpacked with
  `rpm2cpio | cpio -idm`.
- **The paths inside** are the same in both formats, so what is installed into the account does not
  change.

## Acceptance

- **The leg against `fedora`** passes whole, 23 of 23.
- **The leg against `ubuntu26.04`** still passes whole.
