# F138 — A Host On Fedora From The Same Command

**Status:** Idea.

**What must be true.** `porelo-host up` and `down` bring a Fedora host up and take it off again as
they do Ubuntu 26.04, with the same steps, the same stop and the same lines, so that porelo-host's
Fedora plays (its issue "The Host On Fedora") have a command that installs their tools.

## To be checked

- `ansible-core` installed with `dnf install -y ansible-core` on Fedora, chosen by the host's own
  `/etc/os-release`, and `cloud-init status --wait` before it as on Ubuntu.
- The image's own sudo user on a Fedora cloud image, which is `fedora`, not `ubuntu`.
- Whether Scaleway Elastic Metal lists Fedora for the offer, read in its `/os` list; a rented
  Fedora host exists only where it does.
- A machine run on a Fedora cloud image, as `tool/vm-run.sh` runs Ubuntu's.
