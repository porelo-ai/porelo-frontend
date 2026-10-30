# F248 — A Bring Replaces Its Own Earlier Upload

**Status:** Accepted.
**Size:** S - a new try of a bring or join replaces the setup folder its own earlier try left on the host, and still refuses one it did not make.

**What must be true.** A bring or join that failed leaves the next try free to start: a new try replaces the setup folder `~/.local/share/porelo-host/setup/<project>/` that an earlier upload from this interface left, and uploads afresh. A folder this interface did not make, or one holding anything else, is still preserved and refused, with its path named.

## Why

Operator's walk 23 on VM A (2026-10-30): a failed bring left `~/.local/share/porelo-host/setup/walk6-demo/` on walk9server. The next try refused with "The project setup folder already exists; it was preserved." (`uploadSetupFiles` in `packages/porelo_host/lib/src/host_run.dart`). Removing the folder when a bring fails is not the answer: a bring that waits at a stop needs its files when it goes on.

## Plan

- The upload writes a marker into the folder it makes (`.porelo-upload`, holding the upload's time and the bundle digests), as the last file of a complete upload.
- A new try finds the folder, checks that it is a plain directory, that it holds the marker and only the files an upload writes, and that nothing in it is a link. It then removes it and uploads afresh, saying "An earlier upload of walk6-demo was replaced." Anything else is refused as today, naming the path and what made it foreign.
- A bring that goes on after a stop uses the folder as it is and does not re-upload.
- **Red first:** a test that an earlier marked upload is replaced and a new one made; a test that a folder without the marker, or with an extra file or a link, is refused and left untouched.

## Test

Only the change: the tests above against a stand-in remote, and `porelo_host`'s own upload tests. The VM test covers only a second bring try after a failed one on the walk's host.
