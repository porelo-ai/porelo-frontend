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
- **The wire**, shaped by Agent Core in porelo `a668512e9` (B785-B787, Idea, not built; names may still move with
  Agent Smith's answer on how definitions declare the link and code); nothing is built before it stands in porelo's
  stack:
  - B785: `ImportableCredential.rotates: ?bool`, and the same on the vault listing's entries; `SealCredential`'s
    outcome `ROTATES` seals nothing, and `ReceiveCredential` refuses one too. Absent reads as carried.
  - B786: `AgentSignInStart(agent, force, remote, relay: ?bool)`, where `relay` true answers `attach` empty;
    `AgentSignInWatch(agent) -> (state: preparing|waiting-for-you|storing|ended, link: ?string, code: ?string,
    paste: ?bool, ...)`; where `paste` is true the window sends the code the provider shows back once,
    `AgentSignInAnswer(agent, code)`. `link` is only https to a host the agent or provider declares.
    `AgentSignInWait` stays the verdict.
  - A `LOOPBACK` login stays refused with `remote` or `relay` (`LOOPBACK_OVER_SSH`): forwarding its redirect would
    carry the authorization code through the person's computer to a port on the host.
  - B787: `Agents()` `foundVia` gains `login` (signed in on this host, renewed there) beside `vault` (carried, ends at
    its expiry); a start then names that end and the host sign-in.
- **Steps.**
  - Read `rotates` leniently (absent reads as today: carried); a rotating source shows *Made on the host*, with why
    in one sentence, and offers *Sign in on the host* instead of the carry; an API key or another non-rotating
    source keeps the carry and its *Replace it on the host*.
  - *Sign in on the host* drives a `SigningIn` on the host's backend with `remote` and `relay` true and follows
    `AgentSignInWatch`: the dialog shows the link (opened in the browser here on a press, copyable, only https) or
    the code to confirm, and the login's state; where `paste` is true it takes the code the provider shows once and
    sends it by `AgentSignInAnswer`, never logged or kept; `AgentSignInWait` is the verdict. A refusal
    (`ALREADY_SIGNED_IN` offers *Sign in again*, `VAULT_LOCKED` the unlock, `LOOPBACK_OVER_SSH` that this agent's
    login cannot be made from here and how to make it at the host, others in words) is said where pressed.
  - Afterwards the host's providers and the agent's row are read again; the row says *Signed in on the host*. The
    start dialog reads `foundVia` `login` as signed in on the host and `vault` as carried, naming its end where Core
    gives it, beside the vault wording of `StartAgentChoice._mark` (`lib/src/ui/start_work_view.dart`).
  - Against a host whose Porelo knows neither field, the dialog stays as today and says that a provider login copied
    may sign this computer out.
- **Red first** (harm: a rotating login copied and both machines signed out; an API key no longer carried; a link or
  code shown that is not the host's, or a token shown): a model test that a rotating source offers no carry and an
  API key still does; a dialog test of the link, the code and each state; a test that a refused start is said and
  nothing is carried; each seen red.

## Acceptance

- The tests above, each seen red first; `test/ui` and `test/features` green.

## To be checked

- Field names, should Agent Core move them after Agent Smith's answer; and whether `AgentSignInWatch` names the end
  of a carried sign-in for the start dialog.
