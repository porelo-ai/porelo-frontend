# Contributing

Changes to porelo-frontend follow the guide every Porelo repository shares:
[how to contribute to Porelo](https://porelo-ai.github.io/porelo-project/contributing/). It says how
a change is proposed, reviewed and taken in; this file says only what is particular here.

## In this repository

- **Building and testing:** [build.md](build.md) - the Flutter SDK and the Linux desktop toolchain,
  `dart run build_runner build` after a `.feature` file changes, `dart analyze` and `flutter test`.
  The suite runs against a mock and needs no daemon.
- **The integration leg** drives the built interface against a real Porelo machine over ssh, headless
  (`tool/e2e.sh`, also in [build.md](build.md)); it needs a machine with Porelo set up and its ssh key.
- **Windows** is built and tested by the Build's Windows job; a Windows change can be tried on a
  `windows/` branch first.
