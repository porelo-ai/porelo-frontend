# F140 — The Host's Files Written Into The Person's Drive

**Status:** Implementing; it writes into today's layout, the folder `porelo-host/` in the
project's tresor, which porelo-project's issue *A host mounts the person's drives* may change later.
**Size:** M - a folder chosen once per project, the machine file and the host's WireGuard key written
there, the person's own VPN pair kept in the system's secret store.

**What must be true.** The interface writes the files the host reads into the project's locally
synced Tresorit folder, chosen once per project. The host's private WireGuard key travels through
Tresorit; the person's private half stays in the system secret store unless explicitly exported.

## Plan

- `lib/src/app/settings.dart` keeps a `tresorFolders` map keyed by project name, with each key
  and value checked on load. It uses the existing beside-and-rename settings writer, never
  `project.yml`. `lib/src/ui/shell.dart` passes those settings into `HostDialog`.
- `lib/src/ui/host_dialog.dart` uses `getDirectoryPath` to choose or change the local project
  tresor before setup starts. It asks for the repository URL and commit-signing `.pub` path and
  optionally pairs vault entry names with selected files. Without a folder it explains the manual
  copies under `porelo-host/` and leaves *Put on a server* available.
- `packages/porelo_host/lib/src/host_files.dart` handles the pure-Dart preparation. It writes only
  `project: {name, url, signed_by}` and optional `keys` into `porelo-host/machine.yml`; every string
  scalar is quoted and escaped, including every C0, DEL and C1 control as `\uXXXX`. Signing keys
  are fully parsed as ssh-ed25519 (32 bytes) or ssh-rsa (two positive canonical mpints), with no
  trailing bytes, before SHA-256 fingerprinting. Entry names and base names reject traversal and
  option-like names; Windows base names also reject streams, devices and trailing dots/spaces,
  and their uniqueness comparison ignores case. Duplicate entry names are refused too. Key files go into
  `porelo-host/keys/`, and their paths in the machine file are relative.
- X25519 makes two separate WireGuard pairs as 32-byte, standard-base64 private keys. The host's
  key is `porelo-host/wireguard.key`, one line, 0600 on Linux. The person's private half is kept
  under `wireguard-<project>` in `SecretStore.forThisSystem()`. Repeated setup reads the same
  host file and store entry. Only the person's public half enters `up`, resume and `down`, as
  `--vpn-peer-public-key` with `--vpn-peer-address 10.73.0.2/32`.
- Existing differing files or symbolic links are refused by path before `up`. The chosen folder
  itself and its `porelo-host` child are checked without following links; ancestors remain the
  person's choice. Identical files are accepted. `host_file_writer.dart` stages each file in a
  private directory on the destination filesystem, writes through one handle, flushes and closes,
  rechecks that the destination is absent without following links, and publishes by atomic
  no-replace rename. A `finally` removes the staging directory on success and failure. Linux
  requires 0700 staging directories and 0600 files before bytes; Windows restricts the directory
  before writing and the completed file before publication, using checked `icacls` grants for the
  SID read from `whoami`. The dialog keeps the host arguments fixed once setup begins.
- Only after successful `up` exit does the dialog show the host public key, endpoint on port
  51820, `AllowedIPs = 10.73.0.1/32` and `Address = 10.73.0.2/24`. The explicit wg-quick button
  uses `getSaveLocation`, reads the person's private half from the store for that write, and
  keeps the output 0600 on Linux. It never displays or retains the private half in dialog state.
  The person brings the tunnel up with their own WireGuard because that needs root.
- Tests guard incompatible cryptography, wrong signing trust, malformed machine files, traversal,
  accidental key rotation, secret disclosure, destructive writes and mismatched command peers.
  The RFC public-key vector is the first red: reverse the input bytes and observe the mismatch.

## Built so far

- Windows key basenames are read as strings with `package:path` before validation, so a stream
  name produces a safe refusal without converting it to a URI. Native host destinations, staging
  paths and dialog defaults use platform joins; machine YAML retains POSIX relative paths.
  Injected Windows contexts reproduce both regressions on Linux: the stream-name guard first
  received `ArgumentError` instead of `HostFilesRefused`, and the destination guard first received
  mixed separators instead of backslashes. Both guards run without Windows filesystem access.

- The helper, private file writer, settings map, system pickers, optional key imports, file-conflict
  refusal, public peer options and explicit wg-quick export are implemented. The helper and writer
  are exported by the pure-Dart package; no new dependency is needed for the native filesystem
  operations or Windows permission seam.
- A local probe measured Dart `Directory.createTemp` at 0775 with this process's umask. Linux
  therefore uses native `mkdtemp` to make staging private at creation and checks 0700 before
  creating a file. Windows uses `Directory.createTemp` and restricts the empty directory first.
  Linux `renameat2(RENAME_NOREPLACE)` and Windows `MoveFile` refuse an existing destination
  atomically, including a file introduced after the last absence check.
- Store read/write calls turn any `Exception`, including transport and filesystem failures, into
  a fixed refusal without the original error or value. The dialog also guards system-store
  creation and close. Dropped or altered writes fail read-back verification before any command
  starts; setup, export and teardown show the refusal in words. On Windows the dialog states that
  the files are restricted to the user.
- The pure-Dart tests cover the RFC 7748 vector, a fixed signing key with measured
  `ssh-keygen -lf` output, exact machine content, YAML parsing of quotes, colons and newlines,
  unsafe and duplicate names, private-key isolation, key reuse, export permissions, conflicts
  and symbolic links. Mutation runs produced runtime assertion failures for reversed derivation,
  hashing encoded text, raw YAML interpolation, omitted name checks, key rotation, writing the
  person's key to an extra file or a log, omitted permissions, bypassed overwrite checks and followed links.
- External verification confirms the existing package baseline (51 tests) and Flutter baseline
  (1519 tests), including the folder/export scheduling correction. New package security guards
  pass (78 tests) with the five `keystore` tests excluded; each deliberate security mutation
  turned a test red and was restored. The Flutter guards for a store's `SocketException` during
  setup, export and teardown were seen red with the store's exceptions left unwrapped; the whole
  suite passes (1524).
- The folder/export widget test delivers controlled process output and exit through `runAsync`
  and yields the real event loop before pumping frames: file preparation starts that session in
  the real zone, whose pending continuations fake-clock pumping cannot finish. The stop and done
  step are asserted explicitly before interacting or checking the exit guard; secret assertions
  remain intact. The corrected widget test is included in the confirmed Flutter baseline.
- `host_files_security_test.dart` first reproduced 19 runtime failures. The following guards
  state the harm they prevent and the red that was observed before the fix or by mutation:

  | Guard and harm prevented | Observed red |
  |---|---|
  | No early destination, readable mode or partial secret contents | Direct destination creation makes the first-write seam observe an existing destination. |
  | No partial secret or temporary directory after failure | A controlled partial write leaves a destination; omitting `finally` cleanup leaves the temporary directory. |
  | No write through a swapped destination link | A link introduced during writing is accepted when the final no-follow check is absent. |
  | No replacement in the check-to-rename race | Ordinary rename replaces a file introduced in the publication seam. |
  | No bytes after failed or ineffective chmod, or a nonprivate directory | Ignoring measured 0600/0700 modes or accepting nonzero chmod despite mode 0600 fails the guards; failure cleanup is also checked. |
  | No Windows inherited access or unchecked ACL/identity failures | The absent ACL commands fail their exact-argv and first-byte guards; failed whoami, invalid SID and directory/file ACL failures initially publish anyway. |
  | No redirect through either selected-folder or host-child links | The selected-folder link initially succeeds; following links makes the existing child guard fail too. |
  | No fingerprint of malformed or unsupported signing data | Wrong Ed25519 size, incomplete lengths/payloads, missing RSA fields and trailing data are fixtures; removing size, mpint or trailing-byte validation fails at runtime. Valid Ed25519 and RSA fingerprints match measured `ssh-keygen -lf` output. |
  | No Windows devices, streams or colliding destinations | Device/stream/trailing names initially succeed; omitting case folding accepts `Key` and `key`. |
  | No unreadable YAML controls | Short JSON escapes and raw DEL/C1 fail the exact Unicode-escape guard; the complete control set also parses back byte for byte. |
  | No equal-length conflicting file accepted | Omitting byte comparison accepts different machine, WireGuard and export contents of the same length. |
  | No raw store exception or unrecoverable person key | SocketException initially escapes read/write/export; removing read-back equality accepts both dropped and altered writes. |
  | No disclosure during reuse/export through print/stdout/stderr | Each channel is captured with a control marker; deliberate private-key output on each channel fails the guard. |

- In manual-copy mode the host private file is not available here, so the host public key is
  rendered as unavailable and export is disabled. No private key is invented for an unknown host.
  This does not prevent `up`; the person's peer key still comes from the store.
- Private values are scoped to preparation or export calls, never dialog state. This makes no
  promise to wipe Dart memory. The component emits no step or log containing private bytes.
## Acceptance

- A project folder selected with the system picker is kept across settings reloads, independently
  of every other project; malformed stored entries cannot redirect writes. It can change before
  setup starts. Without a folder, copy instructions remain visible and setup is possible.
- With a folder, `machine.yml` has exactly the host contract, with the expected signing fingerprint
  and relative key paths. Quotes, colons and newlines survive YAML parsing. No task or agent list
  appears. Unsafe names and duplicate destinations are refused before writing credential files.
- The host key is a valid WireGuard private key, and derivation matches RFC 7748. Both pairs are
  reused on another setup. Neither private half appears in arguments, steps, logs or machine YAML.
  The person's half appears in no file except an explicitly requested wg-quick export.
- A differing destination, including equal-length data or a file introduced immediately before
  rename, remains byte-for-byte unchanged; its path is named and `up` never starts. Identical
  files are accepted. Selected-folder, host-child and destination links are refused. Secret files
  appear only complete and protected, and staging directories are absent after success or failure.
  Host key, copied key files and explicit export have mode 0600 on Linux; Windows grants only the
  current user full control before publication.
- Up, resume and down carry the same person's public peer and `10.73.0.2/32`. After a successful
  up exit, tunnel settings and an explicit save action are shown when the host key is available;
  a done line before successful exit offers neither. The exported peer is the host public half,
  and the interface explains that the person starts WireGuard with root themselves.
- The system secret store against a real keyring, the desktop flow on Linux, and the Windows
  picker, store, ACLs and `MoveFile` in the Windows build environment.
