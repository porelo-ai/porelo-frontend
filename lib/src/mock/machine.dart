import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

import 'mock_daemon.dart';

/// A machine, answered by a [MockDaemon] the way a real one would answer.
///
/// The point is that it **acts on what it is told**, rather than returning a fixed answer to each
/// method. A stand-in that says a task was removed and then goes on listing it makes a working
/// interface look like one where nothing happens — which is exactly how that was found, by hand,
/// after the tests were green.
///
/// Shared by `tool/mock_daemon.dart`, which is what a person opens the interface against, and by
/// the tests that hold this to the behavior the interface is built on. One stand-in with one
/// behavior: two would drift, and a drifted mock is worse than no mock.
class MockMachine {
  /// Puts a machine behind [daemon].
  ///
  /// [situation] is one of the names in [situations]. [pace] is how fast a launch prints — a real
  /// one takes minutes, a person watching wants to see the lines arrive, and a test wants neither.
  MockMachine(
    this.daemon, {
    this.situation = 'work',
    this.pace = const Duration(milliseconds: 400),
    List<({String name, String url, String commit})> followedProjects = const [],
  }) {
    for (final source in followedProjects) {
      _followed[source.name] = {'name': source.name, 'url': source.url, 'commit': source.commit, 'outcome': 'APPLIED'};
    }
    tasks = const {'empty', 'host'}.contains(situation) ? <Map<String, dynamic>>[] : _aMachineWithWorkOnIt();
    if (situation == 'host') _waiting.clear();
    daemon.version = '0.1.0+mock';
    daemon.description =
        '''
interface ${daemon.interfaceName}
type StartStep (step: string, state: string, text: string, waitingOn: string, cause: string)
method Start(task: ?string, project: ?string, agent: ?string, steps: ?bool) -> (
  line: ?string, step: ?StartStep, steps: ?[]StartStep, container: ?string, exitCode: ?int
)
''';
    daemon.method('List', (_) => <String, dynamic>{'tasks': _listing});
    daemon.method(
      'Agents',
      (_) => <String, dynamic>{
        'agents': situation == 'no-agent'
            ? <Map<String, dynamic>>[]
            : <Map<String, dynamic>>[
                <String, dynamic>{
                  'name': 'an-agent',
                  'label': 'An Agent',
                  'binary': '/usr/bin/an-agent',
                  'version': '2.4.0',
                  'from': '/usr/share/porelo/agents/an-agent.yml',
                  'allowedDomains': <String>['api.anthropic.com'],
                  'refusedDomains': <String>['telemetry.example.test'],
                  // What its commits are attributed to, which is what tells somebody looking at
                  // one whether an agent or a person wrote it.
                  'commitsAs': <String, dynamic>{'name': 'An Agent', 'email': 'an-agent@porelo.invalid'},
                  'artifacts': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'url': 'https://example.test/an-agent-2.4.0.tar.gz',
                      'sha256': '3b1f8e2a9c4d5067a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718',
                      'target': '/opt/an-agent',
                      'unverified': false,
                      'reason': '',
                    },
                  ],
                },
                <String, dynamic>{
                  'name': 'other-agent',
                  'label': 'Another Agent',
                  'binary': '/usr/bin/other-agent',
                  'version': '',
                  'from': '/etc/porelo/agents/other-agent.yml',
                  'allowedDomains': <String>['api.example.test'],
                  'refusedDomains': <String>[],
                  // Installed by a Porelo older than the field: absent, which is a state to
                  // render rather than a blank to fill in.
                  // Knowingly unverified, with the reason that makes it a decision rather than
                  // an oversight. The daemon refuses to build one with neither.
                  'artifacts': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'url': 'https://example.test/other-agent-latest.tar.gz',
                      'sha256': '',
                      'target': '/opt/other-agent',
                      'unverified': true,
                      'reason': 'upstream publishes no digest for the rolling build',
                    },
                  ],
                },
              ],
        // One that could not be read. Shown rather than dropped: missing from a list looks
        // exactly like never installed, and only one of those is worth fixing.
        'failures': <String, dynamic>{'broken-agent': 'its manifest could not be parsed'},
        // Installed and never started, because a copy in a more specific directory wins. Nothing
        // else in the product surfaces this, and a packaged agent hidden by a hand-placed copy
        // was found on a real machine the day the field landed.
        'shadowed': <Map<String, dynamic>>[
          <String, dynamic>{
            'path': '/usr/libexec/porelo/agents/an-agent',
            'usedInstead': '/home/somebody/.local/share/porelo/agents/an-agent',
          },
        ],
      },
    );
    // pushes, not stream: Watch never ends, and a held-back stream would deliver every change one
    // change late.
    daemon.pushes('Watch', (_) async* {
      yield <String, dynamic>{'tasks': _listing};
      yield* _changes.stream;
    });
    daemon.stream('Start', _launch, isFinal: (reply) => reply.containsKey('exitCode') || reply.containsKey('action'));
    daemon.method('Stop', _stop);
    // pushes, not stream: a log being followed does not end, and a held-back stream would
    // deliver every line one line late.
    daemon.pushes('Tail', _tail);
    daemon.method('Logs', _logs);
    daemon.method('Projects', _projects);
    daemon.method('Sets', _sets);
    daemon.method('Egress', _egress);
    daemon.method('SetEgress', _setEgress);
    daemon.method('WidenTask', _widenTask);
    daemon.method('Pending', _pending);
    daemon.method('Review', _review);
    daemon.method('Approve', _approve);
    daemon.method('Reject', _reject);
    // Prompts streams and only streams: answering it once would look like it worked and then
    // deliver nothing ever again.
    daemon.pushes('Prompts', (_) async* {
      // Anything raised before anybody was watching is handed over first. A real daemon has the
      // task blocked and waiting either way; without this a test would have to win a race that
      // says nothing about the interface.
      for (final asked in _raisedBeforeAnybodyWatched) {
        yield asked;
      }
      _raisedBeforeAnybodyWatched.clear();
      _watched = true;
      yield* _asking.stream;
    });
    daemon.method('Decide', _decide);
    daemon.method('Remove', _remove);
    daemon.method('Panic', _panic);
    daemon.method('Unfollow', _deleteProject);
    daemon.method('Following', (_) => <String, dynamic>{'projects': _followed.values.toList()});
    daemon.method('Follow', _follow);
    daemon.method('RefreshProjects', _refreshProjects);
    daemon.method('RefreshTask', _refreshTask);
    daemon.method('Doctor', _doctor);
    daemon.method('Providers', _providers);
    daemon.method('ImportCredential', _importCredential);
    // Which node this is. Random per mock instance, so two mocks are two nodes and one mock
    // reached twice is one — which is the thing a client has to be able to tell.
    daemon.method('Node', (_) => <String, dynamic>{'id': _nodeId});
    daemon.method('Backups', _backups);
    daemon.method('WorkHeld', _workHeld);
    daemon.method('DeleteBackup', _deleteBackup);
    daemon.method('RestoreBackup', _restoreBackup);
    daemon.method('SyncUpstream', _syncUpstream);
    daemon.method('NarrowTask', _narrowTask);
    daemon.method('SetClearance', _setClearance);
    daemon.stream('Prepare', _prepare);
    daemon.method('Label', _label);
    daemon.method('HandIn', _handIn);
    daemon.method('TakeBack', _takeBack);
    daemon.method('HandIns', _handIns);
    daemon.method('CanStart', _canStart);
    daemon.method('Credentials', _credentials);
    daemon.method('CredentialDeclare', _credentialDeclare);
    daemon.method('CredentialForget', _credentialForget);
    daemon.method('CredentialCheck', _credentialCheck);
    daemon.method('SshKeys', (_) => <String, dynamic>{'keys': _sshKeys});
    daemon.method('Lock', _lock);
    daemon.method('EnrollDevice', _enrollDevice);
    daemon.method('Keyslots', (_) => <String, dynamic>{'slots': _slotListing});
    daemon.method('RevokeKeyslot', _revokeKeyslot);
    daemon.method('UnlockWithShare', _unlockWithShare);

    switch (situation) {
      case 'no-watch':
        daemon.remove('Watch');
      case 'newer-interface':
        daemon.interfaces = const <String>['org.varlink.service', 'org.fuin.porelo.Tasks1', 'org.fuin.porelo.Tasks2'];
    }
  }

  /// Situations worth opening the interface against, named for the situation rather than for the
  /// requirement that happened to need one.
  static const situations = <String, String>{
    'work': 'two projects, one of them with work stopped',
    'empty': 'a machine nothing has ever run on',
    'host': 'a fresh host with checkout and no earlier work',
    'no-watch': 'a backend too old to have Watch, so nothing arrives by itself',
    'holds-work': 'a task that refuses to be removed because it holds unpushed commits',
    'nothing-knows': 'a task nothing can say anything about, which is refused too',
    'newer-outcome': 'an Outcome value added after this build shipped',
    'newer-interface': 'a backend serving Tasks2 beside the Tasks1 this build understands',
    'failing-start': 'a launch that prints for a while and then comes back non-zero',
    'start-waits': 'a start waiting on a homeserver that can be made to fail',
    'out-of-time': 'an unattended run killed by its own time limit, with its log kept',
    'no-agent': 'a run asked for when no agent is installed, which is a refusal not a failure',
    'helper-survives': 'an emergency stop that leaves a helper running, to be killed by hand',
    'vault-locked': 'a vault nothing can read, so nothing can say what it holds',
    'no-credential': 'a vault with no credential for the provider a run would use',
    'upstream-unreadable': "a repository whose host refuses this machine's key, with no mirror yet",
  };

  /// The daemon answering for this machine.
  final MockDaemon daemon;

  /// Which situation this machine is in.
  final String situation;

  /// How fast a launch prints.
  final Duration pace;

  /// What is on the machine, as it goes over the wire.
  late List<Map<String, dynamic>> tasks;

  final _changes = StreamController<Map<String, dynamic>>.broadcast();
  Completer<void>? _waitingStart;

  /// Fails the dependency of the waiting start, driven by a test or the mock keyboard.
  void failWaitingStart() {
    final waiting = _waitingStart;
    if (waiting != null && !waiting.isCompleted) waiting.complete();
  }

  /// Adds a task and tells every open `Watch` about it.
  void addTask(String name, String project) {
    tasks = <Map<String, dynamic>>[...tasks, _task(name, project)];
    _changes.add(<String, dynamic>{'tasks': _listing});
  }

  /// Stops answering.
  Future<void> close() async {
    failWaitingStart();
    _bound?.cancel();
    await _changes.close();
    await _asking.close();
  }

  /// The logs this machine has.
  ///
  /// A real daemon checks a name against the files that are there and refuses one that is not.
  /// Nothing lists them — which is why the interface has to ask, and why this has to be able to
  /// refuse a name rather than only a method.
  ///
  /// **Two of these are not `.log`, on purpose.** A daemon that served only `.log` files hid
  /// `events.jsonl`, which is what the firewall blocked and therefore the file somebody needs when
  /// a task starts and then does nothing. A mock that serves only `.log` files would let a suffix
  /// rule grow at this end without a single test going red.
  static const logs = <String>{'agent.log', 'gate.log', 'events.jsonl', 'reader.err'};

  final _asking = StreamController<Map<String, dynamic>>.broadcast();
  final _raisedBeforeAnybodyWatched = <Map<String, dynamic>>[];
  bool _watched = false;

  void _raise(Map<String, dynamic> event) {
    if (_watched) {
      _asking.add(event);
    } else {
      _raisedBeforeAnybodyWatched.add(event);
    }
  }

  /// Raises a blocked connection, and gives back the question so it can be answered or expired.
  ///
  /// Driven by whoever is testing, never by a clock — the same rule the automated tests follow.
  Map<String, dynamic> blocks(String destination, {String task = 'porelo-checkout-shell'}) {
    final parts = destination.split(':');
    final asked = <String, dynamic>{
      'task': task,
      'key': 'tcp/$destination',
      'destination': parts.first,
      'protocol': 'tcp',
      'port': int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0,
      'at': DateTime.now().toUtc().toIso8601String(),
      'prefix': 'egress/deny',
      'deadline': DateTime.now().add(const Duration(minutes: 3)).toUtc().toIso8601String(),
    };
    _raise(asked);
    return asked;
  }

  /// Lets a question run out, which is the one case nothing asks about again.
  void expires(Map<String, dynamic> asked) => _raise(<String, dynamic>{
    ...asked,
    'at': DateTime.now().toUtc().toIso8601String(),
    'prefix': '',
    'deadline': '',
    'verdict': 'timeout',
  });

  Map<String, dynamic> _decide(Map<String, dynamic> parameters) {
    // The answer comes back on the same stream, which is also how a client sees the echo of its
    // own decision. It must not be applied twice.
    _raise(<String, dynamic>{
      'task': parameters['task'],
      'key': parameters['key'],
      'destination': parameters['address'],
      'protocol': 'tcp',
      'port': 0,
      'at': DateTime.now().toUtc().toIso8601String(),
      'prefix': '',
      'deadline': '',
      'verdict': parameters['allow'] == true ? 'allow' : 'deny',
    });
    return <String, dynamic>{'ok': true};
  }

  /// What is waiting at the gate, by ref name. Approving or dropping one takes it out.
  ///
  /// **The name is the ref *under* `refs/porelo/incoming/`, never the whole ref** — the contract
  /// says so and `Review`, `Approve` and `Reject` take the short form. This served whole refs
  /// once, which is a fixture describing something the daemon cannot produce.
  ///
  /// `migrate` belongs to a task on this machine and `drop-dead-code` does not, deliberately:
  /// several containers over time share one ref, so a ref whose container is gone is an ordinary
  /// state rather than a broken one.
  final Map<String, Map<String, dynamic>> _waiting = <String, Map<String, dynamic>>{
    'migrate': <String, dynamic>{
      'name': 'migrate',
      'commit': '9a3c1f2',
      'subject': 'Round to the nearest penny, not away from zero',
      'waiting': '4 minutes',
      'at': '2026-09-07T14:12:00Z',
      'fetch':
          'git fetch ssh://porelo@build-01/srv/checkout/.porelo/mirror '
          'refs/porelo/incoming/migrate:refs/remotes/porelo/migrate',
    },
    'drop-dead-code': <String, dynamic>{
      'name': 'drop-dead-code',
      'commit': '7f21b0e',
      'subject': 'Delete the retry loop nothing calls any more',
      'waiting': '26 minutes',
      'at': '2026-09-07T13:50:00Z',
    },
  };

  /// What was forwarded, and onto which branch, so a manual run can see it happened.
  final List<String> forwarded = <String>[];

  /// Which push each branch was forwarded from, and the commit it holds since.
  final Map<String, ({String name, String commit})> _branchHolds = <String, ({String name, String commit})>{};

  Map<String, dynamic> _pending(Map<String, dynamic> parameters) => <String, dynamic>{
    'mirror': '/srv/checkout/.porelo/mirror',
    'mode': 'gatekeeping',
    'seededFrom': '',
    'pending': _waiting.values.toList(),
  };

  Map<String, dynamic> _review(Map<String, dynamic> parameters) {
    final oneFile = parameters['name'] == 'drop-dead-code';
    return <String, dynamic>{
      'diff': oneFile ? _deletionDiff : _changeDiff,
      'log':
          'commit ${oneFile ? '7f21b0e' : '9a3c1f2'}\n'
          'Author: an agent <agent@porelo>\n\n'
          '    ${_waiting[parameters['name']]?['subject'] ?? ''}',
    };
  }

  Map<String, dynamic> _approve(Map<String, dynamic> parameters) {
    final name = '${parameters['name']}';
    final branch = '${parameters['branch']}';
    if (branch.isEmpty) {
      throw const MockRefusal('org.fuin.porelo.Tasks1.BranchRequired');
    }
    // As Porelo does: a branch already holding other work is never overwritten, and nothing is pushed.
    final holder = _branchHolds[branch];
    if (holder != null && holder.name != name) {
      throw MockRefusal('org.fuin.porelo.Tasks1.BranchExists', <String, dynamic>{
        'branch': branch,
        'at': holder.commit,
      });
    }
    _branchHolds[branch] = (name: name, commit: '${_waiting[name]?['commit'] ?? ''}');
    _waiting.remove(name);
    forwarded.add('$name -> $branch');
    return <String, dynamic>{'forwarded': name, 'branch': '${parameters['branch']}'};
  }

  Map<String, dynamic> _reject(Map<String, dynamic> parameters) {
    final name = '${parameters['name']}';
    _waiting.remove(name);
    return <String, dynamic>{'rejected': name, 'told': true};
  }

  /// The sets a project is using, by project file.
  final Set<String> _using = <String>{'dart-packages'};

  /// The sets installed here, scanned rather than fixed.
  static const _installed = <Map<String, dynamic>>[
    <String, dynamic>{
      'name': 'dart-packages',
      'label': 'Dart packages',
      'domains': <String>['pub.dev', 'storage.googleapis.com'],
    },
    <String, dynamic>{
      'name': 'containers',
      'label': 'Container registries',
      'domains': <String>['registry.fedoraproject.org', 'quay.io', 'docker.io'],
    },
    <String, dynamic>{
      'name': 'forges',
      'label': 'Code forges',
      'domains': <String>['github.com', 'gitlab.com'],
    },
  ];

  Map<String, dynamic> _sets(Map<String, dynamic> parameters) => <String, dynamic>{
    'sets': _installed,
    'locations': <String>['/etc/porelo/egress.d', '/usr/share/porelo/egress.d'],
  };

  Map<String, dynamic> _egress(Map<String, dynamic> parameters) => <String, dynamic>{
    // In the order the sources granted them. The first grant wins, so this order is the
    // answer to "where did this host come from" and must not be sorted.
    'hosts': <Map<String, dynamic>>[
      <String, dynamic>{'host': 'api.anthropic.com', 'origin': 'agent an-agent'},
      <String, dynamic>{'host': 'github.com', 'origin': 'upstream'},
      for (final name in _using)
        for (final host in _domainsOf(name)) <String, dynamic>{'host': host, 'origin': 'set $name'},
    ],
    'refused': <String>['telemetry.example.test'],
  };

  Map<String, dynamic> _setEgress(Map<String, dynamic> parameters) {
    final adding = (parameters['addSets'] as List?)?.cast<String>() ?? <String>[];
    final removing = (parameters['removeSets'] as List?)?.cast<String>() ?? <String>[];
    final preview = parameters['dryRun'] == true;

    for (final name in <String>[...adding, ...removing]) {
      if (!_installed.any((set) => set['name'] == name)) {
        return <String, dynamic>{
          'outcome': 'NO_SUCH_SET',
          'opens': <Map<String, dynamic>>[],
          'closes': <Map<String, dynamic>>[],
          'cost': '',
          'detail': '$name is not installed on this machine',
        };
      }
    }

    final opens = <Map<String, dynamic>>[
      for (final name in adding)
        for (final host in _domainsOf(name)) <String, dynamic>{'host': host, 'origin': 'set $name'},
    ];
    final closes = <Map<String, dynamic>>[
      for (final name in removing)
        for (final host in _domainsOf(name)) <String, dynamic>{'host': host, 'origin': 'set $name'},
    ];
    if (!preview) {
      _using
        ..addAll(adding)
        ..removeAll(removing);
    }
    return <String, dynamic>{
      'outcome': preview ? 'PREVIEWED' : 'CHANGED',
      'opens': opens,
      'closes': closes,
      // Filled only when *this* change makes a forge reachable for a guarded project, and never
      // repeated on a later edit.
      'cost': adding.contains('forges')
          ? 'the gate now rests on the container holding no credential rather than on the '
                'host being unreachable'
          : '',
      'detail': '',
    };
  }

  /// Sets or clears the caption a task reads by.
  ///
  /// It acts: the caption really lands on the task, and **nothing about the identity moves** — the
  /// container name, and with it the gate ref and the log files, read exactly as before. A
  /// stand-in that answered `LABELLED` and went on showing the old caption would make a working
  /// interface look like one where nothing happens.
  Map<String, dynamic> _label(Map<String, dynamic> parameters) {
    final name = parameters['task'] as String? ?? '';
    final caption = (parameters['label'] as String? ?? '').trim();
    final task = tasks.firstWhere((each) => each['name'] == name, orElse: () => const <String, dynamic>{});
    if (task.isEmpty) {
      return <String, dynamic>{'outcome': 'NOT_A_TASK', 'label': ''};
    }
    tasks = <Map<String, dynamic>>[
      for (final each in tasks)
        if (each['name'] == name) <String, dynamic>{...each, 'label': caption} else each,
    ];
    _changes.add(<String, dynamic>{'tasks': _listing});
    return <String, dynamic>{'outcome': caption.isEmpty ? 'CLEARED' : 'LABELLED', 'label': caption};
  }

  /// Whether the store is open. Shutting it really does shut it, and the listing goes with it —
  /// a stand-in that answered *shut* and went on listing names would hide the one distinction
  /// this screen exists to draw.
  bool _open = true;

  Map<String, dynamic> _credentials(Map<String, dynamic> parameters) => <String, dynamic>{
    'vault': '/home/somebody/.local/share/porelo/vault.bin',
    'exists': true,
    // Names, kinds and lengths. **Never a value.**
    'credentials': _open || situation == 'vault-locked'
        ? <Map<String, dynamic>>[
            <String, dynamic>{'name': 'a-provider', 'type': 'api-key', 'characters': 108},
          ]
        : <Map<String, dynamic>>[],
    // An unlocked store holding nothing answers true; only a shut one answers false.
    'readable': _open && situation != 'vault-locked',
    // Read with the store shut too: the list holds no secret.
    'connections': _connections.values.toList(),
  };

  /// What this machine is configured to connect out with, by address and purpose.
  final Map<String, Map<String, dynamic>> _connections = <String, Map<String, dynamic>>{
    'ssh://github.com|git': <String, dynamic>{
      'id': 'git.ssh.github.com',
      'kind': 'SSH_KEY',
      'match': 'ssh://github.com',
      'user': '',
      'purpose': 'git',
      'source': 'VAULT',
      'protected': true,
      'present': true,
      'expires': '',
    },
  };

  /// `git@host:path` as `ssh://host/path`, the way the daemon matches it.
  static String _normalised(String address) {
    final scp = RegExp(r'^([^@/]+)@([^:/]+):(.*)$').firstMatch(address);
    return scp == null ? address : 'ssh://${scp.group(2)}/${scp.group(3)}';
  }

  /// Records a connection, replacing one for the same address and purpose. No value arrives here.
  Map<String, dynamic> _credentialDeclare(Map<String, dynamic> parameters) {
    final kind = parameters['kind'] as String? ?? '';
    final match = _normalised(parameters['match'] as String? ?? '');
    final purpose = parameters['purpose'] as String? ?? 'git';
    final source = parameters['source'] as String? ?? 'VAULT';
    final host = Uri.tryParse(match)?.host ?? 'somewhere';
    final id =
        parameters['id'] as String? ??
        (source == 'AGENT' ? '' : '${kind == 'SSH_KEY' ? 'git.ssh' : 'git.token'}.$host');
    final key = '$match|$purpose';
    final replaced = _connections.containsKey(key);
    final connection = <String, dynamic>{
      'id': id,
      'kind': kind,
      'match': match,
      'user': parameters['user'] as String? ?? '',
      'purpose': purpose,
      'source': source,
      'protected': source == 'VAULT',
      'present': source != 'VAULT',
      'expires': '',
    };
    _connections[key] = connection;
    return <String, dynamic>{
      'connection': connection,
      'storeCommand': source == 'VAULT' ? <String>['porelo', 'vault', 'put', id] : <String>[],
      'storeStdin': source == 'VAULT' && kind == 'SSH_KEY' ? 'the private key file' : '',
      'replaced': replaced,
    };
  }

  /// Forgets a record; its value stays where it is, and the answer says where.
  Map<String, dynamic> _credentialForget(Map<String, dynamic> parameters) {
    final match = parameters['match'] as String? ?? '';
    final key = _connections.keys.where((each) => each.startsWith('$match|')).firstOrNull;
    final gone = key == null ? null : _connections.remove(key);
    return <String, dynamic>{
      'forgotten': gone != null,
      'leftBehind': gone == null || gone['source'] == 'AGENT'
          ? ''
          : "the ${(gone['source'] as String).toLowerCase()} entry ${gone['id']}",
    };
  }

  /// The account's ssh keys, in the four shapes Porelo's own listing showed: one it signs
  /// with, one only ssh itself can use, one behind a passphrase, and a public half with no private.
  static const List<Map<String, dynamic>> _sshKeys = <Map<String, dynamic>>[
    <String, dynamic>{
      'path': '/home/somebody/.ssh/id_ed25519',
      'type': 'ssh-ed25519',
      'fingerprint': 'SHA256:q3Xh0mZ7cK2bY9pWfL1eR4tU8vN6sA5dG0jH3iK7oP2',
      'comment': 'somebody@laptop',
      'encrypted': false,
      'privateHalf': true,
      'usable': true,
      'found': 'DIRECTORY',
      'obstacle': '',
    },
    <String, dynamic>{
      'path': '/home/somebody/.ssh/id_rsa',
      'type': 'ssh-rsa',
      'fingerprint': 'SHA256:6y8MQv2Lk9Tn4Rb7Wc1Xd5Ze3Af0Bg8Ch6Di2Ej9Fk4',
      'comment': 'old@thing',
      'encrypted': false,
      'privateHalf': true,
      'usable': false,
      'found': 'DIRECTORY',
      'obstacle':
          'this machine signs with Ed25519 and this is ssh-rsa; it can still be used where '
          'it lies, by ssh itself',
    },
    <String, dynamic>{
      'path': '/srv/keys/id_work',
      'type': 'ssh-ed25519',
      'fingerprint': 'SHA256:5dtfO1pQ8rS3tU6vW9xY2zA5bC8dE1fG4hI7jK0lM3n',
      'comment': 'locked@company',
      'encrypted': true,
      'privateHalf': true,
      'usable': false,
      'found': 'CONFIGURED',
      'obstacle':
          "a passphrase protects it, and nothing here can ask for one. Use it where it lies, "
          "or store a copy without a passphrase: 'ssh-keygen -p -f /srv/keys/id_work'",
    },
    <String, dynamic>{
      'path': '/home/somebody/.ssh/company_key',
      'type': 'ssh-ed25519',
      'fingerprint': 'SHA256:MNa4pQ7rS0tU3vW6xY9zA2bC5dE8fG1hI4jK7lM0nO3',
      'comment': 'company@forge',
      'encrypted': false,
      'privateHalf': false,
      'usable': false,
      'found': 'DIRECTORY',
      'obstacle': 'only the public half is here; the private key is what a machine signs with',
    },
  ];

  /// Which record an address would use, the longest match winning, and whether it would work.
  Map<String, dynamic> _credentialCheck(Map<String, dynamic> parameters) {
    final url = _normalised(parameters['url'] as String? ?? '');
    if (url.startsWith('/') || url.startsWith('file://')) {
      return <String, dynamic>{'outcome': 'NOT_NEEDED', 'detail': 'a local path needs nothing'};
    }
    final candidates = _connections.values.where((each) => url.startsWith(each['match'] as String)).toList()
      ..sort((a, b) => (b['match'] as String).length - (a['match'] as String).length);
    if (candidates.isEmpty) {
      return <String, dynamic>{'outcome': 'NO_CREDENTIAL', 'detail': 'nothing here is set up to reach $url'};
    }
    final connection = candidates.first;
    final vaultShut = connection['source'] == 'VAULT' && !(_open && situation != 'vault-locked');
    return <String, dynamic>{
      'outcome': vaultShut ? 'VAULT_LOCKED' : 'READY',
      'connection': connection,
      'storeCommand': <String>[],
      'storeStdin': '',
      'detail': vaultShut ? 'the vault is shut' : 'it would use ${connection['id']}',
    };
  }

  Map<String, dynamic> _lock(Map<String, dynamic> parameters) {
    final wasOpen = _open;
    _open = false;
    return <String, dynamic>{
      'keyring': true,
      'wasCached': wasOpen,
      // A running task's proxy read the secret at start and holds it where locking cannot reach.
      'holding': tasks.where((task) => task['running'] == true).length,
    };
  }

  /// The vault's keyslots, as Porelo's proposal has them: the recovery passphrase, and every device
  /// enrolled here, each with the share that opens it. **The share is never in a reply.**
  final List<({Map<String, dynamic> slot, String share})> _slots = <({Map<String, dynamic> slot, String share})>[
    (
      slot: <String, dynamic>{
        'id': 'slot-0',
        'name': 'recovery passphrase',
        'storage': '',
        'enrolled': '2026-09-01T10:00:00Z',
        'lastUsed': '',
        'recovery': true,
      },
      share: '',
    ),
  ];

  /// Which slot opened the vault last, the only way the node learns which one is the caller's.
  String _openedBy = '';

  /// Shuts the store again when a bounded unlock runs out, the way the kernel discards the key.
  Timer? _bound;

  List<Map<String, dynamic>> get _slotListing => <Map<String, dynamic>>[
    for (final each in _slots) <String, dynamic>{...each.slot, 'self': each.slot['id'] == _openedBy},
  ];

  Map<String, dynamic> _slotOf(String id) => _slotListing.firstWhere((each) => each['id'] == id);

  Map<String, dynamic> _enrollDevice(Map<String, dynamic> parameters) {
    final name = parameters['name'] as String? ?? '';
    final share = parameters['share'] as String? ?? '';
    const storages = <String>{'USER_SCOPED', 'APPLICATION_SCOPED', 'FIDO2', 'TPM2'};
    Map<String, dynamic> refused(String outcome) => <String, dynamic>{'outcome': outcome, 'detail': ''};
    if (!storages.contains(parameters['storage'])) return refused('UNKNOWN_STORAGE');
    List<int> bytes;
    try {
      bytes = base64.decode(share);
    } on FormatException {
      bytes = const <int>[];
    }
    if (bytes.length != 32) return refused('BAD_SHARE');
    // Enrolling adds a keyslot to an open vault; a shut one has no key to add it with.
    if (!_open || situation == 'vault-locked') return refused('VAULT_LOCKED');
    final known = _slots.where((each) => each.share == share).firstOrNull;
    if (known != null) {
      return <String, dynamic>{
        'outcome': 'ALREADY_ENROLLED',
        'slot': _slotOf(known.slot['id'] as String),
        'detail': '',
      };
    }
    final id = 'slot-${_slots.length}';
    _slots.add((
      slot: <String, dynamic>{
        'id': id,
        'name': name,
        'storage': parameters['storage'],
        'enrolled': DateTime.now().toUtc().toIso8601String(),
        'lastUsed': '',
        'recovery': false,
      },
      share: share,
    ));
    return <String, dynamic>{'outcome': 'ENROLLED', 'slot': _slotOf(id), 'detail': ''};
  }

  Map<String, dynamic> _revokeKeyslot(Map<String, dynamic> parameters) {
    final id = parameters['id'] as String? ?? '';
    String outcome;
    if (!_slots.any((each) => each.slot['id'] == id)) {
      outcome = 'NO_SUCH_SLOT';
    } else if (_slots.length == 1) {
      outcome = 'LAST_WAY_IN';
    } else {
      _slots.removeWhere((each) => each.slot['id'] == id);
      if (_openedBy == id) _openedBy = '';
      outcome = 'REVOKED';
    }
    return <String, dynamic>{'outcome': outcome, 'remaining': _slotListing, 'detail': ''};
  }

  Map<String, dynamic> _unlockWithShare(Map<String, dynamic> parameters) {
    final share = parameters['share'] as String? ?? '';
    final minutes = parameters['minutes'] as int?;
    final opens = _slots.where((each) => each.share.isNotEmpty && each.share == share).firstOrNull;
    if (opens == null) {
      return <String, dynamic>{'outcome': 'SHARE_REJECTED', 'until': '', 'detail': ''};
    }
    final id = opens.slot['id'] as String;
    _openedBy = id;
    opens.slot['lastUsed'] = DateTime.now().toUtc().toIso8601String();
    // A share for a vault that is already open is not refused: it reads the vault again and replaces
    // the bound, so asking for another hour is expressible (measured on the daemon).
    _open = true;
    _bound?.cancel();
    var until = '';
    if (minutes != null) {
      final end = DateTime.now().toUtc().add(Duration(minutes: minutes));
      until = end.toIso8601String();
      _bound = Timer(Duration(minutes: minutes), () => _open = false);
    }
    return <String, dynamic>{'outcome': 'UNLOCKED', 'until': until, 'slot': _slotOf(id), 'detail': ''};
  }

  /// Whether work can start, answered before anything is created.
  ///
  /// It acts on the situation rather than answering canned: the three outcomes that mean
  /// different actions are each reachable, and `credential` names the key that was looked for
  /// rather than the one that ought to apply.
  Map<String, dynamic> _canStart(Map<String, dynamic> parameters) {
    final agent = parameters['agent'] as String? ?? '';
    if (situation == 'no-agent') {
      return _readiness('NO_AGENT', detail: 'nothing is installed here to run work with');
    }
    if (situation == 'vault-locked' || !_open) {
      return _readiness('VAULT_LOCKED', agent: agent, detail: 'the vault is locked, so nothing can say what it holds');
    }
    if (situation == 'no-credential') {
      return _readiness(
        'CREDENTIAL_MISSING',
        agent: agent,
        provider: 'a-provider',
        // The provider's name, which is what is actually looked up — an older vault answers
        // under the agent's own name, and naming the wrong one reports a key missing from a
        // vault that has it.
        credential: 'a-provider',
        detail: "the vault holds no credential for 'a-provider'",
      );
    }
    if (situation == 'upstream-unreadable') {
      return _readiness('UPSTREAM_KEY_REFUSED', agent: agent, detail: '$_refusedKey Run: $_keyFix');
    }
    if (agent == 'other-agent') {
      return _readiness(
        'NO_PROVIDER_CHOSEN',
        agent: agent,
        detail: 'names no default provider, so one has to be chosen',
      );
    }
    return _readiness(
      'READY',
      ready: true,
      agent: agent.isEmpty ? 'an-agent' : agent,
      provider: 'a-provider',
      credential: 'a-provider',
    );
  }

  /// What Porelo says it tried when the upstream refused, and the command that fixes it.
  static const _refusedKey = "git@github.com refused the deploy key 'checkout-deploy' from the vault.";
  static const _keyFix = 'porelo project key checkout';

  static Map<String, dynamic> _readiness(
    String outcome, {
    bool ready = false,
    String agent = '',
    String provider = '',
    String credential = '',
    String detail = '',
  }) => <String, dynamic>{
    'ready': ready,
    'outcome': outcome,
    'agent': agent,
    'provider': provider,
    'credential': credential,
    'detail': detail,
  };

  /// Removes what Porelo built for a project, or says what it would remove.
  ///
  /// **It refuses rather than decides**, on the same two things the daemon does: a ref nobody has
  /// reviewed, and a task that is up. `keeps` names the operator's own file so a confirmation can
  /// say it survives without this end having to know which things are Porelo's.
  Map<String, dynamic> _deleteProject(Map<String, dynamic> parameters) {
    final name = parameters['name'] as String? ?? '';
    final preview = parameters['dryRun'] == true;
    final force = parameters['force'] == true;
    final its = tasks.where((task) => task['project'] == name).toList();

    final known = (_projects(const <String, dynamic>{})['projects']! as List).whereType<Map<String, dynamic>>().any(
      (project) => project['name'] == name,
    );
    if (!known) {
      return <String, dynamic>{
        'outcome': 'NO_SUCH_PROJECT',
        'removes': <Map<String, dynamic>>[],
        'keeps': <String>[],
        'unreviewed': <String>[],
        'running': <String>[],
        'detail': 'nothing here knows that project',
      };
    }

    // What a person recognizes, in the order somebody would think of them.
    final removes = <Map<String, dynamic>>[
      <String, dynamic>{'kind': 'MIRROR', 'what': '/srv/$name/.porelo/mirror'},
      <String, dynamic>{'kind': 'IMAGE', 'what': 'porelo/$name:latest'},
      <String, dynamic>{'kind': 'BUILD', 'what': '/srv/$name/.porelo/build'},
      <String, dynamic>{'kind': 'REGISTRY', 'what': name},
      for (final task in its) <String, dynamic>{'kind': 'TASK', 'what': task['name']},
    ];
    // The gate is the checkout project's, so only that one can hold unreviewed work here.
    final unreviewed = name == 'checkout' ? _waiting.keys.toList() : <String>[];
    final running = <String>[
      for (final task in its)
        if (task['running'] == true) task['name'] as String,
    ];

    String outcome;
    if (preview) {
      outcome = 'PREVIEWED';
    } else if (!force && unreviewed.isNotEmpty) {
      outcome = 'HOLDS_WORK';
    } else if (!force && running.isNotEmpty) {
      outcome = 'TASKS_RUNNING';
    } else {
      outcome = 'DELETED';
      tasks = <Map<String, dynamic>>[
        for (final task in tasks)
          if (task['project'] != name) task,
      ];
      // Gone from the listing as well as from the task list: a project still on screen after it
      // was removed is the one reading that would send somebody looking for what is left of it.
      _removedProjects.add(name);
      _changes.add(<String, dynamic>{'tasks': _listing});
    }

    return <String, dynamic>{
      'outcome': outcome,
      'removes': removes,
      // Named by the contract, because a client cannot know which things are Porelo's — and one
      // that guessed would sooner or later name the operator's own file among the casualties.
      'keeps': <String>['/srv/$name/project.yml'],
      'unreviewed': unreviewed,
      'running': running,
      'detail': outcome == 'HOLDS_WORK' || outcome == 'TASKS_RUNNING' ? 'nothing was removed' : '',
    };
  }

  /// Stops every running task at once, and never removes anything.
  ///
  /// It acts: the tasks really do stop being listed as running, and `Start` brings them back —
  /// a stand-in that answered *stopped* and went on listing them as up is how a working interface
  /// looks like one where nothing happens.
  Map<String, dynamic> _panic(Map<String, dynamic> parameters) {
    final preview = parameters['dryRun'] == true;
    final stopping = tasks.where((task) => task['running'] == true).toList();

    if (!preview) {
      tasks = <Map<String, dynamic>>[
        for (final task in tasks)
          if (task['running'] != true)
            task
          else
            <String, dynamic>{
              ...task,
              'running': false,
              // Stopped, not removed: the state directory, the workspace and the logs are all
              // still there, which is what makes Start bring it back.
              'state': 'Exited (143) 0 seconds ago',
              'activity': 'DEAD',
              'helpers': 0,
            },
      ];
      _changes.add(<String, dynamic>{'tasks': _listing});
    }

    return <String, dynamic>{
      'tasks': <Map<String, dynamic>>[
        for (final task in stopping)
          <String, dynamic>{
            'name': task['name'],
            'helpers': task['helpers'],
            // A dry run attempts nothing, so nothing can have survived it — which is not the
            // same as nothing surviving, and must never be drawn as though it were.
            'surviving': situation == 'helper-survives' && !preview && task['name'] == 'porelo-checkout-shell'
                ? <String>['porelo-checkout-shell-gate (pid 4711)']
                : <String>[],
          },
      ],
      // A helper that outlived its stop. Named rather than counted, because somebody has to kill
      // it by hand — and a machine where this is empty proves nothing about one where it is not.
      'surviving': situation == 'helper-survives' && !preview
          ? <String>['porelo-checkout-shell-gate (pid 4711)']
          : <String>[],
      'previewed': preview,
    };
  }

  /// What each running task has been let reach beyond what its project declares.
  ///
  /// Kept, because the point of this stand-in is to act: a second call asking for the same name
  /// must answer `NO_CHANGE`, and a widened task must go on being widened.
  final Map<String, Set<String>> _granted = <String, Set<String>>{};

  /// Repositories this mock has been asked to follow, by project name, with what came of it.
  final Map<String, Map<String, dynamic>> _followed = <String, Map<String, dynamic>>{};

  /// Follows a repository and takes it at once, as Porelo does — so the project can be worked in
  /// straight after. A URL saying `unsigned` is refused as `NOT_SIGNED`, which needs a person; the
  /// same name at another address is refused, because that is a different project wearing a name.
  /// Fetches now, as Porelo does: the records as they are afterwards, and `NoSuchProject` for a name
  /// this account does not follow. A commit already in force comes back `UNCHANGED`.
  Map<String, dynamic> _refreshProjects(Map<String, dynamic> parameters) {
    final name = parameters['project'] as String?;
    if (name != null && !_followed.containsKey(name)) {
      throw MockRefusal('org.fuin.porelo.Tasks1.NoSuchProject', <String, dynamic>{'project': name});
    }
    final now = DateTime.now().toUtc().toIso8601String();
    return <String, dynamic>{
      'projects': <Map<String, dynamic>>[
        for (final each in _followed.entries)
          if (name == null || each.key == name)
            _followed[each.key] = <String, dynamic>{
              ...each.value,
              'at': now,
              if ((each.value['commit'] as String? ?? '').isNotEmpty) 'outcome': 'UNCHANGED',
            },
      ],
    };
  }

  Map<String, dynamic> _follow(Map<String, dynamic> parameters) {
    final name = parameters['name'] as String? ?? '';
    final url = parameters['url'] as String? ?? '';
    final unverified = parameters['unverified'] == true;
    if (unverified && (parameters['signedBy'] as String? ?? '').isNotEmpty) {
      throw const MockRefusal('org.fuin.porelo.Tasks1.Failed', <String, dynamic>{
        'message': 'signedBy and unverified are two different instructions; give one',
      });
    }
    final before = _followed[name];
    if (before != null && before['url'] != url) {
      throw MockRefusal('org.fuin.porelo.Tasks1.Failed', <String, dynamic>{
        'message': '$name is already followed at ${before['url']}',
      });
    }
    final refused = url.contains('unsigned');
    final state = <String, dynamic>{
      'name': name,
      'url': url,
      'commit': refused ? '' : 'c0ffee1d2e3f',
      'at': DateTime.now().toUtc().toIso8601String(),
      'outcome': refused ? 'NOT_SIGNED' : 'APPLIED',
      'refused': refused ? 'badc0de4f5a6' : '',
      'signer': '',
      'detail': refused ? 'the fetched commit carries no signature' : '',
      'needsAPerson': refused,
      'unverified': unverified,
    };
    _followed[name] = state;
    _removedProjects.remove(name);
    return state;
  }

  /// Takes names back from a running task.
  ///
  /// **It stops new connections and not the ones already running** — the ruleset accepts
  /// established traffic without consulting the set again. Nothing here models that, because
  /// nothing here has traffic; the interface says it, and this is where the wording is checked
  /// against a real reply.
  Map<String, dynamic> _narrowTask(Map<String, dynamic> parameters) {
    final name = parameters['task'] as String? ?? '';
    final asked = (parameters['domains'] as List?)?.cast<String>() ?? <String>[];
    final scope = _scope(parameters);
    final preview = parameters['dryRun'] == true;

    final task = tasks.firstWhere((each) => each['name'] == name, orElse: () => const <String, dynamic>{});
    if (task.isEmpty || task['running'] != true) {
      return _narrowed('NOT_RUNNING', detail: 'there is no running container called $name');
    }

    // Anything not granted to this run is ignored rather than an error.
    final already = _granted[name] ?? const <String>{};
    final closes = <String>[
      for (final host in asked)
        if (already.contains(host)) host,
    ];
    if (closes.isEmpty) {
      return _narrowed('NO_CHANGE', detail: 'none of those is granted to this run');
    }
    if (preview) {
      return _narrowed('PREVIEWED', closes: closes, addresses: closes.length * 2);
    }

    _granted[name]?.removeAll(closes);

    final file = _fileOf(task['project'] as String? ?? '');
    if (scope == 'RUN_AND_PROJECT' && file.isEmpty) {
      return _narrowed(
        'NO_PROJECT_FILE',
        closes: closes,
        addresses: closes.length * 2,
        detail: 'taken back from the run; no project file is recorded, so nothing was written',
      );
    }
    return _narrowed('NARROWED', closes: closes, addresses: closes.length * 2, persisted: scope == 'RUN_AND_PROJECT');
  }

  static Map<String, dynamic> _narrowed(
    String outcome, {
    List<String> closes = const <String>[],
    int addresses = 0,
    bool persisted = false,
    String detail = '',
  }) => <String, dynamic>{
    'outcome': outcome,
    'closes': closes,
    'addresses': addresses,
    'persisted': persisted,
    'detail': detail,
  };

  /// Turns enforcement on or off on a task that is already running.
  ///
  /// **It opens nothing.** The ruleset stays loaded whichever mode is chosen; what changes is
  /// whether a blocked connection produces a question.
  Map<String, dynamic> _setClearance(Map<String, dynamic> parameters) {
    final name = parameters['task'] as String? ?? '';
    final mode = parameters['mode'] as String? ?? '';
    final preview = parameters['dryRun'] == true;

    if (!const <String>['prompt', 'allow', 'deny', 'off'].contains(mode)) {
      return _clearance('UNKNOWN_MODE', detail: '"$mode" is not a mode this machine knows');
    }
    final at = tasks.indexWhere((each) => each['name'] == name);
    if (at < 0) {
      return _clearance('NO_SUCH_TASK', detail: 'nothing here knows $name');
    }
    if (tasks[at]['running'] != true) {
      return _clearance('NOT_RUNNING', detail: '$name is not up');
    }

    final was = tasks[at]['clearance'] as String? ?? '';
    // Not a failure: it was already in that mode and nothing was restarted.
    if (was == mode) return _clearance('UNCHANGED', was: was);
    if (preview) return _clearance('PREVIEWED', was: was, now: mode);

    tasks[at] = <String, dynamic>{...tasks[at], 'clearance': mode};
    _changes.add(<String, dynamic>{'tasks': _listing});
    return _clearance('CHANGED', was: was, now: mode);
  }

  static Map<String, dynamic> _clearance(String outcome, {String was = '', String now = '', String detail = ''}) =>
      <String, dynamic>{
        'outcome': outcome,
        'was': was,
        // Empty when nothing changed, exactly as the contract says.
        'now': now,
        'detail': detail,
      };

  /// The scope of a widening or a narrowing, as the contract spells it.
  ///
  /// No default, and the daemon will not invent one: this run and this project are different
  /// intentions and choosing between them is not the daemon's to do. **Any other spelling is
  /// refused**, as varlink refuses a value outside an enum — accepting it let `NarrowTask` go out
  /// as `runAndProject` and be read as run-only.
  static String _scope(Map<String, dynamic> parameters) {
    final scope = parameters['scope'] as String? ?? '';
    if (scope.isEmpty) {
      throw const MockRefusal('org.fuin.porelo.Tasks1.ScopeRequired');
    }
    if (scope != 'RUN' && scope != 'RUN_AND_PROJECT') {
      throw const MockRefusal('org.varlink.service.InvalidParameter', <String, dynamic>{'parameter': 'scope'});
    }
    return scope;
  }

  Map<String, dynamic> _widenTask(Map<String, dynamic> parameters) {
    final name = parameters['task'] as String? ?? '';
    final asked = (parameters['domains'] as List?)?.cast<String>() ?? <String>[];
    final scope = _scope(parameters);
    final preview = parameters['dryRun'] == true;

    final task = tasks.firstWhere((each) => each['name'] == name, orElse: () => const <String, dynamic>{});
    if (task.isEmpty || task['running'] != true) {
      return _widened('NOT_RUNNING', detail: 'there is no running container called $name');
    }
    if (task['securityClass'] == 'offline') {
      return _widened('REFUSED_BY_CLASS', detail: "an offline project's tasks reach nothing");
    }

    // In the order asked for, and only what it does not have already.
    final already = _granted[name] ?? const <String>{};
    final opens = <String>[
      for (final host in asked)
        if (!already.contains(host)) host,
    ];
    if (opens.isEmpty) {
      return _widened('NO_CHANGE', detail: 'it can reach all of that already');
    }
    if (preview) return _widened('PREVIEWED', opens: opens);

    _granted.putIfAbsent(name, () => <String>{}).addAll(opens);

    // The run was widened either way. Whether the file was written is the other half, and a
    // project whose file has moved is the case where the two answers differ.
    final file = _fileOf(task['project'] as String? ?? '');
    if (scope == 'RUN_AND_PROJECT' && file.isEmpty) {
      return _widened(
        'NO_PROJECT_FILE',
        opens: opens,
        detail: 'the run can reach it; no project file is recorded, so nothing was written',
      );
    }
    return _widened('WIDENED', opens: opens, persisted: scope == 'RUN_AND_PROJECT');
  }

  static Map<String, dynamic> _widened(
    String outcome, {
    List<String> opens = const <String>[],
    bool persisted = false,
    String detail = '',
  }) => <String, dynamic>{'outcome': outcome, 'opens': opens, 'persisted': persisted, 'detail': detail};

  String _fileOf(String project) {
    final projects = (_projects(const <String, dynamic>{})['projects']! as List<Map<String, dynamic>>);
    return projects.firstWhere(
              (each) => each['name'] == project,
              orElse: () => const <String, dynamic>{'file': ''},
            )['file']
            as String? ??
        '';
  }

  static List<String> _domainsOf(String name) => <String>[
    ...(_installed.firstWhere(
          (set) => set['name'] == name,
          orElse: () => const <String, dynamic>{'domains': <String>[]},
        )['domains']
        as List<String>),
  ];

  /// Whether this machine can run a task.
  ///
  /// **One `DEGRADED` and the rest fine**, because a report that is all green proves nothing about
  /// the screen that has to tell three states apart — and degraded is the one that leaves a
  /// machine running while being worth knowing about.
  Map<String, dynamic> _doctor(Map<String, dynamic> parameters) => <String, dynamic>{
    'probes': <Map<String, dynamic>>[
      _probe('podman', 'OK', '5.2.1', ''),
      _probe('hook registration', 'OK', 'registered for this user', ''),
      _probe(
        'rootless network backend',
        'DEGRADED',
        'slirp4netns rather than pasta: the git gate binds every interface and is '
            'reachable from this machine\u0027s network',
        'install pasta (passt) and restart the daemon',
      ),
      _probe('dnsmasq nftset', 'OK', 'built with nftset support', ''),
      _probe('nft', 'OK', 'v1.0.9', ''),
      _probe('git', 'OK', '2.45.2', ''),
      _probe('nsenter', 'OK', 'util-linux 2.40', ''),
      _probe('SELinux policy', 'OK', 'loaded', ''),
      _probe('keyring', 'OK', 'libkeyutils present', ''),
    ],
    // DEGRADED leaves it ready: the machine runs tasks, and the report says how well.
    'ready': true,
  };

  static Map<String, dynamic> _probe(String name, String state, String detail, String action) => <String, dynamic>{
    'name': name,
    'state': state,
    'detail': detail,
    'action': action,
  };

  /// Which providers this machine has.
  Map<String, dynamic> _providers(Map<String, dynamic> parameters) => <String, dynamic>{
    'providers': <Map<String, dynamic>>[
      <String, dynamic>{
        'name': 'a-provider',
        'label': 'A Provider',
        'upstream': 'api.anthropic.com',
        'dialects': <String>['api-key', 'oauth'],
        'authenticated': true,
        'credentialType': 'api-key',
        'credentialName': 'a-provider',
        'storeCommand': 'porelo vault put a-provider',
      },
      // Stored under the *agent's* name, which is the fallback a client could never work out
      // by intersecting two lists.
      <String, dynamic>{
        'name': 'other-provider',
        'label': 'Another Provider',
        'upstream': 'api.other.test',
        'dialects': <String>['oauth'],
        'authenticated': false,
        'credentialType': '',
        'credentialName': 'an-agent',
        'storeCommand': 'porelo vault put an-agent --type oauth',
      },
    ],
    'readable': true,
  };

  /// Imports a credential an agent already holds here.
  Map<String, dynamic> _importCredential(Map<String, dynamic> parameters) {
    final agent = parameters['agent'] as String?;
    // An empty name matches nothing, and omitting it means "the only one installed". Two
    // different things, kept apart here as they are on the daemon.
    if (agent != null && agent != 'an-agent') {
      return <String, dynamic>{
        'outcome': 'NO_SUCH_AGENT',
        'name': '',
        'type': '',
        'length': 0,
        'source': '',
        'detail': 'no agent called \u0027$agent\u0027 is installed here',
      };
    }
    return <String, dynamic>{
      'outcome': 'IMPORTED',
      'name': 'an-agent',
      'type': 'api-key',
      'length': 51,
      'source': '/home/somebody/.config/an-agent/credentials.json',
      'detail': '',
    };
  }

  /// What has been backed up, by project. **A record rather than a listing of files**: a bundle
  /// is written wherever an operator names it, so nothing could work this out afterwards.
  final Map<String, List<Map<String, dynamic>>> _backupRecords = <String, List<Map<String, dynamic>>>{
    'checkout': <Map<String, dynamic>>[
      <String, dynamic>{
        'taken': DateTime.now().toUtc().subtract(const Duration(hours: 3)).toIso8601String(),
        'bundle': '/srv/checkout/backups/before-sync.bundle',
        'refs': 2,
        'present': true,
        'bytes': 4823 * 1024,
      },
      // A bundle somebody moved. Listed, because it was taken — dropping it would say the backup
      // was never made, which is a different and worse statement.
      <String, dynamic>{
        'taken': DateTime.now().toUtc().subtract(const Duration(days: 2)).toIso8601String(),
        'bundle': '/srv/checkout/backups/last-week.bundle',
        'refs': 5,
        'present': false,
        'bytes': 0,
      },
    ],
  };

  /// What a task holds that never reached the gate.
  ///
  /// **Three answers, and the mock has to be able to give all three** — *holds nothing*, *holds
  /// this much*, and *nobody could look* — because a fake that only ever succeeded would prove
  /// none of what the screen is careful about.
  Map<String, dynamic> _workHeld(Map<String, dynamic> parameters) {
    final name = parameters['task'] as String? ?? '';
    final task = tasks.firstWhere((each) => each['name'] == name, orElse: () => const <String, dynamic>{});
    // A name that is no task at all is a refusal, never an unreadable answer: those are different
    // failures, and merging them makes a wrong argument arrive as a legitimate reading.
    if (task.isEmpty) throw MockRefusal('org.fuin.porelo.Tasks1.NoSuchTask');

    if (task['running'] == true) {
      // Current, so no instant: "holds" rather than "held".
      return <String, dynamic>{
        'readable': true,
        'changedFiles': name.endsWith('-shell') ? 3 : 0,
        'unpushedCommits': name.endsWith('-shell') ? 2 : 0,
      };
    }
    if (name == 'porelo-checkout-tests') {
      // Killed, or stopped by a Porelo that left no note. Not "nothing".
      return <String, dynamic>{'readable': false, 'changedFiles': 0, 'unpushedCommits': 0};
    }
    // Stopped with a note: what was true then, and when.
    return <String, dynamic>{
      'readable': true,
      'changedFiles': 0,
      'unpushedCommits': 4,
      'asOf': DateTime.now().toUtc().subtract(const Duration(minutes: 40)).toIso8601String(),
    };
  }

  Map<String, dynamic> _backups(Map<String, dynamic> parameters) => <String, dynamic>{
    // Newest first, and empty is ordinary: a project nobody has backed up.
    'backups': _backupRecords[parameters['project']] ?? <Map<String, dynamic>>[],
  };

  Map<String, dynamic> _deleteBackup(Map<String, dynamic> parameters) {
    final project = parameters['project'] as String? ?? '';
    final bundle = parameters['bundle'] as String? ?? '';
    final preview = parameters['dryRun'] == true;
    final records = _backupRecords[project] ?? <Map<String, dynamic>>[];
    final known = records.where((each) => each['bundle'] == bundle);
    if (known.isEmpty) {
      // Refused rather than obeyed: otherwise this is a file-deletion primitive wearing a
      // backup's name, reachable by anything that can open the socket.
      return <String, dynamic>{
        'outcome': 'NO_SUCH_BACKUP',
        'fileRemoved': false,
        'refs': 0,
        'detail': 'no record names that path',
      };
    }
    final record = known.first;
    if (!preview) {
      _backupRecords[project] = records.where((each) => each['bundle'] != bundle).toList();
    }
    return <String, dynamic>{
      'outcome': preview ? 'PREVIEWED' : 'DELETED',
      // False with DELETED means the record was cleared for a bundle somebody had already
      // moved — a tidy-up, not a loss.
      'fileRemoved': record['present'] == true,
      'refs': record['refs'],
      'detail': '',
    };
  }

  Map<String, dynamic> _restoreBackup(Map<String, dynamic> parameters) {
    final project = parameters['project'] as String? ?? '';
    final bundle = parameters['bundle'] as String? ?? '';
    final preview = parameters['dryRun'] == true;
    final force = parameters['force'] == true;
    final records = _backupRecords[project] ?? <Map<String, dynamic>>[];
    if (!records.any((each) => each['bundle'] == bundle)) {
      return <String, dynamic>{
        'outcome': 'NO_SUCH_BACKUP',
        'mirror': '',
        'unreviewed': <String>[],
        'detail': 'no record names that path',
      };
    }
    // The checkout gate holds unreviewed work, so restoring over it destroys the only copy
    // there has ever been. That is the refusal worth having.
    final unreviewed = project == 'checkout' ? _waiting.keys.toList() : <String>[];
    final refused = unreviewed.isNotEmpty && !preview && !force;
    return <String, dynamic>{
      'outcome': preview
          ? 'PREVIEWED'
          : refused
          ? 'HOLDS_WORK'
          : 'RESTORED',
      'mirror': '/srv/$project/.porelo/mirror',
      // Filled under force too: it is what force destroyed, and that belongs in the record
      // afterwards rather than only in the warning.
      'unreviewed': unreviewed,
      'detail': '',
    };
  }

  Map<String, dynamic> _syncUpstream(Map<String, dynamic> parameters) {
    final project = parameters['project'] as String? ?? '';
    if (project == 'billing') {
      // Offline: nothing was tried, and zero would read as up to date.
      return <String, dynamic>{
        'outcome': 'MEASURED',
        'behind': 0,
        'measured': false,
        'reason': 'OFFLINE',
        'detail': '',
      };
    }
    if (project == 'never-run') {
      return <String, dynamic>{
        'outcome': 'NO_MIRROR',
        'behind': 0,
        'measured': false,
        'reason': 'NEVER_CHECKED',
        'detail': '',
      };
    }
    return <String, dynamic>{'outcome': 'MEASURED', 'behind': 3, 'measured': true, 'reason': 'MEASURED', 'detail': ''};
  }

  /// What this mock answers when asked which node it is.
  final String _nodeId = 'mock-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}';

  /// Projects removed by `Unfollow`, which stop being listed.
  final Set<String> _removedProjects = <String>{};

  /// Every project on the machine, assembled the way the daemon assembles it.
  ///
  /// `never-run` is here on purpose: a project with no tasks, which a client deriving projects
  /// from the task list could never show. `no-file` is the other state worth having — listed, and
  /// nothing can act on it.
  Map<String, dynamic> _projects(Map<String, dynamic> parameters) => <String, dynamic>{
    'projects': <Map<String, dynamic>>[
      for (final project in _listedProjects)
        if (!_removedProjects.contains(project['name'])) project,
      // What was followed here and taken is a project, with its follow state on it.
      for (final MapEntry(key: name, value: state) in _followed.entries)
        if (!_removedProjects.contains(name) && !_listedProjects.any((each) => each['name'] == name))
          <String, dynamic>{
            'name': name,
            'securityClass': 'guarded',
            'file': (state['commit'] as String).isEmpty ? '' : '/srv/$name/project.yml',
            'mirror': '/srv/$name/.porelo/mirror',
            'pending': 0,
            'tasks': 0,
            'running': 0,
            'repositories': <Map<String, dynamic>>[
              <String, dynamic>{'name': name, 'own': true, 'upstream': state['url']},
            ],
            'following': state,
          },
    ],
  };

  List<Map<String, dynamic>> get _listedProjects => situation == 'host' ? _hostProjects : _everyProject;

  List<Map<String, dynamic>> get _hostProjects => <Map<String, dynamic>>[
    <String, dynamic>{
      'name': 'checkout',
      'securityClass': 'guarded',
      'file': '/srv/checkout/project.yml',
      'mirror': '',
      'prepared': false,
      'preparedState': 'ABSENT',
      'behind': 0,
      'behindMeasured': '',
      'behindReason': 'NEVER_CHECKED',
      'behindDetail': '',
      'pending': _waiting.length,
      'tasks': tasks.length,
      'running': tasks.where((task) => task['running'] == true).length,
    },
  ];

  List<Map<String, dynamic>> get _everyProject => <Map<String, dynamic>>[
    <String, dynamic>{
      'name': 'checkout',
      'securityClass': 'guarded',
      'file': '/srv/checkout/project.yml',
      'mirror': '/srv/checkout/.porelo/mirror',
      'messages': <String, dynamic>{
        'transport': 'matrix',
        'conversation': '!checkout:localhost',
        'reaches': <String>['127.0.0.1:8008'],
        'ready': true,
        'detail': '',
        'loopbackOnly': false,
        'waits': situation == 'vault-locked' ? 'The vault is locked; messages cannot move until it is unlocked.' : '',
        'waitsOn': situation == 'vault-locked' ? 'vault' : '',
      },
      'prepared': true,
      'preparedState': 'READY',
      'behind': 3,
      'behindMeasured': DateTime.now().toUtc().subtract(const Duration(minutes: 20)).toIso8601String(),
      'behindReason': 'MEASURED',
      'behindDetail': '',
      'pending': _waiting.length,
      'tasks': tasks.where((task) => task['project'] == 'checkout').length,
      'running': tasks.where((task) => task['project'] == 'checkout' && task['running'] == true).length,
    },
    <String, dynamic>{
      'name': 'billing',
      'securityClass': 'offline',
      'file': '/srv/billing/project.yml',
      'mirror': '',
      'prepared': true,
      'preparedState': 'STALE',
      'behind': 0,
      'behindMeasured': '',
      // An offline project reaches nothing, so nothing was tried. Distinct from zero.
      'behindReason': 'OFFLINE',
      'behindDetail': '',
      'pending': 0,
      'tasks': tasks.where((task) => task['project'] == 'billing').length,
      'running': tasks.where((task) => task['project'] == 'billing' && task['running'] == true).length,
    },
    <String, dynamic>{
      'name': 'never-run',
      'securityClass': '',
      'file': '/srv/never-run/project.yml',
      'mirror': '',
      // Nothing has run here, so no image was ever built.
      'prepared': false,
      'preparedState': 'ABSENT',
      'behind': 0,
      'behindMeasured': '',
      'behindReason': 'NEVER_CHECKED',
      'behindDetail': '',
      'pending': 0,
      'tasks': 0,
      'running': 0,
    },
    <String, dynamic>{
      'name': 'moved-away',
      'securityClass': 'guarded',
      'file': '',
      'mirror': '/srv/moved/.porelo/mirror',
      'prepared': true,
      'preparedState': 'UNKNOWN',
      'behind': 0,
      'behindMeasured': DateTime.now().toUtc().subtract(const Duration(hours: 3)).toIso8601String(),
      'behindReason': 'FAILED',
      'behindDetail': 'the upstream refused the connection',
      'pending': 1,
      'tasks': tasks.where((task) => task['project'] == 'moved-away').length,
      'running': tasks.where((task) => task['project'] == 'moved-away' && task['running'] == true).length,
    },
  ];

  /// Which logs a task has. A task that was purged has none, and that is a normal answer.
  Map<String, dynamic> _logs(Map<String, dynamic> parameters) => <String, dynamic>{
    'logs': <Map<String, dynamic>>[
      for (final name in logs)
        <String, dynamic>{
          'name': name,
          'bytes': _sizes[name] ?? 182_311,
          'at': '2026-09-07T14:12:00Z',
          // Absent for the two whose names say what they are, which is the case the interface
          // has to render as nothing rather than as a blank line.
          if (_what[name] != null) 'what': _what[name],
        },
    ],
  };

  /// What each file holds, for the ones whose names do not say.
  ///
  /// **The daemon's sentence, not this end's.** It is here because the mock stands in for the
  /// daemon; the interface composes none of it and shows nothing where there is nothing.
  static const _what = <String, String>{
    'events.jsonl':
        'What the firewall blocked. Read this when a task starts and then does '
        'nothing.',
    'reader.err':
        'Standard error of the reader hook, which writes events.jsonl. Empty is normal; '
        'anything here means the record of blocks may be incomplete.',
  };

  static const _sizes = <String, int>{'gate.log': 4096, 'events.jsonl': 9_212, 'reader.err': 0};

  Stream<Map<String, dynamic>> _tail(Map<String, dynamic> parameters) async* {
    final log = parameters['log'];
    if (!logs.contains(log)) {
      throw MockRefusal('org.fuin.porelo.Tasks1.NoSuchLog', <String, dynamic>{'task': parameters['task'], 'log': log});
    }
    const red = '\u001B[31m';
    const green = '\u001B[32m';
    const plain = '\u001B[0m';
    final lines = switch (log) {
      'gate.log' => <String>[
        'gate: mirror at refs/porelo/incoming',
        'gate: waiting for a decision',
        '${green}gate: 2 commits accepted$plain',
      ],
      // What the firewall blocked. Not a line format this end may parse — it is shown as written,
      // like every other log.
      'events.jsonl' => <String>[
        '{"at":"2026-09-07T14:11:58Z","action":"deny","host":"registry.example.com:443"}',
        '{"at":"2026-09-07T14:12:01Z","action":"allow","host":"github.com:443"}',
      ],
      // The reader hook's standard error. Empty is the normal case, which is why the listing
      // gives it zero bytes: anything in it means the record of blocks may be incomplete.
      'reader.err' => <String>['reader: NFLOG group 5 already bound, 3 events may be missing'],
      _ => <String>[
        'agent: reading the prompt',
        'agent: running the tests',
        '${red}agent: 1 test failed$plain',
        'agent: waiting',
      ],
    };
    for (final line in lines) {
      if (pace > Duration.zero) await Future<void>.delayed(pace);
      yield <String, dynamic>{
        'lines': <String>[line],
      };
    }
  }

  /// The tasks as listed, with what Start would do to each worked out from its state.
  List<Map<String, dynamic>> get _listing => <Map<String, dynamic>>[
    for (final task in tasks)
      <String, dynamic>{
        'startAction': task['running'] == true
            ? 'RUNNING'
            : situation == 'vault-locked'
            ? 'NEEDS_VAULT'
            : 'RESUME',
        'startDetail': '',
        'phase': '',
        'run': '${task['name']}-run-1',
        'handInLimit': handInLimit,
        'files': <Map<String, dynamic>>[],
        // No forge follows this machine's work, which is a state, not an older machine.
        'builds': <Map<String, dynamic>>[],
        'buildReader': '',
        'buildProblem': '',
        ...task,
      },
  ];

  /// The bytes one file handed to a task may have, as a project's `limits.hand_in` sets it.
  int handInLimit = 64 * 1024 * 1024;

  final Map<String, ({int bytes, String sha256, List<int> got})> _incoming =
      <String, ({int bytes, String sha256, List<int> got})>{};

  final Map<String, List<Map<String, dynamic>>> _handInRecord = <String, List<Map<String, dynamic>>>{};

  /// Keeps one part of a file handed to a running task, and places the file once it is whole and
  /// its SHA-256 matches, as the machine does.
  Map<String, dynamic> _handIn(Map<String, dynamic> parameters) {
    final name = parameters['task'] as String? ?? '';
    final file = parameters['name'] as String? ?? '';
    final bytes = parameters['bytes'] as int? ?? 0;
    final sha256 = parameters['sha256'] as String? ?? '';
    final offset = parameters['offset'] as int? ?? 0;
    final task = _runningOrRefused(name);
    if (file.isEmpty || file.contains('/') || file.startsWith('.')) {
      throw MockRefusal('org.fuin.porelo.Tasks1.FileNameRefused', <String, dynamic>{
        'name': file,
        'reason': 'not a plain file name',
      });
    }
    if (bytes > handInLimit) {
      throw MockRefusal('org.fuin.porelo.Tasks1.FileTooLarge', <String, dynamic>{'bytes': bytes, 'limit': handInLimit});
    }
    final key = '$name/$file';
    var coming = _incoming[key];
    if (coming != null && (coming.bytes != bytes || coming.sha256 != sha256)) {
      throw MockRefusal('org.fuin.porelo.Tasks1.HandInInProgress', <String, dynamic>{
        'name': file,
        'received': coming.got.length,
        'bytes': coming.bytes,
      });
    }
    coming ??= _incoming[key] = (bytes: bytes, sha256: sha256, got: <int>[]);
    if (offset != coming.got.length) {
      throw MockRefusal('org.fuin.porelo.Tasks1.PartOutOfOrder', <String, dynamic>{
        'name': file,
        'received': coming.got.length,
      });
    }
    coming.got.addAll(base64.decode(parameters['part'] as String? ?? ''));
    if (coming.got.length < bytes) return <String, dynamic>{'received': coming.got.length};
    _incoming.remove(key);
    final actual = crypto.sha256.convert(coming.got).toString();
    if (coming.got.length != bytes || actual != sha256) {
      throw MockRefusal('org.fuin.porelo.Tasks1.FileDiffers', <String, dynamic>{'expected': sha256, 'actual': actual});
    }
    final placed = <String, dynamic>{
      'name': file,
      'bytes': bytes,
      'sha256': sha256,
      'at': DateTime.now().toUtc().toIso8601String(),
      'by': 'somebody',
      'run': '$name-run-1',
    };
    final before = _filesOf(task);
    _putFiles(name, <Map<String, dynamic>>[
      for (final each in before)
        if (each['name'] != file) each,
      placed,
    ]);
    (_handInRecord[name] ??= <Map<String, dynamic>>[]).add(<String, dynamic>{
      'event': before.any((each) => each['name'] == file) ? 'replaced' : 'given',
      'file': placed,
    });
    return <String, dynamic>{'received': bytes, 'file': placed};
  }

  /// Takes a handed-in file out of a running task again.
  Map<String, dynamic> _takeBack(Map<String, dynamic> parameters) {
    final name = parameters['task'] as String? ?? '';
    final file = parameters['name'] as String? ?? '';
    final files = _filesOf(_runningOrRefused(name));
    final taken = files.where((each) => each['name'] == file).firstOrNull;
    if (taken == null) {
      throw MockRefusal('org.fuin.porelo.Tasks1.NoSuchFile', <String, dynamic>{'task': name, 'name': file});
    }
    _putFiles(name, <Map<String, dynamic>>[
      for (final each in files)
        if (each['name'] != file) each,
    ]);
    (_handInRecord[name] ??= <Map<String, dynamic>>[]).add(<String, dynamic>{'event': 'taken back', 'file': taken});
    return <String, dynamic>{'file': taken};
  }

  /// The record under a task's name, also after the task is gone.
  Map<String, dynamic> _handIns(Map<String, dynamic> parameters) => <String, dynamic>{
    'record': _handInRecord[parameters['task'] as String? ?? ''] ?? <Map<String, dynamic>>[],
  };

  /// Brings a task up to its source, as Porelo does: an offline task has no gate to bring up, and
  /// the stand-in's gate never moves, so any other task, an online one included, is up to date.
  Map<String, dynamic> _refreshTask(Map<String, dynamic> parameters) {
    final name = parameters['task'] as String? ?? '';
    final task = tasks.where((each) => each['name'] == name).firstOrNull;
    if (task == null) {
      throw MockRefusal('org.fuin.porelo.Tasks1.NoSuchTask', <String, dynamic>{'task': name});
    }
    return <String, dynamic>{
      'outcome': task['securityClass'] == 'offline' ? 'NOT_GATED' : 'UNCHANGED',
      'moved': <String, String>{},
      'detail': '',
      'told': false,
    };
  }

  Map<String, dynamic> _runningOrRefused(String name) {
    final task = tasks.where((each) => each['name'] == name).firstOrNull;
    if (task == null) {
      throw MockRefusal('org.fuin.porelo.Tasks1.NoSuchTask', <String, dynamic>{'task': name});
    }
    if (task['running'] != true) {
      throw MockRefusal('org.fuin.porelo.Tasks1.NotRunning', <String, dynamic>{'task': name});
    }
    return task;
  }

  static List<Map<String, dynamic>> _filesOf(Map<String, dynamic> task) => task['files'] is List
      ? (task['files'] as List).whereType<Map<String, dynamic>>().toList()
      : <Map<String, dynamic>>[];

  void _putFiles(String name, List<Map<String, dynamic>> files) {
    tasks = <Map<String, dynamic>>[
      for (final each in tasks)
        if (each['name'] == name) <String, dynamic>{...each, 'files': files} else each,
    ];
    _changes.add(<String, dynamic>{'tasks': _listing});
  }

  /// Stops a task and keeps it: its container is its workspace.
  Map<String, dynamic> _stop(Map<String, dynamic> parameters) {
    final name = parameters['task'];
    final running = tasks.any((task) => task['name'] == name && task['running'] == true);
    if (running) {
      tasks = <Map<String, dynamic>>[
        for (final task in tasks)
          task['name'] != name
              ? task
              : <String, dynamic>{
                  ...task,
                  'running': false,
                  'state': 'Exited (143) 0 seconds ago',
                  'activity': 'DEAD',
                  'helpers': 0,
                },
      ];
      _changes.add(<String, dynamic>{'tasks': _listing});
    }
    return <String, dynamic>{
      'outcome': situation == 'newer-outcome'
          ? 'QUARANTINED'
          : running
          ? 'STOPPED'
          : 'NOTHING_TO_STOP',
      'helpers': running ? 2 : 0,
      // A count, as the daemon's Stop answers it; a stopped task's own Panic lists their names.
      'surviving': 0,
    };
  }

  /// Removes a task, or refuses rather than destroys.
  Map<String, dynamic> _remove(Map<String, dynamic> parameters) {
    final name = parameters['task'];
    final force = parameters['force'] == true;
    final rescue = parameters['rescue'] == true;
    final running = tasks.any((task) => task['name'] == name && task['running'] == true);
    final held = switch (situation) {
      'holds-work' => 'HOLDS_WORK',
      'nothing-knows' => 'NOTHING_KNOWS',
      _ => null,
    };
    // The daemon's order: held work first, while the container is up to rescue from; rescue needs
    // it up; and "still running" only for a task that holds nothing.
    final refusal = force
        ? null
        : rescue
        ? (running ? null : 'RESCUE_NEEDS_IT_RUNNING')
        : held ?? (running ? 'STILL_RUNNING' : null);
    if (refusal != null) {
      return <String, dynamic>{
        'outcome': refusal,
        'work': refusal == 'HOLDS_WORK' ? '2 commits on refs/heads/fix-rounding' : '',
        'rescuedRef': '',
        'removed': false,
        'discarded': 0,
      };
    }
    tasks = tasks.where((task) => task['name'] != name).toList();
    _changes.add(<String, dynamic>{'tasks': _listing});
    return <String, dynamic>{
      'outcome': situation == 'newer-outcome' ? 'QUARANTINED' : 'REMOVED',
      'work': '',
      'rescuedRef': rescue ? 'refs/porelo/rescued/$name' : '',
      'removed': true,
      // Counted only when it was removed, and nothing else ever records that any of it existed.
      'discarded': 3 * 1024 * 1024,
    };
  }

  /// Starts a listed task again: refused while it runs or while the vault is locked.
  Map<String, dynamic> _startAgain(String name) {
    final running = tasks.any((task) => task['name'] == name && task['running'] == true);
    if (running) return <String, dynamic>{'action': 'RUNNING'};
    if (situation == 'vault-locked') {
      return <String, dynamic>{'action': 'NEEDS_VAULT'};
    }
    tasks = <Map<String, dynamic>>[
      for (final task in tasks)
        task['name'] != name
            ? task
            : <String, dynamic>{...task, 'running': true, 'state': 'Up 1 second', 'activity': 'WORKING', 'helpers': 1},
    ];
    _changes.add(<String, dynamic>{'tasks': _listing});
    return <String, dynamic>{
      'action': 'RESUME',
      'container': name,
      'exitCode': 0,
      'helpersStarted': 1,
      // Fewer started than recorded on purpose: a partial start is worth seeing said out loud.
      'helpersRecorded': 2,
      'problems': <String>['gate helper did not come back'],
      'imageDrift': 'the image was rebuilt 20 minutes ago',
    };
  }

  /// Builds a project's image without starting anything.
  ///
  /// **Streamed, because a build takes minutes** and showing nothing for that long is
  /// indistinguishable from having hung. The depth decides how much of it runs — which is the
  /// whole reason three depths exist rather than one button.
  Stream<Map<String, dynamic>> _prepare(Map<String, dynamic> parameters) async* {
    final depth = parameters['rebuild'] as String? ?? 'CACHED';
    final steps = <String>[
      'STEP 1/6: FROM ubuntu:24.04',
      if (depth == 'EVERYTHING') '  --> downloading the base layers again',
      'STEP 2/6: RUN apt-get update',
      if (depth == 'EVERYTHING') '  --> installing packages' else '  --> using cache',
      'STEP 4/6: ARG PORELO_AGENT_LAYER',
      if (depth == 'CACHED') '  --> using cache' else '  --> the agent layer is invalidated from here down',
      'STEP 5/6: RUN install-agent',
      'STEP 6/6: COPY project snippet',
    ];
    for (final line in steps) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      yield <String, dynamic>{'line': line};
    }
    await Future<void>.delayed(const Duration(milliseconds: 350));
    yield <String, dynamic>{
      'outcome': 'PREPARED',
      'image': 'porelo/${parameters['project']}:latest',
      // Read back rather than echoed blindly: a depth this daemon did not recognize has to be
      // visible instead of silently defaulted.
      'rebuild': depth,
      'output': <String>[],
      'detail': '',
    };
  }

  /// Brings a container up, and — when a prompt is given — runs the agent in it.
  ///
  /// The two are different lengths of call, which is the whole point of the change that added
  /// `prompt`: without one this ends when the container is up, with one it lasts as long as the
  /// run and the agent's own output arrives as it is produced.
  Stream<Map<String, dynamic>> _launch(Map<String, dynamic> parameters) async* {
    if (situation == 'start-waits') {
      final waiting = Completer<void>();
      _waitingStart = waiting;
      if (parameters['steps'] == true) {
        for (final (name, text) in <(String, String)>[
          ('SOURCE', 'Reading the source'),
          ('CHECKS', 'Checking the repository'),
          ('CREDENTIALS', 'Reading credentials'),
        ]) {
          yield _startStep(name, 'DONE', text);
        }
        yield _startStep('CONVERSATION', 'WAITING', 'Preparing the conversation', waitingOn: "the room's homeserver");
      } else {
        yield <String, dynamic>{'line': 'Preparing the conversation'};
      }
      await waiting.future;
      const cause = 'Error: I/O error: Resource temporarily unavailable (os error 11)';
      if (parameters['steps'] == true) {
        yield _startStep('CONVERSATION', 'FAILED', 'Preparing the conversation', cause: cause);
      } else {
        yield <String, dynamic>{'line': cause};
      }
      if (identical(_waitingStart, waiting)) _waitingStart = null;
      yield <String, dynamic>{'exitCode': 69};
      return;
    }
    // A listed task is started again rather than built beside itself: same project, same name.
    final existing = tasks
        .where((task) => task['task'] == parameters['task'] && parameters['project'] == task['project'])
        .map((task) => task['name'] as String)
        .firstOrNull;
    if (existing != null) {
      yield _startAgain(existing);
      return;
    }
    // As Porelo does: an upstream it cannot read, with no mirror to start from, refuses before anything.
    if (situation == 'upstream-unreadable') {
      throw MockRefusal('org.fuin.porelo.Tasks1.UpstreamUnreadable', <String, dynamic>{
        'cause': 'KEY_REFUSED',
        'detail': _refusedKey,
        'fix': _keyFix,
      });
    }
    // As Porelo does: a task whose earlier work still waits at the gate is not started beside it.
    final waits = _waiting[parameters['task']];
    if (waits != null) {
      throw MockRefusal('org.fuin.porelo.Tasks1.EarlierWorkWaits', <String, dynamic>{
        'task': parameters['task'],
        'commit': waits['commit'],
        'subject': waits['subject'],
      });
    }
    const steps = <String>[
      'Resolving project.yml',
      'Reading the agent manifest',
      'Building the image (this is the slow bit)',
      '  layer 1/3',
      '  layer 2/3',
      '  layer 3/3',
      'Preparing the workspace',
      'Starting the gate',
    ];
    final failing = situation == 'failing-start';
    final prompt = parameters['prompt'] as String? ?? '';
    // The backend's own rule, not this one's: a prompt means UNATTENDED unless something else was
    // asked for, and nothing without a prompt is unattended.
    final mode = parameters['mode'] as String? ?? (prompt.isEmpty ? 'SHELL' : 'UNATTENDED');

    for (final step in steps) {
      if (pace > Duration.zero) await Future<void>.delayed(pace);
      yield <String, dynamic>{'line': step};
    }
    if (parameters['steps'] == true) {
      yield _startStep(
        'IMAGE',
        failing ? 'FAILED' : 'DONE',
        'Building the image',
        cause: failing ? 'could not reach the registry' : '',
      );
    }
    if (failing) {
      yield <String, dynamic>{'line': 'could not reach the registry'};
    }
    if (failing || prompt.isEmpty) {
      yield <String, dynamic>{'container': 'porelo-checkout-shell', 'exitCode': failing ? 1 : 0};
      return;
    }

    // No agent installed is a refusal, not a failed run: nothing ran and there is no log.
    if (situation == 'no-agent') {
      if (parameters['steps'] == true) {
        yield _startStep('AGENT', 'FAILED', 'Starting the agent', cause: 'No agent is installed.');
      }
      yield <String, dynamic>{'container': '', 'exitCode': 69};
      return;
    }

    // Raw log, the same text `Tail` serves for `task.log`. The agent's own formatting is made in
    // the CLI process and never reaches a socket.
    for (final line in <String>[
      'agent: $prompt',
      'agent: reading lib/money.dart',
      'agent: editing lib/money.dart',
      'agent: running the tests',
    ]) {
      if (pace > Duration.zero) await Future<void>.delayed(pace);
      yield <String, dynamic>{'line': line};
    }

    final container = parameters['task'] as String? ?? 'porelo-checkout-run';
    if (situation == 'out-of-time') {
      // Killed by its own limit. The log is kept, which is why the lines above still stand.
      yield <String, dynamic>{'container': container, 'exitCode': 124};
      return;
    }

    // The run is listed afterwards, carrying what it was asked to do — which is what continuing
    // it with a new prompt reads back.
    tasks = <Map<String, dynamic>>[
      ...tasks,
      _task(
        container,
        (parameters['project'] as String? ?? '').contains('billing') ? 'billing' : 'checkout',
        running: false,
        helpers: 0,
        activity: 'DEAD',
        mode: mode,
        agent: parameters['agent'] as String? ?? 'an-agent',
        prompt: prompt,
      ),
    ];
    _changes.add(<String, dynamic>{'tasks': _listing});
    yield <String, dynamic>{'container': container, 'exitCode': 0};
  }

  static Map<String, dynamic> _startStep(
    String step,
    String state,
    String text, {
    String waitingOn = '',
    String cause = '',
  }) => <String, dynamic>{
    'step': <String, dynamic>{'step': step, 'state': state, 'text': text, 'waitingOn': waitingOn, 'cause': cause},
  };

  static const _changeDiff = '''
diff --git a/lib/money.dart b/lib/money.dart
index 1a2b3c4..5d6e7f8 100644
--- a/lib/money.dart
+++ b/lib/money.dart
@@ -12,7 +12,7 @@ class Money {
   final double value;
 
   int get pennies {
-    return (value * 100).ceil();
+    return (value * 100).round();
   }
 }
diff --git a/test/money_test.dart b/test/money_test.dart
--- a/test/money_test.dart
+++ b/test/money_test.dart
@@ -4,3 +4,7 @@ void main() {
     expect(Money(1.005).pennies, 101);
   });
+
+  test('rounds down below the half', () {
+    expect(Money(1.004).pennies, 100);
+  });
 }
''';

  static const _deletionDiff = '''
diff --git a/lib/retry.dart b/lib/retry.dart
deleted file mode 100644
--- a/lib/retry.dart
+++ /dev/null
@@ -1,5 +0,0 @@
-Future<void> retry(Future<void> Function() what) async {
-  for (var attempt = 0; attempt < 3; attempt++) {
-    try { await what(); return; } on Exception { /* again */ }
-  }
-}
''';

  static List<Map<String, dynamic>> _aMachineWithWorkOnIt() => <Map<String, dynamic>>[
    // One of each: telling the states apart is the point, and a machine with only
    // working tasks on it proves nothing.
    _task('porelo-checkout-shell', 'checkout', activity: 'WAITING', waitingFor: 'api.example.test:443', minutesAgo: 6),
    // Its own ref is waiting at the gate, which is what `waiting` says and what nothing
    // could be joined to work out.
    _task('porelo-checkout-migrate', 'checkout', running: false, helpers: 0, waiting: 1),
    _task(
      'porelo-billing-shell',
      'billing',
      securityClass: 'offline',
      helpers: 1,
      activity: 'IDLE',
      mode: 'SHELL',
      minutesAgo: 47,
    ),
    // A container up with no helpers has lost its gate or its clearance watcher, which the
    // detail calls out. Worth having on screen while the frame is being looked at.
    // A terminal is attached to this one, so nothing on this side can see what it is doing.
    // Started with enforcement off: nothing will ever be asked about what it reaches, which
    // is a choice somebody made and the interface has to show.
    _task('porelo-billing-audit', 'billing', helpers: 0, activity: 'UNKNOWN', mode: 'AGENT', clearance: 'off'),
    // A failed run is no longer swept away: a non-zero exit stops the container and leaves it
    // in place, workspace and logs intact, because the run worth looking at is the one that
    // went wrong. So a list has more exited tasks on it than it used to.
    _task('porelo-checkout-tests', 'checkout', running: false, helpers: 0),
    // Running, in a project whose file nothing can find any more. Widening its run works and
    // writing to its project does not, which is the one outcome most likely to be read as a
    // failure when it is not.
    _task('porelo-moved-work', 'moved-away'),
  ];

  static Map<String, dynamic> _task(
    String name,
    String project, {
    bool running = true,
    int helpers = 2,
    String securityClass = 'guarded',
    String activity = 'WORKING',
    String waitingFor = '',
    String mode = 'UNATTENDED',
    String agent = 'an-agent',
    int minutesAgo = 4,
    String clearance = 'prompt',
    String? prompt,
    int waiting = 0,
  }) => <String, dynamic>{
    'name': name,
    // The stand-in's own naming rule; a client never derives this.
    'task': name.replaceFirst('porelo-$project-', ''),
    'label': '',
    'project': project,
    'securityClass': securityClass,
    'state': running ? 'Up $minutesAgo minutes' : 'Exited (1) 12 minutes ago',
    'running': running,
    'helpers': helpers,
    'agent': agent,
    'mode': mode,
    'prompt': prompt ?? (mode == 'UNATTENDED' ? 'Fix the rounding in Money.pennies and add a test for it' : ''),
    // The ref carries the *task* name, which is the container name without the project
    // prefix — not the container name itself, which has the run in it.
    'branch': 'refs/porelo/incoming/${name.replaceFirst('porelo-$project-', '')}',
    'since': DateTime.now().toUtc().subtract(Duration(minutes: minutesAgo)).toIso8601String(),
    'activity': running ? activity : 'DEAD',
    'waitingFor': waitingFor,
    'clearance': clearance,
    'waiting': waiting,
  };
}
