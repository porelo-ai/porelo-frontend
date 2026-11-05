# F358 — A Host's Check Before Its Installation

**Status:** Implementing.
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

## Decided while building

- **The step stands only where the carried collection holds a check**, as `porelo-host check --available` says: a collection without one, an older command or none at all gives the dialog as it was.
- **Prepare is called *Prepare the machine*, as the dialog already says,** and *Check this machine* stands in its place until the answer passes. Passing is `ok` and `complete` with exit 0 and at least one finding.
- **An answer at odds with itself is no answer**: exit 0 without `ok` and `complete`, exit 1 with both, `ok` beside a failing finding, a failure said with no failing finding in a complete list, a pass of nothing, another version, a state out of the contract. A missing `found`, `unit`, `asked` or `do` is allowed, and such a field of the wrong type is not.
- **`unknown` does not hold Prepare back and never reads as passed**: it reads *Cannot be known beforehand*, as most of what it covers can only ever be that.
- **Exit 64 stays for a wrong command line**, as for every verb, and prints no JSON; the window reads it as no answer. A bad address, key or setting is exit 2 with the object saying so.
- **The check logs in as root**, as the installation does, so the bootstrap line stands before it, and a refused login says to run that line.
- **The pin of a check is a private file of its own, deleted after the run**, because writing a pin replaces a whole file and a check has no machine name to keep one under. Nothing stays behind on this computer.
- **The script's lines are not taken out of its answer**: a secret input's lines are cut from what comes back, which would cut a lone `}` from the JSON, so public input has its own way in.
- **`forge` is always sent**, the same word `up` turns an absent choice into; the window has no forge choice yet, so it says true.
- **`ports` is not sent**: the ports the form holds are this computer's forwards, which the machine is never told. Which ports the check's own choice means is not read yet.
- **The VMs choice stands in the dialog beside the form, off by default, and goes to the check alone.** It says so in its words. It is kept nowhere and writes nothing into the inventory; the inventory's own setting comes with its own work. The words on root access are left out until the collection confirms them.
- **An ssh of the check is ended after three minutes, and an answer over a mebibyte is not read.**
- **Findings stand in the order fail, warn, unknown, pass**, each in the check's own order, so what stands in the way is seen first.

**Still to do:** the offer compared with the check's limits before renting; a pin to a collection holding the check, until which the step does not show; the answer's fields, `kvm`, `jobs`, `job_cpus` and `job_memory` read against the real script and a real machine, and the words a machine reached as another person than root gets.

- **`up` asks the check itself** before this run's first change, wherever the carried collection holds one, so the command line and a run started again are stopped too. Its refusal names every fault.
- **The comparison of an offer before renting waits for a place.** The window prepares a machine a person gives, and rents none, so it has no list of offers to compare; `limits.json` stands ready for it.
- **`ports` is not sent yet.** The window's ports are this computer's forwards; what the machine itself must find free is for the collection to say, as the check's `ports` then reads it.

## To be checked

- The answer's fields as the collection finally has them. A pin moves with this dialog.
- A machine reached as a person other than root, and what the login's finding says.
- What the step says for a host being prepared again, where the check's limits meet what is already there.
