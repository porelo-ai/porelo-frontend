# F358 — A Host's Check Before Its Installation

**Status:** Idea. Nothing is built before the foo test.

**What must be true.** A person who rented a machine anywhere and left their ssh key there learns at once, before anything is installed, whether it can do what they want: the host dialog's first step after the address runs one check, shows everything it found, offers the installation only when it passes, and lets a choice be changed there with the check run again.

## The shape

**The flow in the dialog:**

1. The address and the key.
2. The check runs, given the person's choices. It only reads, and changes nothing on the machine.
3. The list: every finding at once, each with its measured value, what was asked, and what to do. What passes reads as passed, not as absent.
4. A choice can be changed right there: VMs in its jobs, a forge of its own, concurrent jobs. The check runs again and the list follows.
5. *Install* is offered only when the list passes. A failure of the check itself reads as that, never as a passed machine, and offers no installation.

**The check is the collection's, not the window's.** The window asks and shows its machine-readable answer, with no limit of its own, so the window and the installation cannot differ; the installation runs the same checks first. The window shows a finding it does not know yet by its words, and does not read it as passed.

**What cannot be known beforehand is said as that,** where the check names it: the window does not turn it into a pass.

## Acceptance

- A stand-in machine with several faults at once shows all of them in one list, each with value, asked and what to do; *Install* is not offered. Seen to fail first.
- Changing a choice runs the check again: a CPU without virtualization is a finding with VMs on and none with VMs off.
- No answer, a broken answer and a refused login each read as the check not having answered, with no *Install*.
- A machine that passes changes in nothing by being checked.

## To be checked

- The check's form, and its answer's fields, when the collection has them. A pin moves with this dialog.
- A machine this window rents itself: whether the check runs after the rental, as it must, and what the person is told before paying, as what was rented stays rented when the check finds something.
- A machine reached as a person other than root, and what the login's finding says.
- What the step says for a host being prepared again, where the check's limits meet what is already there.
