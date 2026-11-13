# F531 — A Windows Card's Daemon Calls Are Bounded Like Its Carried Connections

```json
{
  "$schema": "issue-1.json",
  "id": "F531",
  "title": "A Windows Card's Daemon Calls Are Bounded Like Its Carried Connections",
  "state": "Review",
  "size": "M",
  "priority": "High",
  "rank": 103,
  "blockedBy": [],
  "covers": "On Windows the ssh processes the window starts for one host's card, for its daemon as well as for its forge and homeserver, stay within caps the person can name, as the carrier's own connections already do."
}
```

**Why this size.** M: a choice between three designs, then a pool or a multiplexed relay in the Windows daemon path
with a test that floods calls, watches and carried connections against small caps.

Found in the security reading of the Windows card carrier (Codex `gpt-6.1-sol`, xhigh, 2026-11-13), finding 2,
graded GRAVE there. Not settled in that build: it needs a design decision.

**What must be true.** On Windows, the ssh processes the window starts for one host's card with the person's key,
for its daemon as well as for its forge and homeserver, stay within caps the person can name, as the carrier's own
connections already do (16 per card, 48 in all, 8 starts a second per card); its daemon has one place for each of
its four watches, one for each log and project's pull requests it follows, and 4 for every other call, of which a
stream that ends holds at most 3; the calls and streams that end count under the cap of all, the watches and follows
do not.

## How it stands

- On Windows a card's daemon is reached through `Machine.relayOn` (`lib/src/app/machines.dart`): every
  `Backend.open()` (`lib/src/client/porelo_client.dart`, the relay branch) starts its own
  `ssh -F <card config> -T <host> porelo daemon connect`, and `_call` opens one per call; each watch (Watch, Prompts,
  Talk, Authorizations) holds one for as long as it runs.
- `CarrierBudget` (`lib/src/app/loopback_carrier.dart`) counts the carried service connections and the tunnel's
  readiness probe (`Tunnel._askTheDaemon`), not these.
- So 13 connected cards with their four watches already hold 52 ssh children beside the advertised 48, and concurrent
  calls add more with no admission. The count is driven by the window itself, not by another local program, and the
  key is used once per handshake without confirmation (KeePassXC's agent, as the operator decided for [F290](README.md#f290)).

## Why it is not a plain fix

- Taking a `CarrierBudget` place per daemon connection makes the long-lived watches hold places for good: four per
  card fill the cap of all at twelve cards, and the forge and homeserver connections are then refused.
- Refusing a daemon call past the cap breaks the views that make it; waiting for a place stalls them behind long
  watches.

## Options to decide

1. Two pools: a fixed number of daemon relays per card (the watches plus a small pool for calls, calls waiting for a
   place), and the carrier's caps for the services alone; the cap of all counts both.
2. One relay per card for every daemon call: the window multiplexes its Varlink calls and watches over one
   `porelo daemon connect` (or Core offers a relay that does), so a card costs one ssh for its daemon.
3. Leave the daemon unbounded and say so in [F290](README.md#f290)'s acceptance, since nothing outside the window drives the count.

## Decided

Option 1, two pools (2026-11-13): option 2 needs a new contract of Porelo's or an L in the window's client, and
option 3 leaves the reading's grave finding open. A burst of daemon calls past the call pool waits for a place
instead of starting more ssh.

The cap of all counts only what comes in bursts: the daemon's calls and streams that end, the carried connections
and the readiness probe. The four watches of each card and the places of what it follows (a log, a project's pull
requests) stay outside it: they are bounded by what the person set up and opened, not by anything a program drives,
and counting them would leave a card past the twelfth waiting for its watches for good.

## Acceptance

- On Windows, a test with `inAll` small holds a flood of calls and of carried connections within the stated caps
  beside its daemon's watch, and every view still answers.
- With more cards than the cap of all has room for four watches each, every card's watches and follows start at once
  and none waits; calls and streams that end still wait for the cap of all.
- A burst of daemon calls larger than the call pool waits for places and is answered in turn: none is refused and
  no ssh past the caps is started; a watch keeps its own place throughout.
- On Linux nothing changes: the daemon goes through the card's master as now.
