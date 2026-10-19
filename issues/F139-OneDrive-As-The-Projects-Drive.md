# F139 — OneDrive As The Project's Drive

**Status:** Idea.

**What must be true.** A person chooses per project whether the host's drive is Tresorit or
OneDrive, and `porelo-host up` and the interface ask at the stop for what that drive's login needs.
The `drive` role in [porelo-host](https://github.com/porelo-ai/porelo-host) installs and runs the
client; this issue is the choice and the login. Many companies use OneDrive and no Tresorit.

## To be checked

- **The choice:** an option of `up` and `down` beside `--tresor`, such as `--onedrive <library>`,
  and how the interface offers the two for a project.
- **The login at the stop:** Microsoft's OAuth device flow fits it, since no password is typed for
  the host: `up` stops with 75 and the code and address to open, and a second `up` waits until the
  person has signed in. What the stop's `needs` and the interface's question then are; whether a
  work account needs its tenant's admin to consent to the client's app first, and how that is said.
- **The token:** where the refresh token lies on the host, and that `down` revokes or removes it.
- **Encryption:** Tresorit encrypts end to end, OneDrive does not, so the host's WireGuard key and
  anything secret on the drive would be readable at Microsoft and by the company's admins. Whether
  the person must be told so at the choice, or such files get their own encryption.
- **Personal or business** (OneDrive for Business, SharePoint libraries): which comes first.
- **`down` under the operator's (b):** the client's own "fully synced", for the kept-host line.
- **Which client, and so which login:** the client is HO16's choice in porelo-host, and the login
  this issue asks for follows it. `rclone` and `onedrive` (abraunegg) both come from Ubuntu's and
  Fedora's archives, signed there, and both sign in by a device code or a URL handed back.
  GNOME Online Accounts' Microsoft 365 account asks for its login in a desktop session, which a
  host has not, so likely no login this command could carry; to be said why once read.
