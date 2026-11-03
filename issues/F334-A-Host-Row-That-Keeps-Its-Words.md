# F334 — A Host Row That Keeps Its Words

**Status:** Accepted.

**What must be true.** A machine's row says one steady thing while a host keeps refusing, in words of what the person can do,
and never talks of a forward.

In a walk, on a host still waiting for its token, the row under *Machines* flipped back and forth between a text about raising
the forward and `The host refused this account or its selected key. A host makes your account only after it has read the
organization, up to five minutes after your project is on it, and a host still waiting for a token has made none yet.`

## Why it flips

Read from the code, not run. There is one source, not two: `Tunnel.words`, by the tunnel's state, and the row shows it after
the host's name.

- `TunnelState.raising` says `raising the forward…`, and `_raiseCard` clears `problem` as it starts, so the refusal disappears.
- ssh ends with `Permission denied`, the state is `down`, and `words` is the refusal again.
- `Machines` listens to the machine's `Fleet`: any notice while it is unreachable calls `raiseAgainIfNeeded`, which raises
  again. The window's refresh, every 60 seconds by default, is one such notice; `_raisingAgain` only keeps it to one at a time.

So each try blanks the refusal for as long as ssh takes to be refused. The retry is right, since a host makes the account
later and nobody should have to ask. Showing it as a change of state is what is wrong.

No text in the code reads `raised the forward`, and none ever did on these branches: the walk's note most likely renders
`raising the forward…`.

## Should the words reach the person

Not these. *Forward* says how the interface reaches a machine, and nobody can act on it. The fix is in the words and in the
state:

- A try after a refusal keeps the refusal on the row, with no state of its own to show.
- A first try says `Connecting…`.
- The other forward messages in `tunnel.dart` are worded the same way, as far as they reach a person.

## To be checked

- How often it really tries at a host that refuses. No lockout on the host side was found in a search for `fail2ban` and
  sshd limits, but that search was short, and a host could count these as failed logins.
- That the row stays steady, in a test with a fake ssh that keeps refusing, seen red before the fix.
