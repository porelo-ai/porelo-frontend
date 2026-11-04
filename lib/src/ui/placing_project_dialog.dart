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
    this.every = const Duration(seconds: 5),
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

  /// How often the machine is asked.
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
  HostProgress? _progress;
  bool _giving = false;
  bool _asking = false;
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
      await _take(widget.connections.refresh(widget.host));
    } on OrganizationRefused catch (refused) {
      // The first fetch may refuse before its account exists; asking still tells how it stands.
      if (!mounted) return;
      if (!widget.connections.connected(widget.host)) {
        setState(() => _stopped = 'This computer did not connect to ${widget.host}: ${refused.words}');
        return;
      }
    }
    if (!mounted || _stopped != null) return;
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
    _asking = true;
    try {
      await _take(widget.connections.progress(widget.host));
    } on OrganizationRefused {
      // A machine that does not answer now is asked again; the patience above ends this.
    } finally {
      _asking = false;
    }
  }

  Future<void> _take(Future<HostProgress> asked) async {
    final progress = await asked;
    if (!mounted) return;
    setState(() => _progress = progress);
    if (_ended) _timer?.cancel();
  }

  HostProjectProgress? get _mine =>
      _progress?.projects.where((project) => project.project == widget.project).firstOrNull;

  bool get _ended => _mine?.state == 'carried' || _mine?.state == 'held' || _mine?.state == 'refused';

  bool get _wantsToken => _mine?.waitsForToken ?? (_progress?.waitsForToken ?? false);

  Future<void> _give() async {
    setState(() {
      _giving = true;
      _tokenWhy = null;
    });
    final words = await widget.onGiveToken?.call(widget.host);
    if (!mounted) return;
    setState(() {
      _giving = false;
      _tokenWhy = words;
    });
    try {
      await _take(widget.connections.refresh(widget.host));
    } on OrganizationRefused {
      // Asked again by the timer.
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
      _ when _wantsToken => switch (widget.view) {
        final view? => organizationTokenWords(view, widget.host, project: widget.project),
        null => '${widget.host} waits for a token.',
      },
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
