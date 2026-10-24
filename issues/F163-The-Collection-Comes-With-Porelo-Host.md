# F163 — The Collection Comes With Porelo-Host

**Status:** Implementing; blocked by `porelo-host` [HO13](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho13), which attaches the
tarball and its `SHA256SUMS` to each release, and by its first release.
**Size:** M - the release's tarball carried in the interface's packages, `porelo-host up` taking it by default, and the dialog's step only in a development build.

**What must be true.** The person never chooses the porelo-host collection. `porelo-host` brings the
collection it was built against, or fetches it from that porelo-host release, and checks its digest
as [F137](README.md#f137) says; the host dialog has no field for it. A chooser exists only in a
development build, to try a collection built from a clean clone.

## Why

The host dialog asks for the collection's tarball as a path, which a person cannot know and which
lets any tarball reach the host's installer. With the collection fixed by the release and its digest
pinned, the field is not needed.

## Plan

- **Today**, read in the code:
  - the host wizard's step *The setup file* asks for the tarball (`host-collection`,
    `lib/src/ui/host_dialog.dart`), passed as `--collection` to `porelo-host`;
  - `porelo-host` is built from `packages/porelo_host` and installed beside the interface as
    `/usr/lib/porelo-frontend/porelo-host` (`lib/src/app/host_session.dart`), the very binary the
    packages carry (`.github/workflows/build.yml`);
  - [F137](README.md#f137) pins the tarball's SHA-256 in `packages/porelo_host` and checks it
    before the copy and on the host.
- **What porelo-host's release gives** (Agent Machines, 2026-10-24):
  - the tag `v<version>`, with `porelo-host-<version>.tar.gz` and `SHA256SUMS` attached;
  - each built once and never replaced, so a digest pinned per version stays true;
  - the OpenTofu module of [F166](README.md#f166) to come as a second tarball under the same
    `SHA256SUMS`.
- **Carried, not fetched** (assumed, below): the interface's build downloads the pinned
  version's tarball and `SHA256SUMS` from that release, checks the digest against [F137](README.md#f137)'s constant
  and fails the build on a mismatch. It puts the tarball beside `porelo-host` in the packages
  (`/usr/lib/porelo-frontend/porelo-host-<version>.tar.gz`, beside `porelo-host.exe` on Windows).
  - This brings no network at use time, so nothing is fetched while a person waits.
  - The package's own signature then covers the tarball too.
  - The download step takes the file name as a parameter, so [F166](README.md#f166)'s module comes the same way.
- **`porelo-host up` without `--collection`** takes the tarball beside its own binary and refuses,
  with 65 and the expected path, when it is missing. `--collection FILE` with
  `--collection-sha256 HEX` stays, for a tarball built from a clean clone in a test run.
- **The dialog:** the step *The setup file* is shown only in a development build (`kDebugMode`),
  named *A test collection*, and its use said in the protocol as a test's. In a release build the
  wizard has one step fewer, and the summary names the collection's version.
- **Tests, their harm, red first:**
  - `up` without `--collection` uses the carried tarball, and a missing one is refused before
    anything is rented (a host rented that cannot be set up);
  - a release build's wizard has no collection step and starts `up` without one (today it cannot);
  - the build step is proven by running it green, and red on a changed digest, not by a test of
    the workflow's text.

## Assumed, to be confirmed

- **Carried in the packages**, as above. The alternative: fetched from the release on first use
  into this computer's cache, its digest checked each time, which keeps the packages smaller but
  brings the network into a person's first `up`; [F137](README.md#f137) pins the version either
  way. Asked of the operator as a deferred question on 2026-10-24.

## Acceptance

- In a release build the host dialog shows no collection field, and `up` installs the collection of
  the release the interface was built against, its digest checked.
- In a development build a chooser offers another tarball, named as a test's in the protocol.
- Seen to fail first: today's dialog cannot start `up` with the collection field empty; the test
  starting it without one goes red.
