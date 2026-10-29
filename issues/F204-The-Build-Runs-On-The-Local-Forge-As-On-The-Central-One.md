# F204 — The Build Runs On The Local Forge As On The Central One

**Status:** Idea.

**What must be true.** porelo-frontend's `build.yml` runs green on the host's Forgejo and on the central forge on the
same commit, with no edit between them: the rented machine of its integration leg asked for by kind, never by a
provider (today `-Pe2e,hetzner` and the `HETZNER_*` secrets), the registry it publishes to taken as a variable, and
the Windows job switched by a variable present on both forges, as `porelo-host`'s
`doc/local-forge.md`, *The local registry and publication settings*, describes.
