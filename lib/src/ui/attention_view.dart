import 'dart:async';

import 'package:flutter/material.dart';
import 'package:porelo_frontend/client.dart';

import '../app/builds.dart';
import '../app/granting.dart';
import '../app/host_runs.dart';
import '../app/attention.dart';
import '../app/commands.dart';
import '../app/fleet_model.dart';
import '../app/machines.dart';
import '../app/operations.dart';
import 'command_menu.dart';
import 'expandable_list_row.dart';
import 'grant_view.dart';
import 'held_message_view.dart';
import 'how_long.dart';
import 'operations.dart';
import 'needs_machine.dart';
import 'panes.dart';
import 'tile_console.dart';
import 'tokens.dart';

/// What needs a person, from every machine at once. The window opens here.
///
/// **A landing surface, not a second view.** The rail is for going somewhere to change something;
/// this is for finding out whether anything needs you, and answering it where it is.
class AttentionView extends StatefulWidget {
  /// Constructor taking what to show and what the tiles can do.
  const AttentionView({
    required this.attention,
    required this.onDecide,
    required this.actionsFor,
    required this.onReview,
    this.unlockFor,
    this.onStopFollowing,
    this.onPutAway,
    this.onSelect,
    this.onOpenOperation,
    this.onOpenHost,
    this.onBringVpnUp,
    this.onTakeVpnDown,
    super.key,
  });

  /// The same machine-specific unlock path used by work.unlock, or null when unavailable.
  final VoidCallback? Function(Machine machine)? unlockFor;

  /// Opens a removal preview on the row's machine, without changing the selected project.
  final void Function(Machine machine, Project project)? onStopFollowing;

  /// Every tile, most urgent first.
  final Attention attention;

  /// Goes to a tile's work where it lives.
  final void Function(Tile tile)? onSelect;

  /// Answers a question, on the machine that asked it.
  final void Function(Tile tile, Prompt prompt, {required bool allow}) onDecide;

  /// What the work on a tile can be told to do, on the tile's own machine.
  final List<Command> Function(Tile tile) actionsFor;

  /// Opens the gate for the work's project.
  final void Function(Tile tile) onReview;

  /// Puts away the outcome of a question, on the machine that asked it.
  final void Function(Tile tile, Prompt prompt)? onPutAway;

  /// Opens the retained host stop and its terminal before a daemon exists.
  final void Function(String project)? onOpenHost;

  /// Opens the same local root check used by the machine menu.
  final void Function(Machine machine)? onBringVpnUp;

  /// Takes down the local tunnel left by a given-back server.
  final void Function(Machine machine)? onTakeVpnDown;

  /// Opens what a failed operation printed, which is what puts it away.
  final void Function(Operation operation)? onOpenOperation;

  @override
  State<AttentionView> createState() => _AttentionViewState();
}

class _AttentionViewState extends State<AttentionView> {
  // A countdown that does not move overstates the time left, so it ticks while one is on screen.
  Timer? _ticker;

  void _keepTicking(bool wanted) {
    if (wanted && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 15), (_) {
        if (mounted) setState(() {});
      });
    } else if (!wanted && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.attention,
    builder: (context, _) {
      final rows = widget.attention.openRows;
      final resolved = widget.attention.recentlyResolved;
      final needing = widget.attention.needingSomebody;
      _keepTicking(
        widget.attention.needing.any((tile) => tile.questions.any((question) => question.expiresAt != null)),
      );
      return Column(
        children: <Widget>[
          PaneHeader(
            title: 'Needs you',
            trailing: Flexible(
              child: Text(
                needing == 0 ? 'nothing needs you' : '$needing need you',
                key: const Key('needing-count'),
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ),
          Expanded(
            child: rows.isEmpty && resolved.isEmpty
                ? const Center(child: Text('Nothing needs you on any machine.', key: Key('nothing-needs-you')))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(Space.normal),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Column(
                          key: const Key('open-attention'),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [for (final row in rows) _row(context, row)],
                        ),
                        if (resolved.isNotEmpty)
                          Column(
                            key: const Key('recently-resolved'),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Padding(padding: EdgeInsets.all(Space.normal), child: Text('Recently resolved')),
                              for (final each in resolved)
                                _ResolvedRow(
                                  child: Builder(builder: (context) => _row(context, each.row, resolved: true)),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      );
    },
  );
}

extension on _AttentionViewState {
  Widget _row(BuildContext context, AttentionRow row, {bool resolved = false}) {
    final attention = widget.attention;
    final reason = resolved ? 'this row is resolved' : null;
    void details() => unawaited(
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(row.machine),
          content: SizedBox(
            width: Sizes.dialogMedium,
            child: SingleChildScrollView(child: _details(context, row, resolved: resolved)),
          ),
          actions: [
            TextButton(
              onPressed: closeListDetailsCommand(() => Navigator.pop(context)).run,
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
    var title = row.machine;
    var state = resolved ? 'Resolved' : 'Needs you';
    var icon = Icons.info_outline;
    VoidCallback open = details;
    Command? primary;
    Key? primaryKey;
    switch (row.kind) {
      case AttentionKind.host:
        final stop = row.value as HostStop;
        final runs = attention.hostRuns;
        final run = runs?.of(stop.project);
        title = '${stop.project} server';
        state = stop.interrupted ? 'Interrupted' : 'Needs you';
        icon = Icons.dns_outlined;
        primary = stop.interrupted
            ? continueHostPreparationCommand(
                project: stop.project,
                resolved: resolved,
                goOn: () {
                  if (runs != null && run != null) unawaited(runs.resume(run));
                },
              ).unless(run == null || runs == null ? 'host setup is unavailable here' : null)
            : hostPreparationCommand(
                project: stop.project,
                resolved: resolved,
                open: () => widget.onOpenHost?.call(stop.project),
              ).unless(widget.onOpenHost == null ? 'host setup is unavailable here' : null);
        open = !primary.visible || resolved || widget.onOpenHost == null
            ? details
            : () => widget.onOpenHost!(stop.project);
      case AttentionKind.vpn:
        final machine = row.value as Machine;
        title = '${machine.hostProject} server';
        state = 'VPN down';
        icon = Icons.link_off;
        primary = bringHostVpnUpAgainCommand(
          run: () => widget.onBringVpnUp?.call(machine),
          unavailable: reason ?? (widget.onBringVpnUp == null ? 'VPN setup is unavailable here' : null),
        );
      case AttentionKind.vpnCleanup:
        final machine = row.value as Machine;
        title = '${machine.hostProject} server';
        state = 'Given back, VPN still up';
        icon = Icons.link_off;
        primary = takeGivenBackVpnDownCommand(
          run: () => widget.onTakeVpnDown?.call(machine),
          unavailable: reason ?? (widget.onTakeVpnDown == null ? 'VPN cleanup is unavailable here' : null),
        );
      case AttentionKind.silent:
        final each = row.value as ({Machine machine, String words});
        state = 'Not answering';
        icon = Icons.cloud_off_outlined;
        primary = retrySilentMachine(each.machine, attention.fleetOf(each.machine)).unless(reason);
      case AttentionKind.following:
        final each = row.value as ({Machine machine, Project project, Followed followed});
        title = each.project.name;
        state = 'Not following';
        icon = Icons.folder_outlined;
      case AttentionKind.forward:
        final each = row.value as ({String machine, String project, String words});
        final machine = attention.machineNamed(each.machine);
        title = each.project;
        state = 'Homeserver unreachable';
        icon = Icons.link_off;
        primary = retryAttentionForwardCommand(
          run: () {
            if (machine != null) unawaited(attention.homeservers?.retry(machine, each.project));
          },
          unavailable: reason ?? (machine == null ? 'the machine is no longer watched' : null),
        );
      case AttentionKind.waiting:
        final each = row.value as WaitingMessages;
        title = 'Messages wait';
        state = each.waitsOn == 'vault' ? 'Vault locked' : 'Waiting';
        icon = Icons.mail_outline;
        if (each.waitsOn == 'vault') {
          primary = unlockWaitingMessages(
            each.machine,
            attention.fleetOf(each.machine),
            widget.unlockFor?.call(each.machine),
          ).unless(reason);
        }
      case AttentionKind.unlisted:
        final each = row.value as ({Machine machine, String problem});
        title = 'Held messages';
        state = 'Cannot list';
        icon = Icons.mail_outline;
        primary = askForHeldMessages(each.machine, attention.fleetOf(each.machine)).unless(reason);
      case AttentionKind.message:
        final each = row.value as ({Machine machine, HeldMessage message});
        title = HeldMessageRow.headline(each.message);
        state = each.message.standing;
        icon = Icons.mail_outline;
        open = () => unawaited(
          showDialog<void>(
            context: context,
            builder: (_) => HeldMessageDialog(
              fleet: attention.fleetOf(each.machine),
              message: each.message,
              readOnly: resolved,
              initialRead: row.read,
              onRead: resolved ? null : (read) => attention.messageRead(each.machine, each.message, read),
            ),
          ),
        );
        primary = readAttentionMessageCommand(message: each.message, run: open, unavailable: reason);
      case AttentionKind.authorization:
        final each = row.value as ({Machine machine, AuthorizationNeeded needed});
        title = AuthorizationRow.headline(each.needed);
        state = 'Grant needed';
        icon = Icons.verified_user_outlined;
        primary = grantAttentionCommand(
          run: () => unawaited(
            showGranting(
              context,
              Granting(attention.fleetOf(each.machine).backend, each.machine, each.needed.credential),
            ),
          ),
          unavailable: reason,
        );
      case AttentionKind.operation:
        final operation = row.value as Operation;
        title = operation.title;
        state = 'Failed';
        icon = Icons.error_outline;
        open = widget.onOpenOperation == null || resolved ? details : () => widget.onOpenOperation!(operation);
        primary = openAttentionOperationCommand(
          run: open,
          unavailable: reason ?? (widget.onOpenOperation == null ? 'operation details are unavailable here' : null),
        );
        primaryKey = const Key('failed-operation-open');
      case AttentionKind.tile:
        final tile = row.value as Tile;
        title = tile.task == null
            ? tile.questions.firstOrNull?.task ?? tile.settled?.task ?? 'Unknown work'
            : tile.task!.label.isEmpty
            ? tile.task!.name
            : tile.task!.label;
        state = TaskTile._headline(tile);
        icon = Icons.work_outline;
        open = resolved || widget.onSelect == null ? details : () => widget.onSelect!(tile);
        if (tile.task?.hasWorkWaiting ?? false) {
          primary = reviewAttentionWorkCommand(
            run: () => widget.onReview(tile),
            unavailable:
                reason ?? (tile.fleet.reachability == Reachability.connected ? null : 'the machine is not answering'),
          );
        }
      case AttentionKind.missed:
        final each = row.value as ({Machine machine, int count});
        title = 'Dropped questions';
        state = '${each.count} unseen';
        icon = Icons.help_outline;
        primary = missedQuestionsSeenCommand(
          run: attention.fleetOf(each.machine).clearance.missedSeen,
          unavailable: reason,
        );
    }
    final navigation = listOpenCommand(label: 'Open details', home: Home.attentionRow, open: open);
    return ExpandableListRow(
      key: ValueKey('attention-row ${row.id}'),
      leading: Icon(icon),
      title: '$title · ${row.machine}',
      state: resolved ? 'Resolved' : state,
      onOpen: navigation.run,
      primary: resolved ? null : primary ?? navigation,
      primaryKey: primaryKey,
      details: _details(context, row, resolved: resolved, includePrimary: resolved),
    );
  }

  Widget _details(BuildContext context, AttentionRow row, {bool resolved = false, bool includePrimary = true}) {
    final attention = widget.attention;
    final reason = resolved ? 'this row is resolved' : null;
    switch (row.kind) {
      case AttentionKind.vpnCleanup:
        final machine = row.value as Machine;
        final command = takeGivenBackVpnDownCommand(
          run: () => widget.onTakeVpnDown?.call(machine),
          unavailable: resolved
              ? 'this row is resolved'
              : widget.onTakeVpnDown == null
              ? 'VPN cleanup is unavailable here'
              : null,
        );
        return Card(
          key: ValueKey('vpn-cleanup ${machine.hostProject}'),
          child: Padding(
            padding: const EdgeInsets.all(Space.normal),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NeedsMachine(row.machine),
                Text(
                  attention.hostRuns?.vpnLinkUp == true
                      ? 'The server is given back; the VPN on this computer is still up'
                      : 'The server is given back; the VPN on this computer could not be checked',
                ),
                _RowCommand(command),
              ],
            ),
          ),
        );
      case AttentionKind.vpn:
        final machine = row.value as Machine;
        final command = bringHostVpnUpAgainCommand(
          run: () => widget.onBringVpnUp?.call(machine),
          unavailable: resolved
              ? 'this row is resolved'
              : widget.onBringVpnUp == null
              ? 'VPN setup is unavailable here'
              : null,
        );
        return Card(
          key: ValueKey('vpn-needs ${machine.hostProject}'),
          child: Padding(
            padding: const EdgeInsets.all(Space.normal),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NeedsMachine(row.machine),
                Text('The VPN to ${machine.hostProject} server is down'),
                if (includePrimary) _RowCommand(command),
              ],
            ),
          ),
        );
      case AttentionKind.host:
        final stop = row.value as HostStop;
        final runs = attention.hostRuns;
        final run = runs?.of(stop.project);
        final command = stop.interrupted
            ? continueHostPreparationCommand(
                project: stop.project,
                resolved: resolved,
                goOn: () {
                  if (runs != null && run != null) unawaited(runs.resume(run));
                },
              ).unless(run == null || runs == null ? 'host setup is unavailable here' : null)
            : hostPreparationCommand(
                project: stop.project,
                resolved: resolved,
                open: () => widget.onOpenHost?.call(stop.project),
              ).unless(widget.onOpenHost == null ? 'host setup is unavailable here' : null);
        return Card(
          key: ValueKey('host-needs ${stop.project}'),
          child: Padding(
            padding: const EdgeInsets.all(Space.normal),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NeedsMachine(row.machine),
                Text(stop.text),
                for (final need in stop.needs) Text(need),
                if (includePrimary) _RowCommand(command),
              ],
            ),
          ),
        );
      case AttentionKind.silent:
        final each = row.value as ({Machine machine, String words});
        return _MachineNotice(
          machine: each.machine,
          words: each.words,
          retry: retrySilentMachine(each.machine, attention.fleetOf(each.machine)).unless(reason),
          onSeen: resolved ? null : () => attention.markSeen(each.machine),
        );
      case AttentionKind.following:
        final each = row.value as ({Machine machine, Project project, Followed followed});
        return _NotFollowing(
          machine: each.machine,
          project: each.project,
          followed: each.followed,
          fleet: attention.fleetOf(each.machine),
          resolved: resolved,
        );
      case AttentionKind.forward:
        final each = row.value as ({String machine, String project, String words});
        final machine = attention.machineNamed(each.machine);
        return Card(
          key: ValueKey('homeserver-unforwarded ${each.machine}/${each.project}'),
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: ListTile(
            leading: const Icon(Icons.link_off),
            title: Text('The homeserver of ${each.project} is not reachable from here'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NeedsMachine(each.machine),
                Text('${each.words}\nA Matrix client on this computer cannot reach it until it is.'),
              ],
            ),
            trailing: TextButton(
              key: ValueKey('homeserver-retry ${each.machine}/${each.project}'),
              onPressed: resolved || machine == null
                  ? null
                  : retryAttentionForwardCommand(
                      run: () => unawaited(attention.homeservers?.retry(machine, each.project)),
                    ).run,
              child: const Text('Try again'),
            ),
          ),
        );
      case AttentionKind.waiting:
        final each = row.value as WaitingMessages;
        final namedVault = each.waitsOn == 'vault' && each.vault.isNotEmpty;
        return Card(
          key: ValueKey('messages-wait ${each.machine.name}'),
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(Space.normal),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Messages wait'),
                NeedsMachine(each.machine.name),
                if (namedVault) ...[
                  Text('The vault on ${each.machine.needsATunnel ? each.machine.name : 'this computer'} is locked'),
                  Text(each.vault, style: Theme.of(context).textTheme.bodySmall),
                  const Text('Projects held up:'),
                  for (final project in each.projects) Text(_heldProjectWords(project)),
                ] else
                  Text('${each.waits}\nHeld up: ${each.projects.map((project) => project.name).join(', ')}'),
                if (each.waitsOn == 'vault')
                  _RowCommand(
                    unlockWaitingMessages(
                      each.machine,
                      attention.fleetOf(each.machine),
                      widget.unlockFor?.call(each.machine),
                    ).unless(reason),
                  ),
                if (each.waitsOn == 'vault')
                  for (final project in each.projects)
                    _RowCommand(
                      stopFollowingWaitingProject(
                        each.machine,
                        attention.fleetOf(each.machine),
                        project,
                        widget.onStopFollowing == null ? null : () => widget.onStopFollowing!(each.machine, project),
                      ).unless(reason),
                    ),
              ],
            ),
          ),
        );
      case AttentionKind.unlisted:
        final each = row.value as ({Machine machine, String problem});
        return Card(
          key: ValueKey('messages-unlisted ${each.machine.name}'),
          child: Padding(
            padding: const EdgeInsets.all(Space.normal),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(each.problem),
                NeedsMachine(each.machine.name),
                if (includePrimary)
                  _RowCommand(askForHeldMessages(each.machine, attention.fleetOf(each.machine)).unless(reason)),
              ],
            ),
          ),
        );
      case AttentionKind.message:
        final each = row.value as ({Machine machine, HeldMessage message});
        return HeldMessageRow(
          machine: each.machine,
          fleet: attention.fleetOf(each.machine),
          message: each.message,
          resolved: resolved,
          read: row.read,
          onRead: resolved ? null : (read) => attention.messageRead(each.machine, each.message, read),
        );
      case AttentionKind.authorization:
        final each = row.value as ({Machine machine, AuthorizationNeeded needed});
        return AuthorizationRow(
          machine: each.machine,
          fleet: attention.fleetOf(each.machine),
          needed: each.needed,
          resolved: resolved,
        );
      case AttentionKind.operation:
        final operation = row.value as Operation;
        return _FailedOperation(
          operation: operation,
          onOpen: resolved || widget.onOpenOperation == null ? null : () => widget.onOpenOperation!(operation),
        );
      case AttentionKind.tile:
        final tile = row.value as Tile;
        return TaskTile(
          tile: tile,
          resolved: resolved,
          actions: tile.task == null
              ? const []
              : [for (final command in widget.actionsFor(tile)) command.unless(reason)],
          onDecide: widget.onDecide,
          onReview: widget.onReview,
          onPutAway: widget.onPutAway,
          onSelect: resolved || widget.onSelect == null ? null : () => widget.onSelect!(tile),
        );
      case AttentionKind.missed:
        final each = row.value as ({Machine machine, int count});
        return _MissedQuestions(
          machine: each.machine,
          count: each.count,
          onSeen: resolved ? null : attention.fleetOf(each.machine).clearance.missedSeen,
        );
    }
  }

  String _heldProjectWords(Project project) {
    final lastUsed = project.lastUsed;
    if (lastUsed == null) return project.name;
    if (lastUsed.isEmpty) return '${project.name} — never used here';
    final ago = howLongSince(DateTime.tryParse(lastUsed), now: widget.attention.now);
    return '${project.name} — ${ago == null ? 'last use unknown' : 'last used $ago ago'}';
  }
}

class _RowCommand extends StatelessWidget {
  const _RowCommand(this.command);

  final Command command;

  @override
  Widget build(BuildContext context) => !command.visible
      ? const SizedBox.shrink()
      : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton(onPressed: command.available ? command.run : null, child: Text(command.label)),
            if (command.unavailable case final reason?) Text(reason, style: Theme.of(context).textTheme.bodySmall),
          ],
        );
}

class _ResolvedRow extends StatelessWidget {
  const _ResolvedRow({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = theme.disabledColor;
    final scheme = theme.colorScheme;
    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.apply(bodyColor: colour, displayColor: colour),
        colorScheme: scheme.copyWith(onSurface: colour, onErrorContainer: colour, error: colour, primary: colour),
      ),
      child: child,
    );
  }
}

/// A followed project whose newest commit was not taken, and will not be until somebody acts.
///
/// **The key's fingerprint is shown whole**: it is not a secret, and comparing it with the key
/// somebody meant to pin is the whole of what a person can do about a refused signature.
class _NotFollowing extends StatelessWidget {
  const _NotFollowing({
    required this.machine,
    required this.project,
    required this.followed,
    required this.fleet,
    this.resolved = false,
  });

  final bool resolved;

  final Machine machine;

  /// Where the project is followed, to take a rewritten history from.
  final FleetModel fleet;

  final Project project;

  final Followed followed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      key: ValueKey<String>('not-following ${machine.name}/${project.name}'),
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(Space.normal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(project.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            NeedsMachine(machine.name),
            const SizedBox(height: Space.tight),
            Text(followed.words),
            if (followed.signer.isNotEmpty) SelectableText('Signed by ${followed.signer}', style: text.bodySmall),
            if (followed.detail.isNotEmpty) Text(followed.detail, style: text.bodySmall),
            if (followed.url.isNotEmpty) SelectableText(followed.url, style: text.bodySmall),
            // Walk 10: the card said what to do, with nothing to do it with. A rewritten
            // history is taken only by a second, deliberate act; a refused signature has no button.
            if (followed.outcome == 'REWRITTEN' && followed.url.isNotEmpty) ...<Widget>[
              const SizedBox(height: Space.small),
              OutlinedButton(
                key: ValueKey<String>('accept-rewrite ${machine.name}/${project.name}'),
                onPressed: resolved
                    ? null
                    : acceptAttentionRewriteCommand(run: () => unawaited(_acceptTheRewrite(context))).run,
                child: const Text('Take the rewritten history'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

extension on _NotFollowing {
  /// Takes the rewritten history once the person agreed, with what the machine says about it.
  Future<void> _acceptTheRewrite(BuildContext context) async {
    final agreed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('accept-rewrite-dialog'),
        title: Text('Take the rewritten history of ${project.name}?'),
        content: SizedBox(
          width: Sizes.dialogMedium,
          child: Text(
            '${machine.name} then works with ${followed.refused.isEmpty ? 'the newest commit' : followed.refused}, '
            'which does not descend from what it took before. Do this only if you rewrote the history '
            'yourself (an amend and a force push); otherwise somebody else did.',
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Leave it')),
          FilledButton(
            key: const Key('accept-rewrite-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Take it'),
          ),
        ],
      ),
    );
    if (agreed != true) return;
    try {
      final answer = await fleet.backend.follow(project.name, followed.url, acceptRewrite: true);
      fleet.say('${project.name}: ${answer.words}');
    } on VarlinkException catch (refusal) {
      fleet.say('${project.name}: ${refusal.parameters['message'] ?? refusal.simpleName}');
    }
    await fleet.refresh();
  }
}

/// An operation somebody started that failed, waiting until they have opened it.
class _FailedOperation extends StatelessWidget {
  const _FailedOperation({required this.operation, required this.onOpen});

  final Operation operation;

  /// Opens what it printed.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SizedBox(
      width: Sizes.tile,
      child: Card(
        key: ValueKey<String>('failed-operation ${operation.id}'),
        color: scheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.all(Space.normal),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  OperationMark(operation: operation),
                  const SizedBox(width: Space.small),
                  Expanded(child: Text(operation.title, style: text.bodyLarge)),
                ],
              ),
              NeedsMachine(operation.machine),
              Text(operation.summary, style: text.bodySmall),
              TextButton(
                onPressed: onOpen == null ? null : openAttentionOperationCommand(run: onOpen!).run,
                child: const Text('Open what it printed'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Questions about blocked connections a machine dropped before they were seen.
class _MissedQuestions extends StatelessWidget {
  const _MissedQuestions({required this.machine, required this.count, required this.onSeen});

  final Machine machine;
  final int count;
  final VoidCallback? onSeen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: ValueKey<String>('missed-questions ${machine.name}'),
      child: ListTile(
        leading: Icon(Icons.help_center_outlined, color: scheme.error),
        title: Text(
          'The machine dropped ${count == 1 ? 'a question' : '$count questions'} about a blocked '
          'connection before it was seen',
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NeedsMachine(machine.name),
            const Text(
              'A dropped question is not asked again: work may be waiting for an answer until it '
              'runs out. Look at its work under Work, or at the connections it is blocked on.',
            ),
          ],
        ),
        trailing: TextButton(
          key: ValueKey<String>('missed-questions-seen ${machine.name}'),
          onPressed: onSeen == null ? null : missedQuestionsSeenCommand(run: onSeen!).run,
          child: const Text('Seen'),
        ),
      ),
    );
  }
}

/// A machine that is not answering, said about the machine: it is not work, so it is not a tile.
class _MachineNotice extends StatelessWidget {
  const _MachineNotice({required this.machine, required this.words, required this.retry, required this.onSeen});

  final Machine machine;
  final String words;
  final Command retry;
  final VoidCallback? onSeen;

  @override
  Widget build(BuildContext context) => Card(
    key: ValueKey('machine-notice ${machine.name}'),
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: Padding(
      padding: const EdgeInsets.all(Space.normal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(words),
          NeedsMachine(machine.name),
          Wrap(
            spacing: Space.small,
            children: [
              _RowCommand(retry),
              TextButton(
                key: ValueKey('notice-seen ${machine.name}'),
                onPressed: onSeen == null ? null : machineNoticeSeenCommand(run: onSeen!).run,
                child: const Text('Seen'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Which tiles below it are folded open, where tiles fold at all: a page with many tiles shows each
/// by its work, its machine and its state's mark, and the rest only when it is opened
/// (walk 9). A tile that asks something of a person is never folded.
class TileFolding extends InheritedWidget {
  /// Constructor taking which tiles are open and how one is opened or closed.
  const TileFolding({required this.open, required this.toggle, required super.child, super.key});

  /// The tiles opened, by machine and work.
  final Set<String> open;

  /// Opens or closes one.
  final void Function(String tile) toggle;

  /// The folding above [context], or null where tiles do not fold.
  static TileFolding? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<TileFolding>();

  @override
  bool updateShouldNotify(TileFolding oldWidget) => open != oldWidget.open;
}

/// One tile. Its state is legible without opening it, and it carries its own actions.
class TaskTile extends StatelessWidget {
  /// Constructor taking the tile and what it can do.
  const TaskTile({
    required this.tile,
    required this.actions,
    required this.onDecide,
    required this.onReview,
    this.onPutAway,
    this.resolved = false,
    this.selected = false,
    this.onSelect,
    this.onOpen,
    this.highlight,
    this.onShown,
    this.onEnlargeConsole,
    super.key,
  });

  /// Whether this snapshot has been resolved and its actions must remain disabled.
  final bool resolved;

  /// Shows what its agent writes on the whole right side. Without it, the tile has no console.
  final void Function(Tile tile)? onEnlargeConsole;

  /// What the tile is about.
  final Tile tile;

  /// What its work can be told to do.
  final List<Command> actions;

  /// Answers a question, on the machine that asked it.
  final void Function(Tile tile, Prompt prompt, {required bool allow}) onDecide;

  /// Opens the gate for the work's project.
  final void Function(Tile tile) onReview;

  /// Puts away the outcome of a question, on the machine that asked it. No button without it.
  final void Function(Tile tile, Prompt prompt)? onPutAway;

  /// Whether its work is the one selected.
  final bool selected;

  /// Selects its work.
  final VoidCallback? onSelect;

  /// Opens its work over the frame.
  final VoidCallback? onOpen;

  /// The command the finder went to.
  final String? highlight;

  /// Called once the menu opened on [highlight].
  final VoidCallback? onShown;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final task = tile.task;
    final urgent = tile.demand == Demand.question;
    final first = tile.questions.isEmpty ? null : tile.questions.first;
    final answering = first != null && tile.fleet.clearance.answering(first);
    // Nothing on a machine that is not answering can be told anything.
    final answers = !resolved && tile.fleet.reachability == Reachability.connected;
    final aboutTheDeadline = first == null ? null : _deadlineLine(first);
    // The tile's button and its menu run the same command, so they cannot disagree about it.
    final session = actions.where((command) => command.id == 'work.session').firstOrNull;
    final folding = TileFolding.maybeOf(context);
    final id = '${tile.machine.name}/${task?.name ?? first?.task ?? ''}';
    final asks = first != null || urgent || (task?.hasWorkWaiting ?? false) || tile.demand == Demand.ended;
    final folds = folding != null && !asks;
    final folded = folds && !folding.open.contains(id);

    final card = SizedBox(
      width: Sizes.tile,
      child: GestureDetector(
        onSecondaryTapDown: resolved || actions.isEmpty
            ? null
            : (details) => showCommandMenu(context, details.globalPosition, actions),
        child: Card(
          key: ValueKey<String>('tile ${tile.machine.name} ${task?.name ?? first?.task ?? ''}'),
          // A stopped piece of work is greyed as a whole, not only by its mark (walk 8).
          color: urgent
              ? scheme.surfaceContainerLow
              : (tile.demand == Demand.stopped ? scheme.surfaceContainerHighest : null),
          shape: selected
              ? RoundedRectangleBorder(
                  side: BorderSide(color: scheme.primary, width: Sizes.selectedBorder),
                  borderRadius: BorderRadius.circular(Radii.medium),
                )
              : null,
          child: InkWell(
            onTap: onSelect,
            child: Padding(
              padding: const EdgeInsets.all(Space.normal),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Headed by the work, which tells tiles apart; the machine is the same for every tile
                  // on a machine's page (walk 8). It is said under it all the same: two
                  // machines can serve the same socket path, and only the name tells them apart.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(top: Space.small, right: Space.small),
                        child: _StateMark(tile.demand, scheme),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            // Selectable, because the name is what somebody types into `porelo` on the machine.
                            if (task != null || first != null)
                              SelectableText(
                                task == null ? first!.task : (task.label.isEmpty ? task.name : task.label),
                                key: const Key('tile-what'),
                                style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            KeyedSubtree(key: const Key('tile-machine'), child: NeedsMachine(tile.machine.name)),
                            if (!folded) Text(_headline(tile), key: const Key('tile-headline'), style: text.titleSmall),
                          ],
                        ),
                      ),
                      if (folds)
                        IconButton(
                          key: ValueKey<String>('tile-fold ${task?.name ?? first?.task ?? ''}'),
                          icon: Icon(folded ? Icons.expand_more : Icons.expand_less, size: Sizes.rowIcon),
                          tooltip: folded ? 'Show more' : 'Show less',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => folding.toggle(id),
                        ),
                      if (onOpen != null && task != null)
                        IconButton(
                          key: const Key('tile-open'),
                          icon: const Icon(Icons.chevron_right, size: Sizes.rowIcon),
                          tooltip: 'Open ${task.name}',
                          visualDensity: VisualDensity.compact,
                          onPressed: onOpen,
                        ),
                      if (actions.isNotEmpty)
                        CommandMenu(
                          enabled: !resolved,
                          // Its own per work, so a walk can point at one tile's menu among several.
                          key: ValueKey<String>('tile-menu ${task?.name ?? first?.task ?? ''}'),
                          commands: actions,
                          tooltip: 'What ${task?.name ?? 'this'} can be told to do',
                          highlight: highlight,
                          onShown: onShown,
                        ),
                    ],
                  ),
                  // What the build of its last push did, as the machine reads it from the forge: in a
                  // line of its own under the head, folded or not, since a build is a step that matters;
                  // the commit, the jobs and the age only when opened.
                  if (task != null)
                    if (BuildsSaid.onTheTile(task) case final said?) _BuildLine(said, scheme, folded: folded),
                  // Folded, the tile is its work, its machine and its mark; the rest when opened.
                  if (task != null && task.phase.isNotEmpty)
                    Text(task.phase, key: const Key('tile-phase'), style: text.bodySmall),
                  if (!folded) ...<Widget>[
                    // What its agent writes, small, while there is an agent to write.
                    if (task != null && onEnlargeConsole != null && (task.running || task.agentEnded != null))
                      TileConsole(
                        key: ValueKey<String>('tile-console-of ${tile.machine.name} ${task.name}'),
                        backend: tile.fleet.backend,
                        task: task.name,
                        // `since` is when its current state began, so a start only while it runs.
                        startedAt: task.running ? task.startedAt : null,
                        inATerminal: task.mode != Mode.unattended,
                        // Work in a terminal is enlarged into its session itself, as "Work in it by hand"
                        // does (walk 10: the tile's "Open" is the work's details, not its terminal).
                        onEnlarge: task.mode != Mode.unattended && session != null && session.available
                            ? session.run
                            : () => onEnlargeConsole!(tile),
                      ),
                    // What an unattended run came to, under what it wrote, and where to go from here.
                    if (task case Task(mode: Mode.unattended, agentEnded: final ended?))
                      Text(_cameTo(task, ended), key: const Key('tile-run-ended'), style: text.bodyMedium),
                    // Why it is down, when a restart of its machine took it: in the machine's words.
                    if (task != null && task.takenDownByARestart)
                      Text(task.startDetail, key: const Key('tile-why-down'), style: text.bodySmall),
                    if (tile.inferred)
                      Text(
                        'a guess, not a question',
                        key: const Key('tile-inferred'),
                        style: text.labelSmall?.copyWith(fontStyle: FontStyle.italic),
                      ),
                    if (aboutTheDeadline != null)
                      Text(aboutTheDeadline, key: const Key('tile-deadline'), style: text.bodySmall),
                    // What was attempted and which rule stopped it: a destination alone does not say
                    // whose it was, and five tasks can be asking at once.
                    if (first != null) ...<Widget>[
                      Text(
                        first.shown,
                        key: const Key('blocked-destination'),
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                      ),
                      Text(
                        '${first.protocol}${first.prefix.isEmpty ? '' : ' · stopped by ${first.prefix}'}',
                        style: text.bodySmall,
                      ),
                      if (tile.fleet.clearance.askedBefore(first))
                        Text(
                          'This was let through before. A decision is remembered per address, so a '
                          'host that answers on several addresses asks again for each one.',
                          key: const Key('asked-before'),
                          style: text.bodySmall,
                        ),
                    ],
                    const SizedBox(height: Space.small),
                    if (task != null && task.label.isNotEmpty)
                      SelectableText(task.name, key: const Key('tile-name'), style: text.bodySmall),
                    Text(_where(tile), key: const Key('tile-where'), style: text.bodySmall),
                    // Said here as well: the status line is easy to miss from a tile.
                    if (task != null && tile.fleet.saidAbout(task.name) != null)
                      Text(tile.fleet.saidAbout(task.name)!, key: const Key('tile-said'), style: text.bodySmall),
                    if (task != null && task.activity == Activity.waiting && task.waitingFor.isNotEmpty)
                      Text(
                        'waiting on ${task.waitingFor}',
                        key: const Key('waiting-for'),
                        style: text.bodySmall?.copyWith(color: scheme.error, fontWeight: FontWeight.w600),
                      ),
                    // Nothing asks and nothing is refused for this one, and somebody chose that.
                    if (task != null && task.unenforced)
                      Tooltip(
                        message:
                            'Nothing is enforcing what this work may reach. '
                            'No connection will be refused and nothing will be asked.',
                        child: Chip(
                          key: const Key('unenforced'),
                          avatar: Icon(Icons.gpp_bad_outlined, size: Sizes.rowIcon, color: scheme.error),
                          label: const Text('unenforced'),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: scheme.surfaceContainerLow,
                        ),
                      ),
                    // The last answer, so a question that ran out does not quietly disappear.
                    if (first == null && tile.settled != null)
                      Text(_settledWords(tile.settled!), key: const Key('tile-settled'), style: text.bodySmall),
                    // Until then it stays on what needs a person, so nobody misses it.
                    if (first == null && tile.settled != null && onPutAway != null)
                      TextButton(
                        key: const Key('tile-put-away'),
                        onPressed: resolved
                            ? null
                            : putAwayQuestionCommand(run: () => onPutAway!(tile, tile.settled!)).run,
                        child: const Text('Got it'),
                      ),
                    if (first != null || (session?.available ?? false) || (task?.hasWorkWaiting ?? false)) ...<Widget>[
                      const SizedBox(height: Space.small),
                      Wrap(
                        spacing: Space.small,
                        children: <Widget>[
                          if (first != null) ...<Widget>[
                            TextButton(
                              key: const Key('tile-let-through'),
                              onPressed: answering || !answers
                                  ? null
                                  : questionDecisionCommand(
                                      allow: true,
                                      run: () => onDecide(tile, first, allow: true),
                                    ).run,
                              child: const Text('Let it through'),
                            ),
                            TextButton(
                              key: const Key('tile-keep-blocked'),
                              onPressed: answering || !answers
                                  ? null
                                  : questionDecisionCommand(
                                      allow: false,
                                      run: () => onDecide(tile, first, allow: false),
                                    ).run,
                              child: const Text('Keep it blocked'),
                            ),
                          ],
                          if (session != null && session.available)
                            TextButton(
                              key: const Key('tile-attach'),
                              onPressed: session.run,
                              child: Text(session.label),
                            ),
                          if (task?.hasWorkWaiting ?? false)
                            TextButton(
                              key: const Key('tile-review'),
                              onPressed: answers ? reviewAttentionWorkCommand(run: () => onReview(tile)).run : null,
                              child: const Text('Review at the gate'),
                            ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return selected ? KeyedSubtree(key: const Key('selected-row'), child: card) : card;
  }

  /// What [task]'s unattended run came to, from what the machine says of its end and its gate.
  static String _cameTo(Task task, AgentEnded ended) => switch ((ended.finished, task.hasWorkWaiting)) {
    (true, true) => 'Finished: its work waits at the gate, to be reviewed there.',
    (false, true) => 'Stopped before its end, and its work waits at the gate: its output above says why.',
    (true, false) when ended.unpushed > 0 =>
      'Finished, but ${ended.unpushed} changed ${ended.unpushed == 1 ? 'file' : 'files'} never reached the gate.',
    (true, false) => 'Finished, and nothing waits at the gate: its output above says what it did.',
    (false, false) => 'Stopped before its end, and nothing waits at the gate: its output above says why.',
  };

  static String _settledWords(Prompt prompt) => prompt.expired
      ? '${prompt.shown} ran out — it stays blocked'
      : prompt.verdict == 'allow'
      ? '${prompt.shown} is now reachable — the attempt that was refused is gone'
      : '${prompt.shown} was kept blocked';

  static String _headline(Tile tile) {
    final task = tile.task;
    final since = task == null ? null : howLong(task);
    final forHowLong = since == null ? '' : ' for $since';
    return switch (tile.demand) {
      Demand.question when tile.questions.isNotEmpty => _question(tile.questions),
      Demand.question =>
        'Waiting on '
            '${(task?.waitingFor ?? '').isEmpty ? 'an answer' : task!.waitingFor}$forHowLong',
      // In the agent's or the provider's own words: what ended it is the one thing to know here.
      Demand.ended => task?.agentEnded?.words ?? 'Its agent ended',
      Demand.gate => 'Its work waits for review',
      Demand.working => 'Working$forHowLong',
      Demand.quiet => 'Quiet$forHowLong',
      // Only that it runs: nothing here can see what it is doing, and nothing claims to.
      Demand.unseen => 'Running$forHowLong',
      Demand.stopped => 'Not running',
    };
  }

  /// Time left when the machine says when it runs out; how long it has waited when it does not.
  static String _question(List<Prompt> questions) {
    final first = questions.first;
    final more = questions.length - 1;
    final ends = first.expiresAt;
    final left = howLongUntil(ends);
    final since = howLongSince(DateTime.tryParse(first.at));
    final when = ends != null
        ? (left == null ? ' · out of time' : ' · $left left')
        : (since == null ? '' : ' · blocked for $since');
    return 'Asks to reach ${first.shown}${more > 0 ? ' and $more more' : ''}$when';
  }

  /// What to say about when it runs out, or null when the headline already says how long is left.
  static String? _deadlineLine(Prompt question) {
    if (question.neverRunsOut) return 'This one does not run out.';
    final ends = question.expiresAt;
    if (ends == null) {
      return 'The machine gives up on its own timeout, and does not say when.';
    }
    return howLongUntil(ends) == null ? 'Its time is up; the machine may already have given up on it.' : null;
  }

  static String _where(Tile tile) {
    final task = tile.task;
    final project = task == null ? null : tile.fleet.projectOf(task);
    // Named once there is more than one to tell apart; a project of one repository says nothing new.
    final repository = task == null || project == null || project.repositories.length < 2
        ? null
        : project.repositoryOf(task);
    return <String>[
      if (tile.machine.host.isNotEmpty) tile.machine.host,
      if (task != null && task.project.isNotEmpty) task.project,
      if (repository != null) 'in $repository',
      if (task != null && task.agent.isNotEmpty)
        task.provider.isEmpty ? task.agent : '${task.agent} via ${task.provider}',
    ].join(' · ');
  }
}

/// A piece of work's state at a glance, in colour and in shape: filled where it works or needs a
/// person, a ring where it waits or is stopped. Red only for needing a person, so it never means two
/// things.
class _StateMark extends StatelessWidget {
  const _StateMark(this.demand, this.scheme);

  final Demand demand;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final states = StateColours.of(scheme);
    final (colour, filled, words) = switch (demand) {
      Demand.question || Demand.ended || Demand.gate => (scheme.error, true, 'Needs you'),
      Demand.working => (states.working, true, 'Working'),
      Demand.unseen => (states.working, false, 'Running'),
      Demand.quiet => (states.waiting, false, 'Waiting'),
      Demand.stopped => (states.stopped, false, 'Stopped'),
    };
    return Tooltip(
      message: words,
      child: Container(
        key: ValueKey<String>('tile-state ${demand.name}'),
        width: Sizes.dot + Space.tight,
        height: Sizes.dot + Space.tight,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? colour : null,
          border: Border.all(color: colour, width: Sizes.selectedBorder),
        ),
      ),
    );
  }
}

/// A work's build in a word that stands out, with a mark whose shape says it without colour too.
class _BuildLine extends StatelessWidget {
  const _BuildLine(this.said, this.scheme, {required this.folded});

  final BuildLine said;
  final ColorScheme scheme;
  final bool folded;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final states = StateColours.of(scheme);
    final (icon, colour) = switch (said.look) {
      BuildLook.passed => (Icons.check_circle, states.working),
      BuildLook.failed => (Icons.cancel, scheme.error),
      BuildLook.running => (Icons.timelapse, states.waiting),
      BuildLook.none => (Icons.remove_circle_outline, states.stopped),
    };
    return Padding(
      key: const Key('tile-build'),
      padding: const EdgeInsets.only(top: Space.small),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                icon,
                key: ValueKey<String>('tile-build-look ${said.look.name}'),
                color: colour,
                size: Sizes.rowIcon,
              ),
              const SizedBox(width: Space.small),
              Flexible(
                child: Text(
                  said.headline,
                  key: const Key('tile-build-headline'),
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (!folded) Text(said.detail, key: const Key('tile-build-detail'), style: text.bodySmall),
        ],
      ),
    );
  }
}
