# F136 — Publish Without A Downloaded Client

**Status:** Backlog.
**Size:** S - three upload steps and the probe moved from the JFrog CLI to `curl` in the steps themselves.

**What must be true.** No job that holds the Artifactory token downloads a client to use it. The
packages and the Windows assets reach Artifactory by `curl` against its REST interface, and each
upload carries its SHA-1 and SHA-256, so Artifactory refuses bytes that do not match.

## Plan

- `jfrog/setup-jfrog-cli` goes from `build.yml`'s `Publish` and from `artifactory-probe.yml`.
- **No helper file:** the `curl` calls are written into each step, as porelo-message-sluice's
  Publish does them, until porelo-buildtools [BT23](https://github.com/porelo-ai/porelo-buildtools/blob/main/issues/README.md#bt23) publishes one helper for every repository;
  a copy of another repository's `artifactory.sh` would be one more to retire.
- **The token** goes from the step's `env` into a curl config file of mode 600 under `RUNNER_TEMP`,
  removed after, so it is on no command line.
- **Each upload** is `curl -T` with `X-Checksum-Sha1` and `X-Checksum-Sha256`, so Artifactory refuses
  bytes that do not match:
  - the deb with its Debian properties on its path (distribution, component, architecture);
  - the rpm into its channel;
  - the Windows ZIP and MSIX;
  - `porelo-host` and `porelo-host.exe` alone, each with a `SHA256SUMS` beside it, as
    [F134](README.md#f134) planned and left for this move.
- **The probe's** upload, property read and delete become `curl` against the REST interface.
- The refusal of a version that is there already and the wait until it is indexed stay as they are.
- **Red first:** the steps run on the host against a stand-in for `curl` that records what it is
  given: the addresses, properties and both checksums, the config at mode 600, the token on no
  command line; each refusal (no token, a version already there, an index that cannot be read) made
  to happen once.

## Acceptance

- The probe started by hand and the next `Publish` on `main` are green, with every package found in
  the index afterwards.
- No `jfrog/` and no `jf ` is left under `.github/`.
