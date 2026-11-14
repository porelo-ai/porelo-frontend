// Linux only: it runs the Linux packaging in Bash.
@Tags(<String>['linux'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/product.dart';
import 'package:yaml/yaml.dart';

/// What the packaging promises, held to without building a package.
///
/// Building one takes a release build and two external tools, so it belongs in `tool/package.sh`
/// and on a build machine. What belongs here is everything that can go wrong quietly: a desktop
/// entry pointing at a binary by a name the package does not install, a dependency list that
/// somebody started writing down, an architecture claimed that nothing builds.
void main() {
  final commented = File('packaging/nfpm.yaml.in').readAsStringSync();

  // Comments stripped before anything is asserted. Every rule below is also *explained* in that
  // file, so a plain `contains` matches the sentence describing a directive as readily as the
  // directive — which is how the first version of this passed with the bundle flattened.
  final template = commented.split('\n').where((line) => !line.trimLeft().startsWith('#')).join('\n');
  final desktop = File('packaging/porelo-frontend.desktop').readAsStringSync();

  String desktopField(String key) => desktop
      .split('\n')
      .firstWhere((line) => line.startsWith('$key='), orElse: () => '$key=')
      .substring(key.length + 1)
      .trim();

  test('the desktop entry starts the binary the package actually installs', () {
    // The entry in /usr/bin is a symlink named porelo-frontend; the bundle's own launcher is
    // porelo_frontend, with an underscore. Pointing Exec at the wrong one gives a menu entry that
    // does nothing, and nothing about installing the package would say so.
    expect(desktopField('Exec'), 'porelo-frontend');
    expect(template, contains('dst: /usr/bin/porelo-frontend'));
    expect(template, contains('type: symlink'));
  });

  test('the desktop entry names an icon the package installs', () {
    final icon = desktopField('Icon');

    expect(icon, isNotEmpty);
    expect(template, contains('$icon.svg'));
    expect(File('packaging/$icon.svg').existsSync(), isTrue);
  });

  test('the desktop entry has what a menu needs to draw it', () {
    for (final key in <String>['Type', 'Name', 'Comment', 'Categories']) {
      expect(desktopField(key), isNotEmpty, reason: '$key is what a menu draws');
    }
    expect(desktopField('Type'), 'Application');
  });

  test('every place that names the interface on screen calls it by the product name', () {
    // The window's title is set by each platform's runner, not by the app, so a name changed in
    // Dart alone leaves the title bar saying the binary's name.
    expect(desktopField('Name'), productName);
    final runners = <String, String>{
      'linux/runner/my_application.cc': '"$productName"',
      'windows/runner/main.cpp': 'L"$productName"',
      'windows/runner/Runner.rc': 'VALUE "ProductName", "$productName"',
      'packaging/windows/AppxManifest.xml.in': '<DisplayName>$productName</DisplayName>',
    };
    for (final MapEntry(key: path, value: named) in runners.entries) {
      expect(File(path).readAsStringSync(), contains(named), reason: '$path does not say $productName');
    }
    expect(
      File('linux/runner/my_application.cc').readAsStringSync(),
      isNot(contains('"porelo_frontend"')),
      reason: 'the Linux window still takes its title from the binary',
    );
    expect(
      File('windows/runner/main.cpp').readAsStringSync(),
      isNot(contains('L"porelo_frontend"')),
      reason: 'the Windows window still takes its title from the binary',
    );
  });

  test('dependencies are not written down anywhere', () {
    // The criterion is that they are derived from the binary. A hand-written list goes stale the
    // first time Flutter changes what it links, and the failure is a package that installs and
    // then opens no window — so the template must carry none at all.
    expect(
      template.contains('\ndepends:'),
      isFalse,
      reason: 'dependencies belong to dpkg-shlibdeps and the ELF, not to this file',
    );
    expect(template.contains('\nrequires:'), isFalse);
  });

  test('the backend is recommended, never required', () {
    // An interface pointed at a remote daemon over a forwarded socket is useful with no local
    // backend at all, so a hard dependency would put one on a laptop that never needed it.
    expect(template, contains('recommends:'));
    expect(template, contains('- porelo'));
  });

  test('the bundle is installed as a tree, not flattened into one directory', () {
    // A plain src/dst pair puts libapp.so and icudtl.dat beside the launcher instead of under
    // lib/ and data/. The package installs; the application then finds nothing and opens no
    // window. This shipped once in this repository before it was caught.
    expect(template, contains('type: tree'));
  });

  test('nothing claims an architecture nothing builds', () {
    // Flutter has no cross-compile for Linux desktop, so an arm64 package needs an arm64 builder
    // and there is not one. Claiming the architecture would produce a package that installs on a
    // Pi and cannot run.
    expect(template, contains('arch: amd64'));
    expect(template.contains('arm64'), isFalse);
  });

  test('the version comes from pubspec rather than being kept in two places', () {
    expect(template, contains('@VERSION@'));
    final script = File('tool/package.sh').readAsStringSync();
    expect(script, contains('pubspec.yaml'));
    // `0.4.0-SNAPSHOT` in pubspec is `0.4.0~snapshot.<run>` in the package, never both suffixes.
    expect(script, contains(r'base="${base%-SNAPSHOT}"'));
  });

  test('the packaging script refuses to ship either format with no dependencies', () {
    // The derivation failing silently is the dangerous outcome: an empty list is a package that
    // installs anywhere and runs nowhere. Both formats derive separately, so both are named
    // separately — one message covering both would let either guard be removed unnoticed.
    final script = File('tool/package.sh').readAsStringSync();
    expect(script, contains('refusing to ship a deb with no dependencies'));
    expect(script, contains('refusing to ship an rpm with no dependencies'));
  });

  // Harm: the installed collection is root's alone, the window's porelo-host cannot read it, and the setup runs
  // without its check while saying the collection holds none. A download lands in a mktemp file, mode 0600, and a
  // plain cp keeps that mode up to the package.
  test('the carried collection is fetched and bundled readable by every account', () async {
    final scratch = await Directory.systemTemp.createTemp('collection-mode-');
    addTearDown(() => scratch.delete(recursive: true));
    final source = await Directory('${scratch.path}/source').create();
    final asset = File('${source.path}/porelo-host-0.6.0.tar.gz');
    await asset.writeAsBytes(const [1, 2, 3]);
    await Process.run('chmod', ['600', asset.path]);
    const digest = '039058c6f2c0cb492c533b0a4d14ef77cc0f78abccced5287d84a1a2011cfb81';
    await File('${source.path}/SHA256SUMS').writeAsString('$digest  porelo-host-0.6.0.tar.gz\n');
    final out = '${scratch.path}/out';
    final ran = await Process.run(
      'bash',
      ['tool/fetch_collection.sh', '0.6.0', digest, out],
      environment: {'PORELO_COLLECTION_SOURCE': source.path},
    );
    expect(ran.exitCode, 0, reason: '${ran.stderr}');
    expect(File('$out/porelo-host-0.6.0.tar.gz').statSync().mode & 0x1ff, 0x1a4, reason: 'mode 0644');
    final script = File('tool/package.sh').readAsStringSync();
    expect(script, contains(r'install -m 0644 -- "build/collection/$collection_file" "$bundle/$collection_file"'));
  });

  group('the snapshot collection', () {
    const version = '0.5.13-snapshot.412';
    const file = 'porelo-host-$version.tar.gz';
    // The SHA-256 of the bytes 1, 2, 3.
    const digest = '039058c6f2c0cb492c533b0a4d14ef77cc0f78abccced5287d84a1a2011cfb81';
    final commit = List.filled(40, 'a').join();
    late Directory scratch;
    late Directory source;

    setUp(() async {
      scratch = await Directory.systemTemp.createTemp('snapshot-collection-');
      addTearDown(() => scratch.delete(recursive: true));
      source = await Directory('${scratch.path}/source').create();
      await File('${source.path}/$file').writeAsBytes(const [1, 2, 3]);
      await File('${source.path}/SHA256SUMS').writeAsString('$digest  $file\n');
    });

    Future<ProcessResult> fetch(String sha256, {Map<String, String> environment = const {}}) => Process.run(
      'bash',
      ['tool/fetch_collection.sh', version, sha256, '${scratch.path}/out', file],
      environment: {'PORELO_COLLECTION_SOURCE': source.path, ...environment},
    );

    Future<ProcessResult> choose(String channel, {String? pointer}) async {
      if (pointer != null) await File('${source.path}/latest.json').writeAsString(pointer);
      return Process.run(
        'bash',
        ['tool/host_collection.sh', channel],
        environment: {'PORELO_COLLECTION_SOURCE': source.path},
      );
    }

    String pointer({Object v = version, Object f = file, Object s = digest, Object? c}) =>
        jsonEncode({'version': v, 'file': f, 'sha256': s, 'commit': c ?? commit});

    // Harm: a snapshot window carries a collection nobody checked, or the build cannot fetch the snapshot at all and
    // falls back to what the release lacks.
    test('a snapshot collection is taken by its digest alone, from the snapshot release', () async {
      final wrong = await fetch(List.filled(64, 'b').join());
      expect(wrong.exitCode, isNot(0), reason: 'another digest must be refused');
      expect(File('${scratch.path}/out/$file').existsSync(), isFalse, reason: 'nothing refused may be handed on');

      final right = await fetch(digest);
      expect(right.exitCode, 0, reason: '${right.stderr}');
      expect(File('${scratch.path}/out/$file').readAsBytesSync(), const [1, 2, 3]);

      // Without a local source it asks GitHub; a stand-in curl names what it was asked and answers 404.
      final bin = await Directory('${scratch.path}/bin').create();
      final asked = File('${scratch.path}/asked');
      final curl = File('${bin.path}/curl')
        ..writeAsStringSync('#!/bin/sh\nprintf "%s\\n" "\$@" >> "${asked.path}"\nprintf 404\n');
      await Process.run('chmod', ['755', curl.path]);
      final online = await Process.run(
        'bash',
        ['tool/fetch_collection.sh', version, digest, '${scratch.path}/online', file],
        environment: {
          'PATH': '${bin.path}:${Platform.environment['PATH']}',
          'PORELO_COLLECTION_SOURCE': '',
          'PORELO_COLLECTION_CACHE': '${scratch.path}/cache',
          'GITHUB_SERVER_URL': '',
        },
      );
      expect(online.exitCode, isNot(0), reason: 'a 404 must fail the fetch');
      expect(
        asked.readAsStringSync(),
        contains('https://github.com/porelo-ai/porelo-host/releases/download/snapshot/$file'),
      );
    });

    // Harm: a malformed or tampered pointer names a collection the build then compiles in and carries.
    test('a snapshot pointer is refused unless every field has its form', () async {
      final malformed = <String, String>{
        'not JSON': 'version=$version',
        'a list': '[]',
        'no commit': jsonEncode({'version': version, 'file': file, 'sha256': digest}),
        'a release version': pointer(v: '0.5.13', f: 'porelo-host-0.5.13.tar.gz'),
        'a version as a number': pointer(v: 5),
        'a file of another version': pointer(f: 'porelo-host-0.5.13-snapshot.411.tar.gz'),
        'a file in another directory': pointer(f: '../$file'),
        'a short digest': pointer(s: digest.substring(1)),
        'an upper-case digest': pointer(s: digest.toUpperCase()),
        'a short commit': pointer(c: commit.substring(1)),
        'a commit with a second line': pointer(c: '$commit\nx'),
        'a commit with a trailing newline': pointer(c: '$commit\n'),
      };
      for (final MapEntry(key: what, value: text) in malformed.entries) {
        final said = await choose('snapshots', pointer: text);
        expect(said.exitCode, isNot(0), reason: '$what must be refused; got ${said.stdout}');
        expect('${said.stdout}', isEmpty, reason: '$what must name no collection');
      }
      expect((await choose('nightly', pointer: pointer())).exitCode, isNot(0), reason: 'an unknown channel');
    });

    // Harm: the build carries a collection other than the one the pointer names.
    test('a good snapshot pointer gives version, digest, file and commit on one line', () async {
      final said = await choose('snapshots', pointer: pointer());
      expect(said.exitCode, 0, reason: '${said.stderr}');
      expect('${said.stdout}', '$version $digest $file $commit\n');
    });

    // Harm: a release window carries a snapshot collection, or whichever the newest pointer names instead of the
    // release it was tested with.
    test('a release keeps the pinned release collection, whatever the snapshot pointer says', () async {
      final pinned = await Process.run('dart', ['packages/porelo_host/bin/porelo_host.dart', '--collection-info']);
      expect(pinned.exitCode, 0, reason: '${pinned.stderr}');
      final [pinnedVersion, _, _] = '${pinned.stdout}'.trim().split(' ');
      expect(pinnedVersion, matches(RegExp(r'^\d+\.\d+\.\d+$')), reason: 'the pin must be a release');

      final said = await choose('releases', pointer: pointer());
      expect(said.exitCode, 0, reason: '${said.stderr}');
      expect('${said.stdout}', '${'${pinned.stdout}'.trim()} v$pinnedVersion\n');
    }, timeout: const Timeout(Duration(minutes: 3)));

    // Harm: one of the builds still takes the release pin for a snapshot, or compiles porelo-host without the
    // collection it carries.
    test('every build that carries the collection takes it from the one choice by its channel', () {
      final linux = File('.github/workflows/build.yml').readAsStringSync();
      final trial = File('.github/workflows/windows.yml').readAsStringSync();
      final package = File('tool/package.sh').readAsStringSync();
      final prepare = File('tool/windows-prepare.ps1').readAsStringSync();
      for (final (name, text) in [('build.yml', linux), ('windows.yml', trial)]) {
        expect(text, isNot(contains('bin/porelo_host.dart --collection-info')), reason: '$name asks the pin directly');
      }
      expect(RegExp('tool/host_collection.sh').allMatches(linux).length, 2, reason: 'the Linux and Windows jobs');
      expect(RegExp('tool/host_collection.sh').allMatches(trial).length, 1, reason: 'the Windows trial');
      for (final (name, text) in [('package.sh', package), ('windows-prepare.ps1', prepare)]) {
        for (final define in ['version', 'file', 'sha256']) {
          expect(text, contains('-Dporelo_host.collection.$define='), reason: '$name compiles in the $define');
        }
      }
    });
  });

  // Harm: a packaged window, built in release mode, does not know it is a snapshot and sets machines up from
  // releases; or its version differs from its packages' and the About dialog names neither truly.
  test('every build of the window stamps it with its packages\' version', () {
    final package = File('tool/package.sh').readAsStringSync();
    expect(package, contains('flutter build linux --release --dart-define=PORELO_VERSION="\$version"'));
    for (final name in ['build.yml', 'windows.yml']) {
      final workflow = File('.github/workflows/$name').readAsStringSync();
      final builds = RegExp(r'flutter build windows[^\n]*').allMatches(workflow).map((each) => each[0]).toList();
      expect(builds, ['flutter build windows --release "--dart-define=PORELO_VERSION=\$version"'], reason: name);
      expect(workflow, contains('echo "PORELO_WINDOW_VERSION=\$version" >> "\$GITHUB_ENV"'), reason: name);
    }
    final prepare = File('tool/windows-prepare.ps1').readAsStringSync();
    expect(prepare, contains(r'$env:PORELO_WINDOW_VERSION -ne $version'), reason: 'windows-prepare.ps1 checks it');
  });

  group('the build that publishes them', () {
    final workflow = File('.github/workflows/build.yml').readAsStringSync();

    test('a deb is uploaded with the properties that make it indexable', () {
      // Without them Artifactory stores the file and never indexes it: apt sees nothing and no
      // error appears anywhere. This is the single line whose absence is invisible.
      expect(workflow, contains(r'deb.distribution=${CHANNEL}'));
      expect(workflow, contains('deb.component=main'));
      expect(workflow, contains('deb.architecture=amd64'));
    });

    test('it publishes to the distribution the channel names, which consumers name', () {
      // A consumer puts that word in their sources.list, so snapshots and a release can never mix.
      expect(workflow, contains('porelo-dist-deb/pool/main/p/porelo-frontend/'));
      expect(workflow, contains(r'porelo-dist-rpm/${CHANNEL}/'));
      expect(workflow, contains(r'dists/${CHANNEL}/main'));
    });

    // The channel decides the version the packages carry, so it is run here as the build runs it.
    group('which channel', () {
      final steps = ((loadYaml(workflow) as YamlMap)['jobs']['build']['steps'] as YamlList);
      final script = (steps.firstWhere((step) => (step as YamlMap)['id'] == 'channel') as YamlMap)['run'] as String;

      Future<({int code, String output, String env})> decide(String version, String refType, String ref) async {
        final here = Directory.systemTemp.createTempSync('channel-');
        addTearDown(() => here.deleteSync(recursive: true));
        File('${here.path}/pubspec.yaml').writeAsStringSync('version: $version\n');
        final ran = await Process.run(
          'bash',
          <String>['-c', script.replaceAll(r'${{ github.ref_type }}', refType)],
          workingDirectory: here.path,
          environment: <String, String>{
            'GITHUB_OUTPUT': '${here.path}/output',
            'GITHUB_ENV': '${here.path}/env',
            'GITHUB_REF_NAME': ref,
          },
        );
        String read(String name) =>
            File('${here.path}/$name').existsSync() ? File('${here.path}/$name').readAsStringSync() : '';
        return (code: ran.exitCode, output: read('output'), env: read('env'));
      }

      test('main publishes a snapshot', () async {
        final said = await decide('0.4.0-SNAPSHOT', 'branch', 'main');
        expect((said.code, said.output.trim(), said.env), (0, 'channel=snapshots', ''));
      });

      test('a tag naming the version in pubspec publishes the release', () async {
        final said = await decide('0.4.0', 'tag', 'v0.4.0');
        expect((said.code, said.output.trim(), said.env.trim()), (0, 'channel=releases', 'RELEASE=1'));
      });

      test('a tag on a snapshot, or naming another version, is refused', () async {
        expect((await decide('0.4.0-SNAPSHOT', 'tag', 'v0.4.0-SNAPSHOT')).code, isNot(0));
        expect((await decide('0.4.0', 'tag', 'v0.5.0')).code, isNot(0));
      });
    });

    test('a release package carries the version itself, a snapshot its run', () {
      final script = File('tool/package.sh').readAsStringSync();
      expect(script, contains(r'version="$base~snapshot.$run"'));
      expect(script, contains(r'if [ "${RELEASE:-0}" = 1 ]; then version="$base"; fi'));
    });

    test('check-actions runs in the build', () {
      // The one test for what a build runs being pinned, for every Porelo repository alike: the
      // pins, Dependabot with its cooldown and group, and the digest of what mvnw downloads.
      expect(
        File('.github/workflows/build.yml').readAsStringSync(),
        contains('org.fuin.porelo.release.Main check-actions'),
      );
    });

    test('the builder that writes the packages is pinned by digest', () {
      // It is fetched and then run, and what it produces is what gets published. A version tag
      // names what was meant; only the digest says what arrived. Without the check, an asset
      // replaced upstream would build packages nobody here has ever seen.
      final fetched = RegExp(r'nfpm_([0-9.]+)_Linux_x86_64\.tar\.gz').firstMatch(workflow);
      expect(fetched, isNotNull, reason: 'the workflow no longer fetches nfpm by that name');
      expect(workflow, matches(RegExp(r'nfpm_sha=[0-9a-f]{64}')));
      expect(workflow, contains('sha256sum -c -'), reason: 'the digest is declared and never checked');
    });

    test('the secret names are the ones that exist, not invented ones', () {
      expect(workflow, contains(r'secrets.JF_ACCESS_TOKEN'));
      expect(workflow, contains(r'vars.JF_URL'));
    });

    test('every Linux job that builds the bundle builds on the oldest distribution it installs on', () {
      // The bundle links the system GTK3 stack, so the build machine sets the floor. A job that
      // slipped to a newer runner would produce a package that installs nowhere older, and
      // nothing about the run would say so. Jobs that build nothing may run on a newer one.
      final building = <String>{
        for (final job in _jobs(workflow).entries)
          if (job.value.contains('tool/package.sh')) job.key,
      };
      expect(building, containsAll(<String>['build']), reason: 'no job packages the Linux bundle any more');
      for (final job in building) {
        expect(
          _jobs(workflow)[job],
          contains("runs-on: \${{ vars.PORELO_PUBLISH == 'true' && 'ubuntu-22.04' ||"),
          reason: '$job builds the bundle, on 22.04 wherever it publishes',
        );
      }
      expect(workflow.contains('runs-on: ubuntu-latest'), isFalse);
    });

    test('the publish is not believed until the index carries it', () {
      // An upload that succeeded is not a package anybody can install: Artifactory indexes
      // asynchronously, and a missing index, an empty one and a late one look identical from a
      // client. The only difference is how long you are willing to look.
      expect(workflow, contains('uploaded but not indexed'));
      expect(workflow, contains('binary-amd64/Packages'));
      expect(workflow, contains('repomd.xml'));
    });

    test('a failure reports what it asked and what came back, not a cause', () {
      // It said "check that the token has Annotate as well as Deploy" — a confident diagnosis,
      // and wrong: the packages were indexed and the URL was malformed.
      expect(workflow.contains('check that the token has Annotate'), isFalse);
      expect(workflow, contains('What was asked for and what came back is above'));
      expect(workflow, contains(r"deb index: HTTP $(curl"));
    });

    test('the index check follows redirects, or it reads an empty body', () {
      // Artifactory answers an artifact with a 302 to a CDN, and `curl -f` treats a redirect as
      // success — so without -L the body is empty, nothing matches, and a perfectly well indexed
      // package is reported as "not indexed".
      expect(workflow.contains('curl -fsS "'), isFalse, reason: 'every fetch in the index check needs -L');
    });

    test('the index check retries rather than probing once', () {
      // A single probe of an asynchronous index is a coin toss, not a measurement.
      expect(workflow, contains(r'for attempt in $(seq 1 20)'));
    });

    test('the version it looks for is the one in the package, not the filename', () {
      // A filename is what the build wrote; the Version field is what apt reads.
      expect(workflow, contains(r'dpkg-deb -f packages/*.deb Version'));
    });

    test('the packages are proven to install before they are published', () {
      expect(workflow, contains('needs: [build, installs, legs, integration, windows]'));
      expect(workflow, contains("needs.build.result == 'success' && needs.installs.result == 'success'"));
      for (final system in <String>[
        'ubuntu:26.04@sha256:',
        'debian:13@sha256:',
        'fedora:43@sha256:',
        'fedora:44@sha256:',
      ]) {
        expect(workflow, contains(system), reason: 'each supported system, pinned by its digest');
      }
      expect(workflow, isNot(contains('debian:12')), reason: 'below what Porelo supports');
      expect(workflow, isNot(contains('fedora:40')), reason: 'below what Porelo supports');
    });

    // Nothing is published from a red build: a release and a snapshot both wait for the rented
    // machine's leg, which passed in this run or proved this very tree in one before.
    test('a release and a snapshot wait for the rented machine\'s leg to pass', () {
      expect(workflow, contains("(needs.integration.result == 'success'\n"));
      expect(
        workflow,
        contains(
          "|| (needs.integration.result == 'skipped' && needs.legs.outputs.proven == 'yes'\n"
          "                    && !startsWith(github.ref, 'refs/tags/')))",
        ),
      );
      expect(
        workflow,
        isNot(contains("!startsWith(github.ref, 'refs/tags/v'))")),
        reason: 'a red leg published a snapshot',
      );
      expect(workflow, contains('!cancelled()'), reason: 'a skipped or red job must not make Publish run anyway');
    });

    // Decided, after a run of 1 h 29 min: no job runs without a limit, and the
    // leased machine's test stops before the job does, so the sweep after it still runs.
    test('every job stops after a limit, and the lease leaves time for its sweep', () {
      for (final file in Directory('.github/workflows').listSync().whereType<File>()) {
        final jobs = (loadYaml(file.readAsStringSync()) as YamlMap)['jobs'] as YamlMap;
        for (final job in jobs.entries) {
          expect((job.value as YamlMap)['timeout-minutes'], isA<int>(), reason: '${file.path}: ${job.key}');
        }
      }
      final integration = ((loadYaml(workflow) as YamlMap)['jobs'] as YamlMap)['integration'] as YamlMap;
      final lease = (integration['steps'] as YamlList).cast<YamlMap>().firstWhere(
        (each) => each['name'] == 'Lease, test and sweep',
      );
      expect(lease['timeout-minutes'] as int, lessThan(integration['timeout-minutes'] as int));
    });

    test('no action is left on a runtime GitHub has deprecated', () {
      // Node 20 is deprecated and those actions are being forced onto Node 24: a
      // warning today, a failure whenever the forcing stops. Pinning a major and forgetting it is
      // how a green build becomes a red one without anybody touching it.
      for (final stale in <String>[
        'actions/checkout@v4',
        'actions/upload-artifact@v4',
        'actions/download-artifact@v4',
      ]) {
        expect(workflow.contains(stale), isFalse, reason: '$stale runs on Node 20');
      }
    });

    test('the generated tests are proven current rather than trusted', () {
      expect(workflow, contains('git diff --exit-code test/features'));
    });
  });

  group('the version supersedes the last one', () {
    final script = File('tool/package.sh').readAsStringSync();
    final workflow = File('.github/workflows/build.yml').readAsStringSync();

    test('every build carries a run number, so a repository of snapshots updates', () {
      // A flat version means `apt upgrade` has nothing to do and nobody moves off the build they
      // first installed — in a repository literally called `snapshots`.
      expect(script, contains(r'version="$base~snapshot.$run"'));
      expect(script, contains(r'run="${SNAPSHOT_RUN:-0}"'));
    });

    test('CI passes the run number in', () {
      expect(workflow, contains(r'SNAPSHOT_RUN="${{ github.run_number }}"'));
    });

    test('the ordering is asked of dpkg rather than reasoned about', () {
      // The trap is lexical comparison: if 10 did not beat 9 the scheme would work for nine
      // builds and then quietly stop. The script asks, on the version it actually built.
      expect(script, contains('dpkg --compare-versions'));
      expect(script, contains(r'"$base~snapshot.9" lt "$base~snapshot.10"'));
      expect(script, contains('a flat snapshot never supersedes the last one'));
    });

    test('it matches the shape the backend publishes, so both sort together', () {
      // Separate counters, same shape. Two sets of packages in one repository that sorted by
      // different rules would be a problem nobody could see from either side.
      //
      // `~SNAPSHOT` does appear in the script — in the guard that refuses it — so what is
      // asserted is that the version is never built that way.
      expect(script, contains('~snapshot.'));
      expect(script.contains(r'version="$base~SNAPSHOT"'), isFalse);
    });
  });
}

/// Each job of [workflow] by its id, with the lines that belong to it.
Map<String, String> _jobs(String workflow) {
  final jobs = <String, StringBuffer>{};
  StringBuffer? current;
  var inJobs = false;
  for (final line in workflow.split('\n')) {
    if (line == 'jobs:') {
      inJobs = true;
      continue;
    }
    if (!inJobs) continue;
    final id = RegExp(r'^    ([A-Za-z0-9_-]+):\s*$').firstMatch(line);
    if (id != null) current = jobs[id.group(1)!] = StringBuffer();
    current?.writeln(line);
  }
  return <String, String>{for (final job in jobs.entries) job.key: job.value.toString()};
}
