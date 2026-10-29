# F215 — The Developers Of A Project Kept In Its Access File

**Status:** Backlog; blocked by [F213](README.md#f213).
**Size:** L - a settings section editing a signed file, the forge's API for read access, and the states read from host and forge.

**What must be true.** A project admin keeps the project's developers in its settings: each with an account name on the host, their login at the central forge, and one or more laptops with their public keys and VPN address; the change is signed with the admin's own git, the developer gets read access to the access repository, and each developer shows what the host and the forge say of them.

## Why

Decided: the developers are listed with their public keys in the project's signed access file; bringing the project admits every listed developer, and a change to the list adds or removes them on the host automatically.

## Plan

- ***Developers***, a section of the project's settings (`project-admin`), on the access checkout ([F213](README.md#f213)):
  - **Add:** the account name within `porelo-host`'s pattern, `forge_login`, then laptops: each from a pasted key block (*Copy my public keys*, [F216](README.md#f216)), checked as an ssh and a WireGuard public key, the ssh comment stripped, with the next free `vpn_address` of the host's network proposed.
  - **Remove** a developer or one laptop.
  - Written with `yaml_edit` (declared in `pubspec.yaml`, not used yet), committed and signed with the person's own git, pushed.
- **Read access:** `GitHub` in `lib/src/app/forge.dart` gains the collaborator calls: `PUT /repos/{owner}/{repo}/collaborators/{login}` with `permission: pull`, `DELETE` on removal, and reading the pending invitations. A token without the right is refused with the right named; a forge with no such API gets a link saying what to grant.
- **The states:** *listed*, *admitted*, *locked* or *refused with the helper's reason*, read from the host; *invited* or *can read*, read from the forge.
- **Red first:** a test that adding a developer writes exactly one entry into a fixture `access.yml`, comments kept, and calls the collaborator API once.

## Acceptance

- A developer added here is admitted on the host after the signed commit lands, and can clone the access repository once they accept GitHub's invitation.
- A developer removed is locked on the host and loses read access.
- No private key, no comment of a key, and no token appears in the file, a log or the screen.
- Seen to fail: the fixture test red before the section exists.
