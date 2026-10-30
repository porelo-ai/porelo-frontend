# F233 — The Server Type And Zone Chosen When Renting

**Status:** Idea. Held as an Idea (operator, 2026-10-30, after walk 23): wizard changes wait until he has gone through the whole flow again.
**Size:** M - a choice in the wizard's first step, the stock read before renting, and the zone kept with the host for every later call.

**What must be true.** *Prepare a server…* offers a choice of server types, preconfigured, with the default selected; another zone or another server type can be chosen. Before *Prepare the server* the wizard shows whether the chosen type is in stock in the chosen zone. The zone the server was rented in is kept with the host, and every later call for that host (find, the state poll, down and give back) asks that zone, never the default.

## Why

Decided (operator, 2026-10-30): walk 23's step 2-7 was refused with "Rent the server — EM-I220E-NVME is out of stock in fr-par-1", and nothing in the wizard could choose another. `hostArguments` passes only `--scaleway-project` (`lib/src/app/settings.dart`), so `porelo-host` always rents its default offer in its default zone.

The zone matters after renting: `porelo-host` lists, reads and gives back servers under `/baremetal/v1/zones/<zone>/servers` (`packages/porelo_host/lib/src/scaleway.dart`). Down asked in another zone finds no server and reports the give-back as done ("no host carries the project tag"), while the server keeps running and costing. The offer is read only when renting.

## Plan

- Step 1 of 7 (*Where it is rented*) gains *Server type* and *Zone*: a preconfigured list of Elastic Metal offers and zones, `EM-I220E-NVME` in `fr-par-1` selected, each changeable. The list is the interface's own, not typed free.
- Before *Prepare the server*, the wizard reads the chosen offer's stock in the chosen zone through `porelo-host` with the kept Scaleway key (a new read-only command or option; the key never reaches an argument). It shows whether the offer is in stock, and refuses to rent an offer that is out of stock or not offered there, naming the zone and the type.
- Up passes `--zone` and `--offer`. The host's kept settings and its recovery record hold the zone and the type. Down, give back and any find for that host pass the recorded `--zone`. A host recorded before this has `fr-par-1`.
- A host rented in one zone is never looked for in another: a down that finds no server in the recorded zone says so with the zone named, rather than only "done".
- **Red first:** a test that up and down for a host recorded in another zone both pass that `--zone`; a test that an out-of-stock offer stops the wizard before renting.

## Acceptance

- In the wizard, the default type and zone are selected; choosing another type or zone and preparing the server rents exactly that type in that zone.
- A type out of stock in the chosen zone is shown as such before *Prepare the server*, and nothing is rented.
- For a host recorded outside `fr-par-1`, up, down and give back pass that zone to `porelo-host` (shown by the red-first tests, not by a rental).

Built together with [F234](README.md#f234) and [F235](README.md#f235).

## Estimate and test, shared by F233, F234 and F235

- Built as one piece of work with one review cycle and one VM test: `F233+F234+F235 size=M est=70 basis=medians M 61 (24 records) + S 15 (11) + XS 10 (8) = 86 as the ceiling, less about 16 that one shared build, one review and one VM test save`.
- The VM test covers exactly the new dialog part and nothing else: the server type and zone chosen, with stock shown before *Prepare the server*; *Back* blocked and *Finish* closing to *Machines* on Step 7 of 7. It runs on the test VM with a stand-in `porelo-host` named by `PORELO_HOST_STANDIN`: a script that answers the stock read and a rental without asking Scaleway, so nothing is rented and no Scaleway key is on the VM. No full run of every function, no new walk.
