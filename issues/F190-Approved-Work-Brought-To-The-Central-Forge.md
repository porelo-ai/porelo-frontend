# F190 — Approved Work Brought To The Central Forge

**Status:** Idea.

**What must be true.** From the interface, a person reviews and approves a task's work waiting on the host's Forgejo
instance and brings approved work on to the central forge, without a terminal on the host, with every promotion bound to
the exact reviewed commit SHA, target repository, and pull request number and showing the push's source level (`E0`,
`E1`, `I1`, `A`), risk class (`C0`–`C3`), and SARIF check completeness (`porelo`
[B291](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b291)).

## Why

Approving work on the host's Forgejo and promoting the gathered push to the central forge are the person's two
decisions on every piece of work. Carrying both through Porelo's SARIF 2.1.0 review model (`porelo-project`
[PJ72](https://github.com/porelo-ai/porelo-project/blob/main/issues/README.md#pj72)) and source-level and risk-class
rules (`porelo-project` [PJ73](https://github.com/porelo-ai/porelo-project/blob/main/issues/README.md#pj73)) lets the
person make both decisions in the interface with the same safety checks as at the local gate.

## The shape

- **Approve on the host's Forgejo:** the pull request `porelo/<task>` → `main` on the host's Forgejo is shown in the
  review with its SARIF 2.1.0 review runs, inline comments, PR review verdicts (`APPROVED`, `REQUEST_CHANGES`,
  `COMMENT`), and commit statuses mapped by `porelo-adapters`
  [GH10](https://github.com/porelo-ai/porelo-adapters/blob/main/issues/README.md#gh10), alongside its source level
  (`E0`, `E1`, `I1`, `A`) and risk class (`C0`–`C3`), and is merged from the interface.
- **Bring it on:** the gathered push (`porelo-buildtools`
  [BT06](https://github.com/porelo-ai/porelo-buildtools/blob/main/issues/README.md#bt06)) from the host's Forgejo to the
  central forge is started from the interface. The central forge's token is asked for hidden and kept nowhere.
- **Explicit bound promotion and completeness:** promoting work to the host's Forgejo or to the central forge is always
  an explicit action by the person bound to the reviewed commit SHA, target repository, and pull request or merge
  request number, and shows the profile's completeness as `porelo`
  [B291](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b291) defines it; anything but complete is never
  shown as clean.
- **Inbound public pull requests:** when an external pull request from the central forge is mirrored into the host's
  Forgejo for review (`porelo` [B145](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b145)), its source
  level (`E0` or `E1`) and risk class (`C0`–`C3`) govern container execution, secret withholding, and comment holding
  ([F191](README.md#f191)) identically.
- **Its result per repository:** pushed, or refused because the central forge or pull request head moved, naming the
  commits and that they come to the host's forge as the branch `central/main`. A project `offline` offers neither.

## To be checked

- Dependencies: `porelo-buildtools`
  [BT06](https://github.com/porelo-ai/porelo-buildtools/blob/main/issues/README.md#bt06), `porelo-adapters`
  [GH07](https://github.com/porelo-ai/porelo-adapters/blob/main/issues/README.md#gh07), `porelo-adapters`
  [GH10](https://github.com/porelo-ai/porelo-adapters/blob/main/issues/README.md#gh10), `porelo`
  [B136](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b136), `porelo`
  [B145](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b145), and `porelo`
  [B293](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b293).
- Code places in `porelo-frontend` for forge setup and client calls: `PoreloClient`
  (`lib/src/client/porelo_client.dart`), `FleetBackend` (`lib/src/app/fleet_backend.dart`), `Forge`
  (`lib/src/app/forge.dart`), `ForgeConnection` (`lib/src/app/forge_connection.dart`), and `ForgesPage`
  (`lib/src/ui/forges_page.dart`).
- Code places in `porelo-frontend` for gate review and promotion: `Gate` (`lib/src/app/gate.dart`), `BuildsSaid`
  (`lib/src/app/builds.dart`), and `ReviewView` and `_Decision` (`lib/src/ui/gate_view.dart`).
- Whether the gathered push is started through `porelo` over Varlink so that the interface needs no ssh to the host.
