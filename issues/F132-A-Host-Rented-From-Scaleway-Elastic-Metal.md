# F132 — A Host Rented From Scaleway Elastic Metal

**Status:** Implementing; blocked by [F131](README.md#f131) (the provider interface) and [F133](README.md#f133) (the key's store).
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

## Built so far

- `ScalewayElasticMetal` against Elastic Metal API v1 and IAM's ssh keys, read in Scaleway's own
  schema (`/en/developers/api/elastic-metal/v1/schema.yml`):
  - **rent:** the offer by name and Ubuntu 26.04 by name and version, `POST …/servers` with the
    tags, `install` (`os_id`, `hostname`, `ssh_key_ids`) and `user_data` for cloud-init;
  - **ready:** `status` `ready` and `install.status` `completed`, at the IPv4 address;
  - **found again** by `?tags=porelo-project=<name>`, a server being deleted not counted;
  - **given back** by `DELETE`, refused for a server without a project tag.
- **The person's ssh key**, as the operator decided: registered once by hand in Scaleway's console;
  the API key holds Elastic Metal and `SSHKeysReadOnly` only. `up` reads the project's keys and,
  when the person's is missing, ends before renting, printing the line to paste and where. The
  guide's "A project on a server" says so. Seen red: a registration put back into the rent.
- **The host key** is not the API's, which names none: `up` makes an ed25519 pair with `ssh-keygen`.
  The private half goes into cloud-init's `ssh_keys`, and the public half into the tag
  `porelo-host-key=<base64>`, read back by every later `up` and `down`, on any computer.
- `porelo-host up --scaleway-project ID [--zone]` takes the key `key set scaleway` kept ([F133](README.md#f133)).
- Eight tests against recorded answers; seen red: a server without a project tag given back.

## Acceptance

- One real `up` and `down` per release of the package, by hand on the operator's word, with the
  time to `ready` measured and the
  server gone from the account afterwards, read through the API.
- Seen to fail: a key without the right permission is said as such, and an offer out of stock is
  said with the zone.

## To be checked

- Whether `user_data` is sent as a base64 string, as Scaleway's own SDKs send it, or as the
  schema's `{"value": …}`; the first real rent answers it.
- That Ubuntu 26.04 on Elastic Metal says `cloud_init_supported` and takes `ssh_keys`, so the
  host key the tag names is the one sshd offers.
- The time from the rent to `ready`, measured at the first real rent.
