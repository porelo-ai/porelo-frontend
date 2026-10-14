# F120 — The Interface Renamed Porelo

**Status:** Analyzed; blocked by `sokar` renamed and published, step 3 of
[PJ41](https://github.com/sokar-ai/sokar-project/blob/main/issues/README.md#pj41).
**Size:** M - one scripted commit over 708 files, plus a handful of names the replacement gets wrong, a
regenerated step tree, the whole suite, the packages and the integration leg against a renamed daemon.

**What must be true.** Nothing a person installs, starts, types or reads from the interface says Sokar,
except where it says what the old name was. The interface speaks the renamed daemon's contract, installs as
`porelo-frontend` and keeps its settings under the new name. It is installed afresh, and nothing of Sokar's
is read or kept.

## Why

[PJ41](https://github.com/sokar-ai/sokar-project/blob/main/issues/README.md#pj41) renames the product, its
repositories, the organisation at the forge, its packages and its contracts in one window. This
repository goes in step 4, beside the other repositories built on `sokar`, once the daemon is published
under the new name.

## What carries the name

Counted on `main`: 4,392 occurrences (`sokar` 3,374, `Sokar` 855, `SOKAR` 163, no other case) in 708 of
1,675 tracked files, and 28 paths: 22 under `test` and `integration_test`, 18 of them generated step files,
`lib/src/app/sokar_app.dart`, `lib/src/client/sokar_client.dart`, the two packaging files and
`images/sokar-frontend.gif`.

| Where | Occurrences | Files |
|---|---|---|
| `test` | 2,361 | 469 |
| `lib` | 649 | 109 |
| `integration_test` | 220 | 55 |
| `issues`, `doc`, the top level | 461 | 55 |
| `tool`, `.github`, `packaging`, `linux`, `windows` | 142 | 20 |

**Contracts something outside reads**, each renamed with its other side:

- **The daemon's wire:** `org.fuin.sokar.Tasks1`, `Tasks2` and their errors (112 occurrences in 37 files),
  the socket `$XDG_RUNTIME_DIR/sokar/…`, the commands run on a machine (`sokar`, `sokard`,
  `sokar task attach`, `sokar vault unlock`, `sokar doctor`; 213 `sokard`), the gate's refs
  `refs/sokar/…` (19) and forwarded branches `sokar/…`, and the title prefix
  `sokar ` by which a forge key made by a machine is recognised.
- **The Dart package `sokar_frontend`** (494 imports in 339 files) becomes `porelo_frontend`, and with it
  the binary and window class `sokar_frontend` on Linux and Windows.
- **On the desktop:** `linux/CMakeLists.txt`'s `APPLICATION_ID` `org.fuin.sokar_frontend`, the window
  title, the method channel `sokar/window`, `packaging/sokar-frontend.desktop` (`Name=Sokar`,
  `StartupWMClass`), `/usr/bin/sokar-frontend` and `/usr/lib/sokar-frontend`, the Windows `Runner.rc`,
  and the instance socket `sokar-frontend.sock`.
- **Shared with the IntelliJ plugin:** the settings `$XDG_CONFIG_HOME/sokar/frontend.json` and
  `%APPDATA%\sokar\frontend.json`, which the plugin reads. Both rename in the same window.
- **The package and its home:** the deb and rpm `sokar-frontend`, its dependency `sokar`,
  `sokar-dist-deb`/`-rpm` in the workflows, the Maven artifact `org.fuin.sokar:sokar-frontend` on
  `sokar-parent`, `org.fuin.sokar.release.Main` and `org.fuin.sokar.machines.Main`.
- **Other repositories' packages**, named by the new-machine wizard, its tests and the integration leg
  (37 occurrences): `sokar-message-transport-matrix` and `-local`, the virtual package `sokar-transport`,
  `sokar-message-sluice-filter`. They are renamed in the same window with sluice and matrix.
- **Variables:** 163 occurrences of names `SOKAR_*` in 35 files (`SOKAR_SOCKET` 41 times, `SOKAR_E2E_*`,
  `SOKAR_WALK`, the test tokens, the leg's `SOKAR_CANDIDATE` and `SOKAR_CI_LEG`).

## Plan

- **The script** (`tool/rename.sh`, kept out of the commit): `git mv` for the 28 paths, then `sokar`,
  `Sokar` and `SOKAR` replaced by `porelo`, `Porelo` and `PORELO` in every tracked text file, then the
  exceptions put back, then `dart run build_runner build`. The regenerated steps must equal what the script
  made, apart from import order.
- **The exceptions**, put back after the replacement:
  - `CHANGELOG.md`'s released sections (`0.4.1`, `0.4.0`); `0.5.0` is the first entry under the new name
    and says the product was renamed.
  - The Shared Area in `AGENTS.md`, which is taken from `sokar-project` in the window, not scripted.
  - The decision in `doc/decisions.md` that records the rename.
  - Any remaining mention of `org.fuin.sokar` at Maven Central as the old coordinates, if one is kept.
- **What replacement gets wrong, fixed by hand in the same commit:**
  - **The Debian pool path** `pool/main/s/sokar-frontend` becomes `pool/main/p/porelo-frontend`; the
    letter is the name's first.
  - **The MSIX identity** `ai.porelo.sokar.frontend` would become `ai.porelo.porelo.frontend`; it becomes
    `ai.porelo.frontend`, a new app, which no migration needs.
  - **The demo `images/sokar-frontend.gif`** is recorded again if it shows the name; the icons draw only the
    gate, not the word.
- **Red first:** a test tagged `documents` that fails while any tracked file outside the exceptions says
  `sokar` in any case, seen red on `main` before the script and green after, and kept.

## What must be published first

`porelo-parent` 0.2.0, `porelo-release` and `porelo-machines` 0.5.0 (the checks and the integration leg),
and `porelo` as a snapshot with its packages in `porelo-dist-deb`, which the leg installs. The repository is
renamed `porelo-ai/porelo-frontend` at the forge before the commit is pushed, so its links and
`gh attestation verify --repo` resolve.

## Acceptance

- **The test against the old name** is seen to fail before the script and passes after.
- **`dart analyze` is clean, the whole suite is green and `build_runner` leaves no diff**, on the commit.
- **The packages install as `porelo-frontend`**: the packaging tests and the Build's install checks on
  Ubuntu, Debian and Fedora; the Windows job builds the ZIP and the MSIX.
- **The integration leg is green against `porelod`** on the VM, installed afresh from Porelo's packages.

## To be checked

- Whether the tunnel socket `$runtime/porelo-tunnel-<name>.sock`, one character longer, still fits 108
  characters for the longest machine name the interface allows, and which test asserts it.
- Whether `images/sokar-frontend.gif` shows the word Sokar in a frame.
