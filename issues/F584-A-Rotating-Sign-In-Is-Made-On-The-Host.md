# F584 — A Rotating Sign-In Is Made On The Host

```json
{
  "$schema": "issue-1.json",
  "id": "F584",
  "title": "A Rotating Sign-In Is Made On The Host",
  "state": "Idea",
  "size": "M",
  "priority": "High",
  "rank": 16,
  "blockedBy": [],
  "covers": "Story ST364: in Import from this computer, a sign-in whose refresh token rotates is marked as one made on the host and offers Sign in on the host, which shows the login's link or code and its progress in the dialog and the agent's row afterwards; API keys are carried as today."
}
```

**Why this size.** One contract change read (which sources rotate, and a host login's link or code without a
terminal), the carry dialog and the sign-in model it drives, and their tests; the login itself, its forward and its
wait are there already (`SigningIn`, `raiseForward` in `lib/src/app/login_forward.dart`).

**What must be true.** A person never copies a provider login whose refresh token rotates to a host, where two
machines would spend one token and sign each other out: the host makes its own, the person confirms it in the
browser here, and an API key still goes across in one press.

## Plan

- **Today.** `CarryCredentialDialog` (`lib/src/ui/carry_credential_dialog.dart`) lists this computer's vault entries
  and the local agents' sign-ins (`sourcesFor`, `lib/src/app/credential_carry.dart`) and carries the one
  chosen by `CredentialReceiver`, `SealCredential` and `ReceiveCredential`. A machine's own login is `SigningIn`
  (`lib/src/app/agent_sign_in.dart`): `AgentSignInStart` runs it in a container there, the person attaches in a
  terminal on that machine, `AgentSignInWait` says whether the vault holds the credential then; a `LOOPBACK` login
  asked from another machine is refused `LOOPBACK_OVER_SSH`.
- **The wire, to be shaped with Agent Core** (proposed; nothing is built before it stands in porelo's stack):
  - each source says whether it rotates: `ImportableCredential.rotates: ?bool` and the same on a vault entry's
    listing, and `SealCredential` refuses a rotating one (`ROTATES`), so no window, old or new, carries it;
  - a host's login gives the window what the person needs without a terminal there: `AgentSignInStart` answers, or a
    watch (`AgentSignInWatch(agent)`) streams, `link: ?string`, `code: ?string` (a device code) and a `state`
    (`preparing`, `waiting-for-you`, `storing`, `ended`), never a token; a loopback login on a host is either
    refused or served by the window's forward of its redirect port, Core's choice.
- **Steps.**
  - Read `rotates` leniently (absent reads as today: carried); a rotating source shows *Made on the host*, with why
    in one sentence, and offers *Sign in on the host* instead of the carry; an API key or another non-rotating
    source keeps the carry and its *Replace it on the host*.
  - *Sign in on the host* drives a `SigningIn` on the host's backend with `remote: true`; the dialog shows the link
    (opened in the browser here on a press, copyable) or the code to confirm, and the login's state, until
    `AgentSignInWait` answers; a refusal (`ALREADY_SIGNED_IN` offers *Sign in again*, `VAULT_LOCKED` the unlock,
    others in words) is said where pressed.
  - Afterwards the host's providers and the agent's row are read again; the row says *Signed in on the host*.
  - Against a host whose Porelo knows neither field, the dialog stays as today and says that a provider login copied
    may sign this computer out.
- **Red first** (harm: a rotating login copied and both machines signed out; an API key no longer carried; a link or
  code shown that is not the host's, or a token shown): a model test that a rotating source offers no carry and an
  API key still does; a dialog test of the link, the code and each state; a test that a refused start is said and
  nothing is carried; each seen red.

## Acceptance

- The tests above, each seen red first; `test/ui` and `test/features` green.

## To be checked

- The wire with Agent Core: the `rotates` flag and where it stands, how the host's login hands over its link or code
  (answer or watch), and whether a loopback login on a host is refused or forwarded.
