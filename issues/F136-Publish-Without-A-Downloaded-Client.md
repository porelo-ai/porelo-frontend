# F136 — Publish Without A Downloaded Client

**Status:** Review.
**Size:** S - three upload steps and the probe moved from the JFrog CLI to `curl` in the steps themselves.

**What must be true.** No job that holds the Artifactory token downloads a client to use it. The
packages and the Windows assets reach Artifactory by `curl` against its REST interface, and each
upload carries its SHA-1 and SHA-256, so Artifactory refuses bytes that do not match.

## Plan

- `jfrog/setup-jfrog-cli` goes from `build.yml`'s `Publish` and from `artifactory-probe.yml`.
- **No helper file:** the `curl` calls are written into each step, as porelo-message-sluice's
  Publish does them, until porelo-buildtools [BT23](https://github.com/porelo-ai/porelo-buildtools/blob/main/issues/README.md#bt23) publishes one helper for every repository;
  a copy of another repository's `artifactory.sh` would be one more to retire.
- **The token** reaches curl on standard input, per call (`printf … | curl -K -`), from the
  step's own `env`: never a command line, never a file, as the shared rule on secrets in CI says.
- **Each upload** is `curl -T` with `X-Checksum-Sha1` and `X-Checksum-Sha256`, so Artifactory refuses
  bytes that do not match:
  - the deb with its Debian properties on its path (distribution, component, architecture);
  - the rpm into its channel;
  - the Windows ZIP and MSIX;
  - `porelo-host` and `porelo-host.exe` alone, left for this move when the packages began shipping
    them: into the generic repository `porelo-dist-host`, `<channel>/<version>/`, with one `SHA256SUMS`
    for what is there, the Windows one only where the Windows job made it. The build job and the
    Windows job hand the very binaries the packages carry to Publish as artifacts of their own.
- **The probe's** upload, property read and delete become `curl` against the REST interface.
- The refusal of a version that is there already and the wait until it is indexed stay as they are.
- **Red first:** the steps run on the host against a stand-in for `curl` that records what it is
  given: the addresses, properties and both checksums, the config on standard input, the token on
  no command line and in no file; each refusal (no token, a version already there) made to happen once. Seen red: the
  JFrog steps (`jf` not found), a checksum of another file, the token on a command line, the deb
  without its properties, and a config written to a file under `RUNNER_TEMP`.

## Acceptance

- The probe started by hand and the next `Publish` on `main` are green, with every package found in
  the index afterwards.
- No `jfrog/` and no `jf ` is left under `.github/`.
- `porelo-host` and `porelo-host.exe` can be fetched without a token from
  `porelo-dist-host/<channel>/<version>/`, and match the `SHA256SUMS` beside them.
