# F572 — A Credential Carried From This Computer To A Host

```json
{
  "$schema": "issue-1.json",
  "id": "F572",
  "title": "A Credential Carried From This Computer To A Host",
  "state": "Review",
  "size": "M",
  "priority": "High",
  "rank": 17,
  "blockedBy": [],
  "covers": "Story ST362: a remote machine's provider row offers Import from this computer, a small dialog with this computer's vault entries and the local agents' own sign-in files side by side, and carries the one chosen to the host's vault, never shown, logged or put in a command line."
}
```

**Why this size.** The window's half: one dialog, its sources from porelo and the local readers, and the call that carries. porelo carries the value (Agent Core), and each agent's local sign-in file has a reader (Agent Smith).

**What must be true.** A person signs in once and carries that sign-in to each host from the window, without seeing or typing its value.

## Plan

The window's half of ST362. Agent Core files porelo's half (export from one vault, put into the other over the
machine's connection, porelo to porelo). Agent Smith files the readers of each local agent's own sign-in files, one
per agent adapter.

- A remote machine's provider row offers *Import from this computer…*.
- The dialog lists both kinds side by side. One is the entries of this computer's porelo vault for that provider.
  The other is the local agents' own sign-in files for it, for every provider available locally (Claude Code's,
  Codex's, Gemini's, pi's and omp's, as the local import finds them).
  - Each source shows what it is (kind, account if known, age or expiry if known), never its value.
  - A source that cannot be carried is greyed, with the reason.
- The person picks one, and porelo carries it to the host's vault, and into the agent's own file there where the
  agent needs one. The value is never shown, logged or put in a command line.

## Acceptance

- A guard for the dialog's two kinds and a greyed source; one that the carrying call names the source and never a value; a feature scenario against stand-ins. Each red first.

## Built

Against Agent Core's posted wire shape for B774/B775 (`CredentialReceiver`, `SealCredential`, `ReceiveCredential`),
with the mock daemon answering it until porelo's main has it.

- The client has the three calls. `PoreloBackend` offers them through a separate `CarriesCredentials`, so a stand-in
  that cannot carry shows no button.
- `credential_carry.dart` holds the flow as plain logic over that interface. The host makes a one-use key, this
  computer seals to it, and the host opens it under the name and kind sealed. The window holds only the ciphertext,
  for the one call that hands it on. A kept entry (`EXISTS`) is replaced on asking with a fresh key and a fresh seal,
  since the host's key is spent after one receipt. Every outcome has words for a person, and none carries the value
  or the ciphertext.
- The sources are this computer's vault entries of the provider's name or type, and every local agent that reaches
  the provider's upstream or was found signed in to it. An entry is greyed, with its reason, when this computer's
  vault is shut, when the agent found itself signed out, or when it is signed in to another provider. Until B775's
  listing comes, an agent that cannot say is offered and carrying finds out.
- A remote host's provider row offers *Import from this computer…*. This computer's own page and a WSL page do not.
  The dialog shows both kinds side by side, carries the one picked, says what happened, and offers *Replace it on the
  host* for a kept entry. Afterwards the host's providers are read again.
- Guards, each seen red under a deliberate break: `test/app/credential_carry_test.dart` (6),
  `test/ui/carry_credential_dialog_test.dart` (3), and the host row in `test/ui/import_words_test.dart`.

Left as [F575](README.md#f575): a feature scenario across two stand-in machines (the feature world has one backend), and the live
check against B774/B775 once they are on porelo's main.

With B775: the agent sources are porelo's `ImportableCredentials` rows for the provider, each with its kind. Where a
Porelo does not know that call, the agents' own findings stand in as before.
