# Sokar interface

The desktop interface for Sokar, on Linux. Sokar runs AI coding agents in locked-down containers: no
network except what a project declares, no credential the agent can read, and nothing leaves the
machine without somebody approving it. This interface does what Sokar's command line does, on this
computer and on machines reached over ssh, without a terminal.

## Install

From the same package repository as Sokar itself, on the systems Sokar supports: Ubuntu 26.04,
Debian 13, Fedora 43 and Fedora 44.

Debian and Ubuntu:

```bash
curl -fsSL https://fuinorg.jfrog.io/artifactory/api/security/keypair/sokar-packages/public \
  | sudo tee /usr/share/keyrings/sokar.asc > /dev/null
echo "deb [signed-by=/usr/share/keyrings/sokar.asc] https://fuinorg.jfrog.io/artifactory/sokar-dist-deb releases main" \
  | sudo tee /etc/apt/sources.list.d/sokar.list
sudo apt update && sudo apt install sokar-frontend
```

Fedora:

```bash
sudo tee /etc/yum.repos.d/sokar.repo > /dev/null <<'REPO'
[sokar]
name=Sokar
baseurl=https://fuinorg.jfrog.io/artifactory/sokar-dist-rpm/releases
enabled=1
gpgcheck=0
REPO
sudo dnf install sokar-frontend
```

Artifactory signs the repository's index, not each package, so there is no package signature to
check. Sokar itself is recommended, not required: the interface is as useful for machines reached
over ssh.

### Windows

On Windows the interface reaches a Sokar in a WSL distribution of yours, through `wsl.exe`, with no
ssh and no open port. It comes as a ZIP, `sokar-frontend-<version>-windows-x64.zip`, unpacked and
started with nothing installed. It lies in the same Artifactory as the packages, one folder per
version, `<version>/`, with its checksum and its attestation beside it: the
[releases](https://fuinorg.jfrog.io/artifactory/sokar-dist-windows/releases/), and each build of
`main` among the [snapshots](https://fuinorg.jfrog.io/artifactory/sokar-dist-windows/snapshots/).
The ZIP is not signed. Check it before unpacking, twice:

```powershell
# The checksum, against the SHA256SUMS beside it:
(Get-FileHash .\sokar-frontend-<version>-windows-x64.zip -Algorithm SHA256).Hash.ToLower()
Get-Content .\SHA256SUMS

# That this repository's workflow built it, with the attestation from beside it:
gh attestation verify .\sokar-frontend-<version>-windows-x64.zip --repo sokar-ai/sokar-frontend `
  --bundle .\sokar-frontend-<version>-windows-x64.zip.sigstore.json
```

When a WSL distribution has no Sokar yet, the interface offers to set it up there, every line shown
before it runs, and checks the repository's key against the fingerprint it carries. That fingerprint
is only as trustworthy as the ZIP it came in, which is why both checks above come first.

## First steps

1. **Start it**: *Sokar* among the desktop's applications. It shows this computer's Sokar, if one is
   installed, and every machine added before.
2. **Add a machine** with *Watch another machine…* in the title bar: one whose socket is forwarded
   already, one reached over ssh, where the interface raises the forward itself, or **a new machine
   just rented**, which a wizard prepares end to end, showing every command before it runs it and
   using root only for setting up. The first time you go to it and it answers, the interface shows
   what it says about itself, as `sokar doctor` does on a terminal: each check green, yellow or red, with what to do.
   Nothing is repaired from here, and the machine is added either way.
3. **Add your forge** under *Forges*, with a token, so a repository can be picked rather than typed.
4. **Start work** with *New work* on *Work*: a machine and a repository. Without a project it runs
   with the machine's own settings. The first time, the agent asks you to sign in; the sign-in is
   kept in the machine's vault.
5. **Review what the agent did**: what it changed, the most far-reaching first, and what it was
   asked. Forward it to the repository's origin, or drop it.
6. **Follow a project** under *Projects* when work needs settings of its own: a repository holding a
   `project.yml`, whose settings are changed in that repository.

*Needs you* lists everything a person has to answer, on every machine, the most urgent first.

## What the other pages hold

- [Design](design.md): what the interface is made of, and why.
- [Decisions](decisions.md): what holds, and what it costs.
- [Backend API](Backend-API.md): how a client talks to Sokar's daemon.
- [What the contract does not yet cover](Contract-Gaps.md): what the daemon has no method or field
  for yet.
- [The guided walk](guided-walk.md): how an agent leads a person through the interface.
