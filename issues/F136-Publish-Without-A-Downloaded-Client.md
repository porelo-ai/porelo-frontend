# F136 — Publish Without A Downloaded Client

**Status:** Analyzed; blocked by porelo [B49](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b49).
**Size:** S - three upload calls and a probe moved from the JFrog CLI to Porelo's proven curl script.

**What must be true.** No job that holds the Artifactory token downloads a client to use it. The
packages and the Windows assets reach Artifactory by `curl` against its REST interface, and each
upload carries its SHA-1 and SHA-256, so Artifactory refuses bytes that do not match.

## Plan

- `jfrog/setup-jfrog-cli` goes from `build.yml`'s `Publish` and from `artifactory-probe.yml`.
- Porelo's `.github/scripts/artifactory.sh` comes over as it stands, once it is proven there:
  porelo's smoke test on the real Artifactory and its next `Publish`, as the coordinator set.
- `Publish`'s three `jf rt upload` calls become `art_put`:
  - the deb with its Debian properties;
  - the rpm into its channel;
  - the Windows ZIP and MSIX.
- The probe's upload, property read and delete become `art_put` and `art_api`.
- The refusal of a version that is there already and the wait until it is indexed stay as they are.
- **The red test first:** against a stand-in HTTP server, as porelo's script was checked, with a
  wrong checksum refused.

## Acceptance

- The probe started by hand and the next `Publish` on `main` are green, with every package found in
  the index afterwards.
- No `jfrog/` and no `jf ` is left under `.github/`.
