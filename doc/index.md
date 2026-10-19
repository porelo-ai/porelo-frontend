# Porelo interface

The desktop interface for Porelo, on Linux. Porelo runs AI coding agents in locked-down containers: no
network except what a project declares, no credential the agent can read, and nothing leaves the
machine without somebody approving it. This interface does what Porelo's command line does, on this
computer and on machines reached over ssh, without a terminal.

## Install

From the same package repository as Porelo itself, on the systems Porelo supports: Ubuntu 26.04,
Debian 13, Fedora 43 and Fedora 44.

Debian and Ubuntu:

```bash
curl -fsSL https://fuinorg.jfrog.io/artifactory/api/security/keypair/porelo-packages/public \
  | sudo tee /usr/share/keyrings/porelo.asc > /dev/null
echo "deb [signed-by=/usr/share/keyrings/porelo.asc] https://fuinorg.jfrog.io/artifactory/porelo-dist-deb releases main" \
  | sudo tee /etc/apt/sources.list.d/porelo.list
sudo apt update && sudo apt install porelo-frontend
```

Fedora:

```bash
sudo tee /etc/yum.repos.d/porelo.repo > /dev/null <<'REPO'
[porelo]
name=Porelo
baseurl=https://fuinorg.jfrog.io/artifactory/porelo-dist-rpm/releases
enabled=1
gpgcheck=0
REPO
sudo dnf install porelo-frontend
```

Artifactory signs the repository's index, not each package, so there is no package signature to
check. Porelo itself is recommended, not required: the interface is as useful for machines reached
over ssh.

### Windows

On Windows the interface reaches a Porelo in a WSL distribution of yours, through `wsl.exe`, with no
ssh and no open port. It comes two ways, from the same Artifactory as the packages, one folder per
version, `<version>/`: the [releases](https://fuinorg.jfrog.io/artifactory/porelo-dist-windows/releases/),
and each build of `main` among the
[snapshots](https://fuinorg.jfrog.io/artifactory/porelo-dist-windows/snapshots/). Each folder holds both,
with one `SHA256SUMS` over them and the build's attestation,
`porelo-frontend-<version>-windows-x64.sigstore.json`. Both read and write the same machine list,
`%APPDATA%\porelo\frontend.json`, so either can be used, and the other taken up later.

**Untested on a Windows machine.** Each build is checked on GitHub's Windows runner, where its tests
run and the ZIP and the MSIX are built; neither has yet been tried with a WSL distribution on a
person's Windows computer, and the MSIX has not been installed. Once such a test is done, this says
on which version.

#### Portable (ZIP)

`porelo-frontend-<version>-windows-x64.zip`, unpacked whole into a folder of its own and started there
as `porelo_frontend.exe`, with nothing installed and no administrator needed: for a computer you may
not install on. The ZIP is not signed. Check it before unpacking, twice:

```powershell
# The checksum, against the SHA256SUMS beside it:
(Get-FileHash .\porelo-frontend-<version>-windows-x64.zip -Algorithm SHA256).Hash.ToLower()
Get-Content .\SHA256SUMS

# That this repository's workflow built it, with the attestation from beside it:
gh attestation verify .\porelo-frontend-<version>-windows-x64.zip --repo porelo-ai/porelo-frontend `
  --bundle .\porelo-frontend-<version>-windows-x64.sigstore.json
```

A newer version is a new folder: unpack it beside the old one, or over it.

#### Installation (MSIX)

`porelo-frontend-<version>-windows-x64.msix`, installed as an app, in the Start menu as "Porelo
interface", and updated by installing a newer one over it. It is signed by `CN=porelo.ai` with a
certificate of the project's own, whose public half lies beside it as `porelo-msix.cer`. Windows
installs the MSIX only once that certificate is trusted on the machine: once, as an administrator.
Before trusting it, check that it is the project's: its thumbprint is
`8BD1F34465EDC9B11A162B39C6644231851DEE24`, valid until 2029-10-11, and the file's SHA-256 is
`6641c3c28749e532120ff7b76da057cab1987e984d13b1624504376bbb93498b`. Check the MSIX against
`SHA256SUMS` and the attestation as the ZIP above, then:

```powershell
# The certificate, before trusting it:
(Get-PfxCertificate .\porelo-msix.cer).Thumbprint
(Get-FileHash .\porelo-msix.cer -Algorithm SHA256).Hash.ToLower()

# Once per machine, as an administrator:
Import-Certificate -FilePath .\porelo-msix.cer -CertStoreLocation Cert:\LocalMachine\TrustedPeople

# Each version:
Add-AppxPackage .\porelo-frontend-<version>-windows-x64.msix
```

#### Either way

If typing or scrolling in a task's terminal does not work, `porelo_frontend.exe --diagnose-terminal`
shows every key and wheel event the terminal receives, the bytes it would send, and what of them
arrives in a WSL distribution, and writes it all to `porelo-terminal-diagnose.txt` in `%TEMP%`.

When a WSL distribution has no Porelo yet, the interface offers to set it up there, every line shown
before it runs, and checks the repository's key against the fingerprint it carries. That fingerprint
is only as trustworthy as the ZIP or the MSIX it came in, which is why the checks above come first.

## First steps

1. **Start it**: *Porelo* among the desktop's applications. It shows this computer's Porelo, if one is
   installed, and every machine added before.
2. **Add a machine** with *Watch another machine…* in the title bar: one whose socket is forwarded
   already, one reached over ssh, where the interface raises the forward itself, or **a new machine
   just rented**, which a wizard prepares end to end, showing every command before it runs it and
   using root only for setting up. The first time you go to it and it answers, the interface shows
   what it says about itself, as `porelo doctor` does on a terminal: each check green, yellow or red, with what to do.
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

## A project on a server

`porelo-host`, installed beside the interface (`/usr/lib/porelo-frontend/porelo-host`, or
`porelo-host.exe` in the Windows folder), puts a project on a rented server and takes it off
again. The playbook runs on the server itself, so this computer needs only ssh.

**Once, in Scaleway's console**, for the project the host is rented in:

1. Add your public ssh key: *Project dashboard* → *SSH keys* → *Add SSH key*, pasting the line
   from your `.pub` file. `porelo-host` never adds a key; when yours is missing it stops before
   renting anything and prints the line to paste.
2. Make an API key that may manage Elastic Metal and only read the project's ssh keys
   (`SSHKeysReadOnly`), and keep it in this computer's own secret store:

   ```sh
   porelo-host key set scaleway      # reads the key from standard input; nothing is echoed
   ```

**Then, for each project:**

```sh
porelo-host up --project <name> --account porelo --public-key ~/.ssh/id_ed25519.pub \
    --identity ~/.ssh/id_ed25519 --collection porelo-host-<version>.tar.gz --scaleway-project <project id>
```

It rents the host, or finds it again by its tag, and stops once with exit code 75 for what only you
can give: the drive's login and the vault's passphrase. The same `up` again with
`--answers-on-stdin` takes them as one JSON object on standard input, never as arguments, and goes
on. `porelo-host down` with the same options takes the last copies and gives the host back. Every
step is one JSON line on standard output.

## What the other pages hold

- [Design](design.md): what the interface is made of, and why.
- [Decisions](decisions.md): what holds, and what it costs.
- [Backend API](Backend-API.md): how a client talks to Porelo's daemon.
- [What the contract does not yet cover](Contract-Gaps.md): what the daemon has no method or field
  for yet.
- [The guided walk](guided-walk.md): how an agent leads a person through the interface.
