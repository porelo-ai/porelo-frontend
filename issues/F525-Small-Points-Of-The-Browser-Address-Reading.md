# F525 — Small Points Of The Browser Address Reading

```json
{
  "$schema": "issue-1.json",
  "id": "F525",
  "title": "Small Points Of The Browser Address Reading",
  "state": "Backlog",
  "size": "S",
  "priority": "Medium",
  "rank": 98,
  "blockedBy": [],
  "covers": "The small points a reading by another model found in the host's browser addresses on both loopbacks: guards no test shows, and Windows taking an IPv6 loopback for granted."
}
```

**Why this size.** S: tests for guards that have none, and the Windows branch of the IPv6 loopback check.

**What must be true.** Each guard of [F509](README.md#f509) has a test that fails without it, and a Windows desktop
without `::1` gets the 127.0.0.1 address instead of a refused card.

## Why

The reading of [F509](README.md#f509)'s final change found, beside the grave points fixed there:
- The occupied-`::1` test skips where the machine has no IPv6 loopback, and the ssh master fakes bind no port, so a
  failed `-O forward` on a live master is shown only by its refused exit, never by a port actually taken.
- Replacing the start-up detection with `HostCardSsh.ipv6Loopback = true` leaves every test green; removing `v6Only:
  true` from the pre-check has no test of its own.
- On Windows `hasIpv6Loopback` answers true without looking (`packages/porelo_host/lib/src/host_card_ssh.dart`), so a
  desktop without `::1` refuses the card at the pre-check instead of falling back to 127.0.0.1.

## Plan

- A test that binds the port on the other family in the ssh fake and runs a renewal through it.
- A test of the start-up detection on a given `if_inet6` text and one that fails without `v6Only`.
- On Windows, the IPv6 loopback found by binding `::1:0` once; a test with the seam.

## Estimate

`F525 size=S est=15 basis=median S 15 (11 records)`
