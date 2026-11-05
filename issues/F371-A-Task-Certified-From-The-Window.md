# F371 — A Task Certified From The Window

**Status:** Review.
**Size:** M - a signing step at the desk over the second call, and renewing a certificate; Core carries the request.

**What must be true.** Work started from the window on a host starts. In the foo test, *Start work in foo-project* got through the project, machine, vault, gate mirror and login, then refused at "Preparing and building" with "this host starts a task only with a key of its own that you certify: add the key of your card to your agent (ssh-add) and start it again". The advice cannot help a person at their desk, as their agent is there and the host rightly gets none.

## Why, by reading

- **A host starts no task without a certificate.** It records each task's certificate and makes its forge token from it.
- **The window never certifies.** A start goes through the daemon's `Start` over the tunnel, and nothing in the window asks for or answers a certificate. This holds for *Start work* and for *Start an agent for each repository…*.
- **The agent is rightly not forwarded.** `ForwardAgent=no` stays.
- **The command line can do it:** `porelo task start TASK --host LOGIN@HOST --project PROJECT`, whose key the desk's agent certifies, with the host asking on one line of its output and reading the answer from its input.
- **The refusal's words send the person the wrong way** when the start came from the window.
- **Renewing is missing too.** A certificate lasts seven days, and nothing in the window offers `porelo task certify`.

## The shape

**Decided:** `Start` carries the certificate request, and the window signs by the local agent. The other way falls away.

Two ways, to be chosen with Core:

1. **The daemon's `Start` carries the certificate request,** and the window has the local agent sign it, showing what is signed. This keeps the start form, the wizard and their progress as they are, and needs a change in Core and a signing step here. This one is recommended.
2. **The window starts by the local command** with `--host`, and reads its output for progress. No change in Core, but the form and the wizard leave the stream they are built on.

Either way, the agent never leaves the desk, and what is certified is checked here first: an Ed25519 key, the one task's principal, at most the allowed time.

A card key missing from the desk's agent says so in the window, and a renewal is offered before a certificate ends.

## Plan

The contract with Core: `Start` takes `certify`; its stream gives one `certify` request; `Certify(start, certificate?, refused?)` answers it.

1. `task_certifying.dart` checks what was asked as the command line does, finds the first certifier the agent lists, and signs with `ssh-keygen` by the agent. A test runs this against a real agent with a throwaway key.
2. `PoreloBackend` answers in the start's stream, for the form, the wizard and *Start it again*, and says what it signed; a refusal goes to the host so its wait ends.
3. Renewal: a command for a certified task runs `porelo task certify`, and a task says before its certificate ends, on a field Core gives.

## Acceptance

- *Start work* and the wizard start a task on a host from the window, with the agent on the desk only. Seen to fail first.
- A card key not in the desk's agent is said beside the start, naming the key.
- A task's certificate can be renewed from the window, and it says before it ends.
- A real run on a machine, since a fixture cannot prove this.

## To be checked

- The renewal on a host known only by its card or on another port. From the window on an ordinary ssh machine it was seen to work, with the row's end not moving, which is the daemon's answer.
- The tile's word on a real daemon, which says a certificate's end once Core gives the field.
- A real start on a machine, with the desk's agent, and how the window reads the refusal when the person's words go back to the host.
- How the rehearsal passed this step, as the coordinator asks, which is Core's to say.
- Where a task started by the command line stands in the window, and whether its follow-ups work.
- The warning "cannot record the start's step", which came with this refusal.
