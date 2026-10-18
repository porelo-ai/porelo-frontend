# F129 — The Integration Leg Set Up On Fedora Too

**Status:** Backlog.
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

- **Where the steps unpack a package**
  (`the_test_machine_has_a_task_with_a_message_held_for_saying.dart`, `support/matrix.dart`,
  `the_test_machine_has_porelos_stub_agent.dart`): on a machine with `rpm2cpio`, the package comes
  from `porelo-dist-rpm`'s snapshots, checked against the digest its index publishes, and is
  unpacked with `rpm2cpio | cpio -idm`; otherwise as today.
- **The paths inside** are the same in both formats, so what is installed into the account does not
  change.

## Acceptance

- **The leg against `fedora`** passes whole, 23 of 23.
- **The leg against `ubuntu26.04`** still passes whole.
