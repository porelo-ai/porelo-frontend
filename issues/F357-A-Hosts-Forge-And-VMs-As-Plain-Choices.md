# F357 — A Host's Forge And VMs As Plain Choices

```json
{
  "$schema": "issue-1.json",
  "id": "F357",
  "title": "A Host's Forge And VMs As Plain Choices",
  "state": "Review",
  "size": "M",
  "priority": "Medium",
  "rank": 42,
  "blockedBy": [],
  "covers": "The put-on-a-host dialog asks in plain words about a forge of its own and VMs in its jobs, with what each costs, and says what the machine can carry."
}
```

**Why this size.** the host dialog's two plain choices and what each means, and the inventory's `porelo_host_kvm`.

**What must be true.** Putting a project on a host, a person chooses in plain words whether the host runs a forge of its own and whether it runs VMs in its jobs, reads what each choice costs, and sees what the machine can carry when setting its concurrent jobs. A CPU without virtualization stops only a host that asked for VMs, and says what to do.

**Decided:** the choice for VMs says that admitted people get access amounting to root on the machine, once that fact is confirmed from the collection's side.

## The shape

**The three things in the put-on-a-host dialog:**

- **This host has a forge of its own.** On by default, as today, when it has no switch: the window always sends on. Words on what each choice costs: off means a central forge alone, with less to run on the machine; on means builds run here and take memory and CPUs from the tasks.
- **This host runs VMs in its jobs.** Off by default. Words: on installs KVM and libvirt, needs a CPU with virtualization, and is for a job that makes a VM; a job in a container needs none of it. It only has a meaning with a forge of its own, or with a pool of VMs.
- **Concurrent forge jobs.** Today this field says only "Leave empty for the machine role default". It says what this machine can carry, where the machine is known, and what an empty field gives.

**What it writes.** The inventory's `porelo_host_kvm`, a boolean beside `porelo_host_forge`, default false. An older collection ignores it, so the pin to the collection that reads it moves together with this dialog, not before.

**The words a refused CPU shows, with VMs on:** "This machine's CPU offers no virtualization, so it cannot run VMs in its jobs. Nothing was installed. Choose a machine with hardware virtualization, or turn off *This host runs VMs in its jobs*."

**The numbers come from the host's page of servers:** each cost and each machine's carrying is said as measured there, or left out. Until then the dialog says no number.

## Acceptance

- With VMs off, the inventory says `porelo_host_kvm: false` and a CPU without virtualization goes through; with VMs on, it says true, and that CPU is refused with the words above, seen to fail first.
- With the forge off, the inventory says so, and the jobs' fields and the VMs' choice do not stand there as if they meant something.
- A dialog reopened on a host shows what that host was set to, and an existing host is not silently changed.

## Decided while building

- **The two choices are kept with the host's other preparation settings,** and only where they differ from the default, so an older host's record reads as it did. Once a host is prepared the dialog does not offer them, so an existing host is not changed.
- **With the forge off, VMs are off,** and the switch and the forge's own fields do not stand there. A pool of VMs, the other use of VMs, is not offered yet.
- **Concurrent forge jobs says what an empty field gives,** that the machine's role works it out from what the machine has. No number, and no carrying of a machine, as the host's page of servers has not measured them.

## To be checked

- **A host that had a forge, set up again without one:** the organization's card keeps its forge ports, as `changeHost` has no way to clear them, and connections would still forward them. The dialog offers no such change on a prepared host, so only a preparation run anew reaches it; it needs a contract with the daemon.
- **Whether the pinned collection refuses such a CPU:** the tests use a stand-in for the check, and only a run on a machine without virtualization shows the collection's part.

- Which collection reads `porelo_host_kvm`, and how a pool of VMs combines with VMs off: the collection stops at that with both named, and the window also offers no pool yet.
- Whether what a machine can carry can be read before it is put on, for a machine that is only given by its address.
- An existing host: what turning either choice off does, as nothing is removed by it.
