# F119 — The Code Changed Since The Skills Reading Read Against Them

**Status:** Analyzed.
**Size:** L - 860 files under `lib`, `test`, `tool` and `integration_test` changed since the last
reading, about 37,400 lines added, 17,200 of them in `lib`; each finding fixed with a test seen red.

**What must be true.** Every line of Dart in this repository has been read against the sixteen skills
`AGENTS.md` names, each at a recorded version and SHA-256. Every finding was either fixed with a test
seen to fail first, or declined with its reason written here.

## Why

The whole of `lib`, `test`, `tool` and `integration_test` was read against the skills once, in
`17d641f`, which survives only on the local branch `pre-public`; `main` holds it inside `81b91e9`.
Everything written since has not been read against them. Neither that reading nor its issue
recorded which version of each skill it used.

## Plan

- **The scope** is `git diff 17d641f main -- lib test tool integration_test`, read as whole files
  where a file is new (598 of the 860) and as changed hunks with their surroundings otherwise:

  | Directory | Files | Added | Removed |
  |---|---|---|---|
  | `lib` | 103 (43 new) | 17,228 | 1,522 |
  | `test` | 672 (481 new), 60 % of it `test/features/step` | 17,661 | 1,016 |
  | `tool`, `integration_test` | 85 (74 new) | 2,521 | 28 |

- **The skills, as published now**, each checked against its SHA-256 before it is loaded; the
  versions are read again when the reading starts, and the ones used replace these:

  | Skill | Version | SHA-256 |
  |---|---|---|
  | `dart-add-unit-test` | 2026.910.3 | `3b22d9d1470459b3a7103f243ef6605a6dcf4f30910b658bc22ac9897526ca70` |
  | `dart-build-cli-app` | 2026.910.3 | `9e9caed5bf1e1f06d1bc2764bf401d325cfe16c0003fd8b857c052a4d2f8e3f5` |
  | `dart-collect-coverage` | 2026.910.3 | `6b6cefc79000d2398499a3ed4bb1c7d9aafaf10eb913edaf7644e74147a7dcf9` |
  | `dart-generate-test-mocks` | 2026.910.3 | `36d04ce566bc38f336d676c2c911857203dcefc1833761deadfdf8c5318ffafb` |
  | `dart-resolve-package-conflicts` | 2026.910.3 | `f3eaa18571b5296e9b5efcaeeecc98de8fb7e37e8dfe9abd6a3141aef19a2fc6` |
  | `dart-run-static-analysis` | 2026.910.3 | `925dfd8160f369ac81b440c6be4cc69c10998efeb5a82a531b2a3559ce61b522` |
  | `dart-use-path-package` | 2026.910.3 | `d2f12524f4d6efbb8eed712e767db984aa5b483651157d5a0fd7749dfac647cd` |
  | `dart-use-pattern-matching` | 2026.910.3 | `7f62381040acff9754a7be771686d4d18d69508578ea6f56169b6c0d5f6ac8f2` |
  | `dart-use-primary-constructors` | 2026.910.3 | `b8879260c8b8c959022a3ed70094ca9f58aaaf7f7dfae9b65cf5513adfa56f67` |
  | `dart-write-documentation` | 2026.910.3 | `2cc50c5611094d630c272798fc22ff77f3e5166d4618e7ef398c6a830b06f716` |
  | `flutter-add-integration-test` | 2026.911.3 | `6cf6706ec7d998097711adbc2a00ca016b613d17a5b2044f0e0b9850aee622b4` |
  | `flutter-add-widget-test` | 2026.911.3 | `c0918f867e3c9de492929bf1446f03a39a2f74e6aa0a991fa6fbcbb44a16751b` |
  | `flutter-apply-architecture-best-practices` | 2026.911.3 | `fd37725ebf2a7715fa121a94fb91e7a65e75987a2bbe7f79188eb8513b6e4cf9` |
  | `flutter-build-responsive-layout` | 2026.911.3 | `cfb5fd5fc320ba534950b644638c7db1f032c3bb0b6fa7ce259997e94a69d0cc` |
  | `flutter-fix-layout-issues` | 2026.911.3 | `d3ae723b488c2dab47ed7aa815eef128b5263e5d6ffc9608ba7b2ed489a90930` |
  | `flutter-implement-json-serialization` | 2026.911.3 | `2bdc1a68726438346f5efec715a783d432f5dac02d7b92264307f3bb78545ce1` |

- **The order**, from what reaches a daemon outward: `lib/src/client`, `lib/src/app`, `lib/src/ui`,
  `lib/src/mock`, `tool`, then the tests (`dart-add-unit-test`, `flutter-add-widget-test`,
  `flutter-add-integration-test`, `dart-generate-test-mocks` weigh most there).
- **A finding** is fixed with a test seen to fail first. Otherwise it is declined here with its
  reason. Where a skill contradicts a rule measured here, it is added to the decision "Where a Dart
  or Flutter skill says otherwise" in `doc/decisions.md`, which already settles tolerant readers,
  non-enum backend values, the layout of `lib/src`, `World.settle`, stand-ins instead of `mockito`
  and `integration_test` under xvfb.
- **Red first:** each finding's own test, seen to fail on `main` before its fix.

## Acceptance

- **Every file in the scope was read against all sixteen skills**, and the versions and SHA-256s
  used are in this issue.
- **Each finding is fixed with a test seen to fail without its fix, or declined here with its
  reason**; a skill that contradicts a measured rule is named in `doc/decisions.md`.
- **`dart analyze` is clean and the whole suite is green** on the commit handed over.

## To be checked

- That the skills loaded in the harness are the reviewed packages from `agent-skills` at the
  versions above. The `dart-flutter` plugin installed here may differ, and it does not carry
  `dart-use-path-package` or `dart-write-documentation`.
