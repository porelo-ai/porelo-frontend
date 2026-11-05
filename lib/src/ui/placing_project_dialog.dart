import 'dart:async';

import 'package:flutter/material.dart';

import '../app/host_progress.dart';
import '../app/organization_source.dart';
import 'organization_token_words.dart';

/// Follows a project just put on [host] until it is carried, or says why not: the connection, the
/// token where it waits for one, and the machine's own fetch, in one place.
class PlacingProjectDialog extends StatefulWidget {
  /// Constructor taking what it follows.
  const PlacingProjectDialog({
    required this.project,
    required this.host,
    required this.view,
    required this.connections,
    this.onGiveToken,
    this.every = const Duration(seconds: 20),
    this.patience = const Duration(minutes: 6),
    super.key,
  });

  /// The project put on the machine.
  final String project;

  /// The machine it was put on.
  final String host;

  /// What the organization says, for the forge's name.
  final OrganizationView? view;

  /// This computer's way to the machine.
  final HostConnections connections;

  /// Gives the machine the person's token; answers the words to show, if any. None: not offered.
  final Future<String?> Function(String host)? onGiveToken;

  /// How often the machine is asked: a login each time, so not often, or sshd counts a refused one.
  final Duration every;

  /// How long this follows before it says the machine goes on alone.
  final Duration patience;

  @override
  State<PlacingProjectDialog> createState() => _PlacingProjectDialogState();
}

class _PlacingProjectDialogState extends State<PlacingProjectDialog> {
  Timer? _timer;
  String? _stopped;
  String? _tokenWhy;
  String? _lastRefusal;
  HostProgress? _progress;
  bool _giving = false;
  bool _asking = false;
  int _quietAsks = 0;
  int _nextQuiet = 1;
  late final DateTime _began = DateTime.now();

  @override
  void initState() {
    super.initState();
    unawaited(_begin());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _begin() async {
    try {
      if (!widget.connections.connected(widget.host)) await widget.connections.connect(widget.host);
    } on OrganizationRefused catch (refused) {
      if (mounted) setState(() => _stopped = 'This computer did not connect to ${widget.host}: ${refused.words}');
      return;
    }
    try {
      await _take(widget.connections.refresh(widget.host));
    } on OrganizationRefused catch (refused) {
      // A first fetch may refuse before its account exists; asking still tells how it stands, and if
      // that refuses too, the machine's words are what there is to say.
      try {
        await _take(widget.connections.progress(widget.host));
      } on OrganizationRefused {
        if (mounted) setState(() => _lastRefusal = refused.words);
      }
    }
    if (!mounted || _stopped != null || _ended) return;
    _timer = Timer.periodic(widget.every, (_) => unawaited(_ask()));
  }

  Future<void> _ask() async {
    if (_asking || _giving || _ended) return;
    if (DateTime.now().difference(_began) > widget.patience) {
      _timer?.cancel();
      setState(() {
        _stopped =
            '${widget.host} has not taken ${widget.project} yet, and goes on by itself. Its page says how it stands.';
      });
      return;
    }
    if (_quietAsks > 0) {
      _quietAsks--;
      return;
    }
    _asking = true;
    try {
      await _take(widget.connections.progress(widget.host));
      _nextQuiet = 1;
    } on OrganizationRefused catch (refused) {
      // A machine that does not answer now is asked again, less and less often, as each refused login
      // counts against this address; the patience above ends this.
      _quietAsks = _nextQuiet;
      _nextQuiet = _nextQuiet >= 8 ? 8 : _nextQuiet * 2;
      if (mounted) setState(() => _lastRefusal = refused.words);
    } finally {
      _asking = false;
    }
  }

  Future<void> _take(Future<HostProgress> asked) async {
    final progress = await asked;
    if (!mounted) return;
    setState(() {
      _progress = progress;
      _lastRefusal = null;
    });
    if (_ended) _timer?.cancel();
  }

  HostProjectProgress? get _mine =>
      _progress?.projects.where((project) => project.project == widget.project).firstOrNull;

  bool get _ended =>
      _mine?.state == 'carried' || _mine?.state == 'held' || _mine?.state == 'refused' || _mine?.hasNoAddress == true;

  bool get _wantsToken => (_mine?.waitsForToken ?? false) || (_progress?.waitsForToken ?? false);

  Future<void> _give() async {
    final first = _progress?.waitsForToken ?? false;
    setState(() {
      _giving = true;
      _tokenWhy = null;
    });
    String? words;
    try {
      words = await widget.onGiveToken?.call(widget.host);
    } on Exception {
      // Its own words are not said here: they are no one's to read for what a token may have been.
      words = 'The token was not given. Close this and give it from the machine\'s page.';
    } finally {
      if (mounted) {
        setState(() {
          _giving = false;
          _tokenWhy = words;
        });
      }
    }
    if (!mounted || words != null) return;
    try {
      await _take(widget.connections.refresh(widget.host));
      // The machine has made the account it could not make before: the connection can come up now.
      if (first && !(_progress?.waitsForToken ?? true)) await widget.connections.connect(widget.host);
    } on OrganizationRefused catch (refused) {
      if (mounted) setState(() => _lastRefusal = refused.words);
    }
  }

  String get _words {
    if (_stopped case final stopped?) return stopped;
    final mine = _mine;
    final why = mine?.why;
    return switch (mine?.state) {
      'carried' => '${widget.host} carries ${widget.project}.',
      'held' || 'refused' =>
        '${widget.host} did not take ${widget.project}${why == null ? '' : ': $why'}. Its page says what to do.',
      _ when mine?.hasNoAddress == true =>
        '${widget.project} has no address yet: its Project Admin creates its Git repository first, and ${widget.host} takes it then.',
      _ when _wantsToken => switch (widget.view) {
        final view? => organizationTokenWords(view, widget.host, project: widget.project),
        null => '${widget.host} waits for a token.',
      },
      _ when _progress?.refused != null =>
        '${widget.host} refused its last fetch and stays on what it took before: ${_progress!.refused}.',
      _ when _lastRefusal != null => '${widget.host} did not answer: $_lastRefusal It goes on by itself.',
      _ when _progress == null => 'Connecting to ${widget.host}…',
      _ => '${widget.host} takes ${widget.project} when it next reads the organization, within five minutes.',
    };
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const Key('placing-project'),
    title: Text('Putting ${widget.project} on ${widget.host}'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_words, key: const Key('placing-project.words')),
        if (_tokenWhy case final why?) Text(why, key: const Key('placing-project.tokenWhy')),
      ],
    ),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      if (_stopped == null && !_ended && _wantsToken && widget.onGiveToken != null)
        FilledButton(
          key: const Key('placing-project.giveToken'),
          onPressed: _giving ? null : () => unawaited(_give()),
          child: Text('Give it my ${organizationForgeName(widget.view)} token…'),
        ),
    ],
  );
}
