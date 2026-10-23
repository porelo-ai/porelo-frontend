# F154 — A Host Stands In Machines While It Is Prepared

**Status:** Idea.

**What must be true.** Starting *Put this project on a server* closes the setup dialog (or says
*Ready: \<name\> is in your machines* without offering *Put it on a server* again) and places the
host in *Machines* at once as *In preparation*, where it becomes a ready machine by itself when
`up` finishes. Its entry shows one plain-words line for the current step, an estimate of the time
left, the full protocol on a click, and *Needs you* with a link to the input when the person is
wanted.

## Why

In [F135](README.md#f135), the host dialog locks the window while `porelo-host up` runs, shows
internal phase names (`rent`, `ssh`, `ansible`), asks *Add this server to your machines* as a
separate step after a finished `up`, and stays open with *Put it on a server* still as its main
button.

## Acceptance

- Starting `up` adds the host to *Machines* as *In preparation* with a plain-words step, estimated
  time left, a click to open the protocol, and a *Needs you* link at a stop; when `up` exits 0, the
  host becomes a ready machine by itself and *Put it on a server* is no longer offered as the main
  action.
- Seen to fail: when `up` exits non-zero, the host entry is never marked ready and shows the
  refusal and protocol under *Machines*.

## To be checked

- Measured step times of `porelo-host up` on a rented host and a local VM for the time-left
  estimate.
