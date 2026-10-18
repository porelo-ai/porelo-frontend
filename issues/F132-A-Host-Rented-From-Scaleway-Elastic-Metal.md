# F132 — A Host Rented From Scaleway Elastic Metal

**Status:** Backlog; blocked by [F131](README.md#f131) (the provider interface) and [F133](README.md#f133) (the key's store).
**Size:** M - one REST adapter, its answers recorded, and one real rent.

**What must be true.** `porelo-host up` rents an Elastic Metal server from Scaleway, the offer
[PJ40](https://github.com/porelo-ai/porelo-project/blob/main/issues/README.md#pj40) measured (EM-I220E-NVME), with Ubuntu 26.04, the project's tags and the person's public key.
`down` gives it back, so nothing goes on billing after it. The provider's key comes from the
system's secret store ([F133](README.md#f133)) and appears in no file, log or argument.

## Plan

- **Where, as decided:** the Porelo project at Scaleway, zone `fr-par-1` first, with a key of its
  own for Elastic Metal only. No Scaleway secret is on GitHub, so the Build tests against recorded
  answers only. One real rent per release of the package, by hand on the operator's word.
- `ScalewayElasticMetal implements HostProvider`, on `package:http` against the Elastic Metal API
  v1, `X-Auth-Token` from [F133](README.md#f133):
  - create the server with its offer, zone, name and tags;
  - install it with the OS, hostname and ssh key;
  - poll its state until it is `ready`;
  - read its address;
  - delete it.
- **The host key:** read from the server's console output or the user data's own report, never a
  keyscan. Which of the two Scaleway offers is to be checked.
- **A server it did not tag is never deleted.** A `down` finds the host by the project's tag
  alone.
- **The red test first:** recorded answers for create, poll, ready and delete. It is run red with
  the delete given an untagged server.

## Acceptance

- One real `up` and `down` per release of the package, by hand on the operator's word, with the
  time to `ready` measured and the
  server gone from the account afterwards, read through the API.
- Seen to fail: a key without the right permission is said as such, and an offer out of stock is
  said with the zone.

## To be checked

- Whether the create or install call takes cloud-init user data on Elastic Metal: the API
  reference names `tags` and `install`, and Scaleway's concepts page says cloud-init runs at the
  first boot.
- How the host key is reported, and the time an install takes.
