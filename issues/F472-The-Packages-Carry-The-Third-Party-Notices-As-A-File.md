# F472 — The Packages Carry The Third-Party Notices As A File

```json
{
  "$schema": "issue-1.json",
  "id": "F472",
  "title": "The Packages Carry The Third-Party Notices As A File",
  "state": "Analyzed",
  "size": "S",
  "priority": "Medium",
  "rank": 12,
  "blockedBy": [],
  "covers": "The .deb and .rpm carry the licenses of all third-party code built into the window as one plain THIRD-PARTY-NOTICES file, unpacked from Flutter's own notices."
}
```

**Why this size.** one build step that unpacks a file Flutter already writes, two entries in the package description,
and a test of the unpacked file.

**How it stands.** The operator decided on 2026-11-10 that every repository that ships a .deb or .rpm with
third-party code built in ships its notices as one THIRD-PARTY-NOTICES file, with the full license texts, and gave
this issue the priority Medium. The Java repositories take a generator from porelo-buildtools; the window needs none,
since Flutter already collects its notices. Like every adoption, it is built once that generator is on main.

**What must be true.** Someone who installs the window's .deb or .rpm finds the licenses of all third-party code built
into it as a plain text file, in the place their system looks: `/usr/share/doc/porelo-frontend/THIRD-PARTY-NOTICES`,
named in the deb's `copyright`, and `/usr/share/licenses/porelo-frontend/THIRD-PARTY-NOTICES` as the rpm's license
file. They need not start the window to read them. Fedora has no shared license directory, so the rpm must carry the
full texts itself.

## Plan

Read in today's build and packaging:
- `flutter build linux --release` writes `data/flutter_assets/NOTICES.Z`, a zlib-compressed text. It holds the full
  license of every Dart package resolved into the window: `packages/xterm`, the planning screen from porelo-planner,
  and the Flutter engine with the libraries it embeds. The window's About dialog already shows it through *View
  licenses*.
- `tool/package.sh` and `packaging/nfpm.yaml.in` install the bundle as a tree under `/usr/lib/porelo-frontend`, plus
  the window's own `LICENSE` as the deb's `copyright` and the rpm's license.
- The step: after the release build, `tool/package.sh` inflates `NOTICES.Z` into `build/THIRD-PARTY-NOTICES`. nfpm
  installs it twice, to `/usr/share/doc/porelo-frontend/THIRD-PARTY-NOTICES` for the deb, with the `copyright` file
  naming it, and as a `type: license` entry under `/usr/share/licenses/porelo-frontend/` for the rpm.
- The MSIX keeps the notices inside its bundle, as it does today.
- Red first: a test of the packaging step that the unpacked file is plain text, names `xterm` and the Flutter engine,
  and holds the same text as `NOTICES.Z`; and that the nfpm description lists both destinations.

## Acceptance

- The built .deb and .rpm each hold THIRD-PARTY-NOTICES at their system's place, as plain text with the full license
  texts, the same as the window's *View licenses*.
- The deb's `copyright` names the file.
