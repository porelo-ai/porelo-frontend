# F358 — A Host's Check Before Its Installation

**Status:** Backlog.
**Size:** L - one check in the dialog with its list and choices, on the collection's answer, and an offer compared before renting.

**What must be true.** A person who rented a machine anywhere and left their ssh key there learns at once, before anything is installed, whether it can do what they want: the host dialog's first step after the address runs one check, shows everything it found, offers the installation only when it passes, and lets a choice be changed there with the check run again.

**Decided:** before renting, what an offer publishes is compared with the check's limits, CPUs, memory, disk and virtualization, and the script checks the rest after.

## The shape

**The flow in the dialog:**

1. The address and the key.
2. The check runs, given the person's choices. It only reads, and changes nothing on the machine.
3. The list: every finding at once, each with its measured value, what was asked, and what to do. What passes reads as passed, not as absent.
4. A choice can be changed right there: VMs in its jobs, a forge of its own, concurrent jobs. The check runs again and the list follows.
5. *Install* is offered only when the list passes. A failure of the check itself reads as that, never as a passed machine, and offers no installation.

**The check is the collection's, not the window's.** It is one script with no change to the machine, sent by ssh on standard input, the choices as JSON; a playbook cannot do it, since installing Ansible is already a change. The window shows its answer, with no limit of its own, so the window and the installation cannot differ. The installation runs the same script first. A finding the window does not know yet is shown by its words and is not read as passed.

**The answer:** one JSON object, with a version, `ok`, and `complete` for whether the check ran to its end; each finding has a stable `id`, `pass`, `fail`, `warn` or `unknown`, the value and unit found, what was asked and what to do. Exit 0 passes, 1 has findings, anything else means the check itself could not run.

**This window's own part, before the script can answer:** the login, `sudo -n` and a missing `python3` are reported from the first ssh line, and the run of `porelo-host` checks before its first `apt-get`, on the command line too, or that run changes the machine first.

**What cannot be known beforehand is said as that,** by `unknown`: that KVM really works, an account's controllers, the store's bucket, that packages install, reach from outside, behaviour under load. The window does not turn it into a pass.

**Disk:** until it is measured it is shown with its value and refuses nothing, as the installation holds no limit today.

## Acceptance

- A stand-in machine with several faults at once shows all of them in one list, each with value, asked and what to do; *Install* is not offered. Seen to fail first.
- Changing a choice runs the check again: a CPU without virtualization is a finding with VMs on and none with VMs off.
- No answer, a broken answer and a refused login each read as the check not having answered, with no *Install*.
- A machine that passes changes in nothing by being checked.

## To be checked

- The answer's fields as the collection finally has them. A pin moves with this dialog.
- A machine reached as a person other than root, and what the login's finding says.
- What the step says for a host being prepared again, where the check's limits meet what is already there.
