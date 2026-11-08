import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/machines.dart';
import '../app/organization_source.dart';
import '../app/shell_model.dart';
import 'machine_tree.dart';
import 'tokens.dart';
import 'window_size.dart';

/// Counts exactly the projects the corresponding page lists.
int projectsInRail(OrganizationView? view, {required int onMachines, bool fromOrganization = false}) =>
    !fromOrganization ? onMachines : (view == null ? 0 : view.projects.where(view.isMine).length);

/// A machine entry with its last observed connection or preparation state.
typedef RailMachine = ({Machine machine, String? state});

/// The folding navigation tree, with refresh and the global stop kept at its foot.
class ShellRail extends StatefulWidget {
  /// Takes the places, observations and navigation actions of the frame.
  const ShellRail({
    required this.section,
    required this.running,
    this.work,
    required this.needing,
    required this.machines,
    required this.projects,
    this.forges,
    this.machineEntries = const [],
    this.machinesWithSections,
    this.organizations = const [],
    this.organizationsKnown = true,
    this.place,
    this.foldedOpen = const {},
    this.onPlace,
    this.onFold,
    required this.width,
    required this.onGo,
    required this.onRefresh,
    required this.onStopEverywhere,
    super.key,
  });

  /// The current page kind, also used by callers without an exact place.
  final Section section;

  /// The exact selected place.
  final ShellPlace? place;

  /// Open branches, keyed by place identity.
  final Set<String> foldedOpen;

  /// Machines in the same order as the frame lists them.
  final List<RailMachine> machineEntries;

  /// Names with a watched daemon whose tools can be safely selected.
  final Set<String>? machinesWithSections;

  /// Organizations read; the shape also accepts several.
  final List<OrganizationView> organizations;

  /// Whether an empty organization list is a read absence rather than a pending read.
  final bool organizationsKnown;

  /// Observed totals; null means they cannot currently be read.
  final int? running, work, needing, machines, projects, forges;

  /// The width reserved for the tree.
  final double width;

  /// Navigates to a top-level page for callers without an exact place.
  final ValueChanged<Section> onGo;

  /// Chooses a place, keeping parents open in a phone drawer.
  final void Function(ShellPlace place, bool branch)? onPlace;

  /// Folds a branch without choosing it.
  final ValueChanged<String>? onFold;

  /// Asks every machine again.
  final VoidCallback onRefresh;

  /// Opens the global stop confirmation, absent when no machine answers.
  final VoidCallback? onStopEverywhere;

  @override
  State<ShellRail> createState() => _ShellRailState();
}

class _TreeRow {
  const _TreeRow(
    this.place,
    this.label, {
    this.depth = 0,
    this.branch = false,
    this.icon,
    this.selectedIcon,
    this.count,
    this.countKey,
    this.badge = false,
    this.state,
  });
  final ShellPlace place;
  final String label;
  final int depth;
  final bool branch, badge;
  final IconData? icon, selectedIcon;
  final int? count;
  final String? countKey, state;
}

class _ShellRailState extends State<ShellRail> {
  final _focus = FocusNode(debugLabel: 'Navigation tree');
  final _rows = <String, GlobalKey>{};
  int _cursor = 0;
  bool _focused = false;
  String? _revealed;
  Set<String> _lastFolds = {};

  List<_TreeRow> get rows => [
    _TreeRow(
      const ShellPlace(Section.work),
      'Work',
      icon: Icons.play_circle_outline,
      selectedIcon: Icons.play_circle,
      count: widget.work,
      countKey: 'rail-work-count',
    ),
    _TreeRow(
      const ShellPlace(Section.attention),
      'Needs you',
      icon: Icons.notifications_active_outlined,
      selectedIcon: Icons.notifications_active,
      count: widget.needing,
      badge: true,
    ),
    _TreeRow(
      const ShellPlace(Section.machines),
      'My machines',
      branch: true,
      icon: Icons.dns_outlined,
      selectedIcon: Icons.dns,
      count: widget.machines,
      countKey: 'rail-machines-count',
    ),
    if (widget.foldedOpen.contains('machines'))
      for (final entry in widget.machineEntries) ...[
        _TreeRow(
          ShellPlace(Section.machine, machine: entry.machine),
          entry.machine.name,
          depth: 1,
          branch: widget.machinesWithSections?.contains(entry.machine.name) ?? true,
          state: entry.state,
        ),
        if ((widget.machinesWithSections?.contains(entry.machine.name) ?? true) &&
            widget.foldedOpen.contains(ShellPlace.machineKey(entry.machine.name)))
          for (final section in MachineSection.values)
            _TreeRow(
              ShellPlace(Section.machine, machine: entry.machine, machineSection: section),
              section.label,
              depth: 2,
            ),
      ],
    _TreeRow(
      const ShellPlace(Section.forges),
      'My forges',
      icon: Icons.hub_outlined,
      selectedIcon: Icons.hub,
      count: widget.forges,
      countKey: 'rail-forges-count',
    ),
    _TreeRow(
      const ShellPlace(Section.projects),
      'My projects',
      icon: Icons.folder_outlined,
      selectedIcon: Icons.folder,
      count: widget.projects,
      countKey: 'rail-projects-count',
    ),
    const _TreeRow(ShellPlace(Section.cards), 'My cards & keys', icon: Icons.key_outlined, selectedIcon: Icons.key),
    _TreeRow(
      const ShellPlace(Section.organizations),
      'Organizations',
      branch: widget.organizations.isNotEmpty,
      icon: Icons.apartment_outlined,
      selectedIcon: Icons.apartment,
      count: widget.organizationsKnown ? widget.organizations.length : null,
      countKey: 'rail-organizations-count',
    ),
    if (widget.foldedOpen.contains('organizations'))
      for (final organization in widget.organizations) ...[
        _TreeRow(
          ShellPlace(Section.organization, organization: organization.name),
          organization.name,
          depth: 1,
          branch: true,
        ),
        if (widget.foldedOpen.contains(ShellPlace.organizationKey(organization.name)))
          for (final section in OrganizationSection.values)
            _TreeRow(
              ShellPlace(Section.organization, organization: organization.name, organizationSection: section),
              section.label,
              depth: 2,
            ),
      ],
  ];

  String get selected => widget.place?.key ?? widget.section.name;

  void _scrollTo(String key) => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    final context = _rows[key]?.currentContext;
    if (context != null) Scrollable.ensureVisible(context, alignment: Sizes.treeScrollAlignment);
  });

  void _choose(_TreeRow row) {
    if (widget.onPlace case final choose?) {
      choose(row.place, row.branch);
    } else {
      widget.onGo(row.place.section);
    }
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed || keyboard.isAltPressed || keyboard.isMetaPressed) return KeyEventResult.ignored;
    final entries = rows;
    _cursor = _cursor.clamp(0, entries.length - 1).toInt();
    final row = entries[_cursor];
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowUp) {
      setState(
        () => _cursor = (_cursor + (key == LogicalKeyboardKey.arrowDown ? 1 : -1)).clamp(0, entries.length - 1).toInt(),
      );
      _scrollTo(entries[_cursor].place.key);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      if (row.branch && !widget.foldedOpen.contains(row.place.key)) widget.onFold?.call(row.place.key);
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      if (row.branch && widget.foldedOpen.contains(row.place.key)) {
        widget.onFold?.call(row.place.key);
      } else if (row.place.ancestors.isNotEmpty) {
        final parent = entries.indexWhere((entry) => entry.place.key == row.place.ancestors.last);
        if (parent >= 0) setState(() => _cursor = parent);
      }
    } else if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
      _choose(row);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final entries = rows;
    if (_revealed != selected || !_sameFolds(widget.foldedOpen)) {
      final chosen = entries.indexWhere((row) => row.place.key == selected);
      if (_revealed != selected && chosen >= 0) _cursor = chosen;
      _revealed = selected;
      _lastFolds = Set.of(widget.foldedOpen);
      _scrollTo(selected);
    }
    final phone = WindowSize.fromContext(context) == WindowSize.compact;
    return SizedBox(
      width: widget.width,
      child: Column(
        children: [
          if (phone)
            Padding(
              padding: const EdgeInsets.all(Space.normal),
              child: Text('Porelo', style: Theme.of(context).textTheme.titleLarge),
            ),
          Expanded(
            child: Focus(
              key: const Key('navigation-tree-focus'),
              focusNode: _focus,
              onKeyEvent: _key,
              autofocus: phone,
              onFocusChange: (value) => setState(() => _focused = value),
              child: SingleChildScrollView(
                key: const Key('shell-rail'),
                child: Column(
                  children: [
                    for (var index = 0; index < entries.length; index++) ...[
                      if (entries[index].place.section == Section.machines && entries[index].depth == 0) ...[
                        const Divider(height: Sizes.divider),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(Space.normal, Space.small, Space.normal, Space.tight),
                          child: Text('Set up', style: Theme.of(context).textTheme.labelMedium),
                        ),
                      ],
                      _row(context, entries[index], index),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Space.small),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Tooltip(
                  message: 'Ask every machine again, now (Shift+F5)',
                  child: TextButton.icon(
                    key: const Key('refresh-all'),
                    onPressed: widget.onRefresh,
                    style: TextButton.styleFrom(
                      minimumSize: Size(Sizes.touchTarget, WindowSize.fromContext(context).treeRowHeight),
                    ),
                    icon: const Icon(Icons.refresh, size: Sizes.rowIcon),
                    label: const Text('Refresh'),
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(minHeight: WindowSize.fromContext(context).treeRowHeight),
                  child: StopEverywhere(onPressed: widget.onStopEverywhere),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, _TreeRow row, int index) {
    final theme = Theme.of(context);
    final chosen = selected == row.place.key;
    final ancestor = widget.place?.ancestors.contains(row.place.key) ?? false;
    final open = widget.foldedOpen.contains(row.place.key);
    final treeKey = row.place.key;
    final globalKey = _rows.putIfAbsent(treeKey, GlobalKey.new);
    final height = WindowSize.fromContext(context).treeRowHeight;
    Widget? count;
    if (row.countKey != null || row.badge) {
      final value = row.count;
      count = Tooltip(
        message: value == null
            ? 'Not read: no machine is answering or the list has not been read'
            : row.badge
            ? '$value need you'
            : row.place.section == Section.work
            ? '${widget.running ?? '?'} running'
            : '$value',
        child: row.badge && value != null
            ? Badge(
                key: const Key('needing-count-badge'),
                isLabelVisible: value > 0,
                label: Text(value > 99 ? '99+' : '$value'),
              )
            : Text(value == null ? '?' : '$value', key: row.countKey == null ? null : Key(row.countKey!)),
      );
    }
    return KeyedSubtree(
      key: globalKey,
      child: Semantics(
        button: true,
        focusable: true,
        selected: chosen,
        focused: _focused && _cursor == index,
        expanded: row.branch ? open : null,
        label: row.state == null
            ? row.depth == 1 && row.place.machine != null
                  ? '${row.label}, Connected'
                  : row.label
            : '${row.label}, ${row.state}',
        child: Material(
          color: chosen ? theme.colorScheme.secondaryContainer : Colors.transparent,
          child: InkWell(
            key: ValueKey('rail $treeKey'),
            canRequestFocus: false,
            onTap: () {
              _cursor = index;
              _focus.requestFocus();
              _choose(row);
            },
            child: Container(
              constraints: BoxConstraints(minHeight: height),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _focused && _cursor == index ? theme.colorScheme.primary : Colors.transparent,
                  width: Sizes.focusStroke,
                ),
              ),
              padding: EdgeInsets.only(left: Space.small + row.depth * Space.normal, right: Space.small),
              child: Row(
                children: [
                  if (row.icon != null) ...[
                    Icon(chosen ? row.selectedIcon : row.icon, size: Sizes.rowIcon),
                    const SizedBox(width: Space.small),
                  ],
                  Expanded(
                    child: Tooltip(
                      message: row.label,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: chosen || ancestor ? FontWeight.bold : null,
                            ),
                          ),
                          if (row.state?.contains('\n') ?? false)
                            Text(
                              row.state!.substring(row.state!.indexOf('\n') + 1),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (row.state case final state?) Tooltip(message: state, child: _stateMark(theme, state)),
                  if (count != null)
                    Padding(
                      padding: const EdgeInsets.only(left: Space.tight),
                      child: count,
                    ),
                  if (row.branch)
                    ExcludeFocus(
                      child: IconButton(
                        key: ValueKey('fold $treeKey'),
                        tooltip: '${open ? 'Fold' : 'Unfold'} ${row.label}',
                        constraints: BoxConstraints(minWidth: height, minHeight: height),
                        icon: Icon(open ? Icons.expand_more : Icons.chevron_right, size: Sizes.rowIcon),
                        onPressed: () => widget.onFold?.call(treeKey),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _sameFolds(Set<String> other) => other.length == _lastFolds.length && other.containsAll(_lastFolds);

  Widget _stateMark(ThemeData theme, String state) {
    final colours = StateColours.of(theme.colorScheme);
    final failed = state.startsWith('Not answering') || state == 'Interrupted';
    final stopped = state == 'Stopped' || state == 'Not connected yet';
    return Icon(
      failed
          ? Icons.cloud_off_outlined
          : stopped
          ? Icons.pause_circle_outline
          : Icons.pending_outlined,
      size: Sizes.mark,
      color: failed
          ? theme.colorScheme.error
          : stopped
          ? colours.stopped
          : colours.waiting,
    );
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }
}
