import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:guided_walk/guided_walk.dart';
import 'package:porelo_frontend/client.dart';

import '../app/conversation.dart';
import '../app/commands.dart';
import '../app/desk.dart';
import '../app/element_desktop.dart';
import '../app/fleet_backend.dart';
import '../app/homeserver_forwards.dart';
import '../app/machines.dart';
import '../app/settings.dart';
import 'dialog_scroll.dart';
import 'tokens.dart';

/// Shows [project]'s conversation, who has joined it, and lets a person join.
Future<void> showProjectMessages(
  BuildContext context, {
  required FleetBackend backend,
  required Machine machine,
  required Project project,
  required Settings settings,
  HomeserverForwards? forwards,
  RoomAdmission Function()? admission,
  Listenable? admissionChanges,
  bool Function()? hostReached,
  Listenable? hostChanges,
}) async {
  final conversation = ProjectConversation(
    backend,
    machine,
    project,
    settings: settings,
    forwards: forwards,
    admission: admission,
    admissionChanges: admissionChanges,
    hostReached: hostReached,
    hostChanges: hostChanges,
  );
  unawaited(conversation.load());
  await showDialog<void>(
    context: context,
    builder: (_) => MessagesDialog(conversation: conversation),
  );
  conversation.dispose();
}

/// A project's conversation: where it is, whether this machine can carry it, and a way in for a person.
class MessagesDialog extends StatefulWidget {
  /// Constructor taking the conversation, and for a test the Element it looks for.
  const MessagesDialog({required this.conversation, this.element, super.key});

  /// The project's conversation, and who is in it.
  final ProjectConversation conversation;

  /// This computer's Element, or null for the one installed here.
  final ElementDesktop? element;

  @override
  State<MessagesDialog> createState() => _MessagesDialogState();
}

class _MessagesDialogState extends State<MessagesDialog> {
  final TextEditingController _person = TextEditingController();

  /// Whether Element is installed here, or null while it is looked for: asked only on a host.
  bool? _elementHere;

  /// Whether Element starts with its own profile for the host, beside any Element already open.
  bool _separate = true;

  /// Why Element could not be started, or null.
  String? _elementProblem;

  /// The admitted login chosen to join as, or null for the person's own.
  String? _chosen;

  ElementDesktop get _element => widget.element ?? elementDesktop;

  @override
  void initState() {
    super.initState();
    if (widget.conversation.hostHomeserver != null) unawaited(_lookForElement());
  }

  Future<void> _lookForElement() async {
    final here = await _element.installed();
    if (!mounted) return;
    setState(() => _elementHere = here);
  }

  @override
  void dispose() {
    _person.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.conversation,
    builder: (context, _) {
      final model = widget.conversation;
      final messages = model.project.messages;
      final text = Theme.of(context).textTheme;
      final scheme = Theme.of(context).colorScheme;
      final members = model.members;
      final joined = model.joined;
      final joinedAs = model.joinedAs;
      final hostHomeserver = model.hostHomeserver;
      final admission = model.admission;
      final admitted = admission is AdmittedLogins ? admission.logins : null;
      final chosen = admitted == null
          ? _person.text.trim()
          : admitted.contains(_chosen)
          ? _chosen!
          : (admission as AdmittedLogins).yours ?? '';
      final join = joinMessagesCommand(
        person: chosen,
        busy: model.busy,
        nobodyAdmitted: admitted != null && admitted.isEmpty,
        choosing: admitted != null,
        run: () => unawaited(model.join(chosen)),
      );
      // On a host the homeserver manages its people itself: a join here could only be refused.
      final offersJoin = hostHomeserver == null && joined == null && joinedAs == null;
      // An invited account keeps its own password: there is none here to make anew, after Done and while the forward
      // is down too, so the remembered invitation decides.
      final offersReset =
          hostHomeserver == null &&
          !model.invited &&
          (joinedAs != null || (joined == null && model.alreadyJoined != null));
      final reset = newMessagePasswordCommand(
        busy: model.busy,
        run: () => unawaited(joinedAs != null ? model.newPassword() : model.join(model.alreadyJoined!, reset: true)),
      );
      return AlertDialog(
        key: const Key('messages-dialog'),
        title: Text('Messages of ${model.project.name}'),
        content: SizedBox(
          width: Sizes.dialog,
          child: DialogScroll(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (messages != null) ..._where(context, messages),
                // Joined before: still reachable, and said so, without joining again (walk 10).
                if (model.joined == null && model.forwarded != null && hostHomeserver == null)
                  Text(
                    'A Matrix client here reaches its homeserver at http://127.0.0.1:${model.forwarded}, forwarded while '
                    'this window runs.',
                    key: const Key('homeserver-forwarded'),
                    style: text.bodySmall,
                  ),
                const SizedBox(height: Space.small),
                if (hostHomeserver != null) ..._throughElement(context, hostHomeserver),
                Text(hostHomeserver == null ? 'Who is in it' : 'Already in the room', style: text.titleSmall),
                if (members == null && model.problem == null) const Text('Asking the machine…'),
                if (members != null && members.isEmpty) const Text('Nobody has joined yet.', key: Key('no-members')),
                // On a host its homeserver manages its people: who is in reads by name alone, with nothing to do.
                if (hostHomeserver != null)
                  Wrap(
                    spacing: Space.tight,
                    runSpacing: Space.tight,
                    children: <Widget>[
                      for (final each in members ?? const <MessageMember>[])
                        Chip(key: ValueKey<String>('member-chip ${each.person}'), label: Text(each.person)),
                    ],
                  )
                else
                  for (final each in members ?? const <MessageMember>[]) _member(context, each),
                const SizedBox(height: Space.normal),
                if (joinedAs != null) Text('You are in as ${joinedAs.person}', key: const Key('joined-as')),
                if (offersJoin) ...<Widget>[
                  Text('Join it', style: text.titleSmall),
                  Text(
                    'An account is made for the person and invited into the room. Its password is shown '
                    'here once and kept nowhere, here or on the machine.',
                    style: text.bodySmall,
                  ),
                  if (admitted != null && admitted.isEmpty)
                    Text(
                      'The organization admits nobody to ${model.project.name}’s room yet: only its admins and '
                      'members whose card holds are let in.',
                      key: const Key('join-nobody-admitted'),
                    ),
                  if (admitted != null && admitted.isNotEmpty)
                    DropdownButtonFormField<String>(
                      key: const Key('join-login'),
                      initialValue: admitted.contains(chosen) ? chosen : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Join as',
                        helperText: 'the logins the organization admits to this room',
                      ),
                      items: <DropdownMenuItem<String>>[
                        for (final login in admitted)
                          DropdownMenuItem<String>(
                            key: ValueKey<String>('join-login $login'),
                            value: login,
                            child: Text(login, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (login) {
                        setState(() => _chosen = login);
                        model.personChanged();
                      },
                    ),
                  if (admission is AdmissionUnread && admission.problem == null)
                    Text(
                      'The organization is not read yet, so the logins its room admits cannot be offered; '
                      'the machine refuses a name it does not admit.',
                      key: const Key('join-admission-unread'),
                      style: text.bodySmall,
                    ),
                  if (admission is AdmissionUnread && admission.problem != null)
                    Text(
                      'The organization could not be read: ${admission.problem} So the logins its room admits '
                      'cannot be offered; the machine refuses a name it does not admit.',
                      key: const Key('join-admission-refused'),
                      style: TextStyle(color: scheme.error),
                    ),
                  if (admitted == null)
                    TextField(
                      key: const Key('join-person'),
                      controller: _person,
                      inputFormatters: <TextInputFormatter>[_LowerCaseName()],
                      // Walk 10: the name a person goes by in the chat, not "who".
                      decoration: const InputDecoration(
                        labelText: 'Your name in the chat',
                        helperText: 'lower-case letters, digits and . _ = -',
                      ),
                      onChanged: (_) => model.personChanged(),
                    ),
                ],
                if (model.removed case final answer? when answer.kept)
                  Padding(
                    padding: const EdgeInsets.only(top: Space.small),
                    child: SelectableText(answer.why, key: const Key('member-removal-kept')),
                  ),
                if (model.problem != null)
                  Padding(
                    padding: const EdgeInsets.only(top: Space.small),
                    child: Text(
                      model.problem!,
                      key: const Key('messages-problem'),
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
                if (_greyWords(joining: offersJoin ? join : null, resetting: offersReset ? reset : null)
                    case final words?)
                  Padding(
                    padding: const EdgeInsets.only(top: Space.small),
                    child: Text(words, key: const Key('messages-why')),
                  ),
                if (joined != null) ..._login(context, model, joined),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          if (offersReset)
            Tooltip(
              message: reset.unavailable ?? '',
              child: OutlinedButton(
                key: ValueKey<String>(reset.id),
                onPressed: reset.available ? reset.run : null,
                child: Text(reset.label),
              ),
            ),
          if (offersJoin)
            Tooltip(
              message: join.unavailable ?? '',
              child: FilledButton(
                key: ValueKey<String>(join.id),
                onPressed: join.available ? join.run : null,
                child: Text(join.label),
              ),
            ),
          TextButton(
            key: const Key('messages-close'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(joined == null || joined.invited ? 'Done' : 'Done: the password is not shown again'),
          ),
        ],
      );
    },
  );

  /// Why a grey button at the foot of the dialog is grey, once: both say the same while it answers.
  String? _greyWords({Command? joining, Command? resetting}) =>
      switch (<String?>{joining?.unavailable, resetting?.unavailable}.nonNulls.toList()) {
        [] => null,
        final said => 'Not now: ${said.join(' · ')}',
      };

  Widget _member(BuildContext context, MessageMember member) {
    final model = widget.conversation;
    final remove = removeMessageMemberCommand(
      member.person,
      supported: model.removalSupported,
      busy: model.busy,
      run: () => unawaited(_confirmRemoval(member)),
    );
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: SelectableText(
                '${member.person}, as ${member.user}',
                key: ValueKey<String>('member ${member.person}'),
                style: text.bodySmall,
              ),
            ),
            OutlinedButton(
              key: ValueKey<String>(remove.id),
              onPressed: remove.available ? remove.run : null,
              child: Text(remove.label),
            ),
          ],
        ),
        if (remove.unavailable != null) Text(remove.unavailable!, style: text.bodySmall),
      ],
    );
  }

  Future<void> _confirmRemoval(MessageMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${member.person}?'),
        content: Text('Remove ${member.person}, as ${member.user}, from this project’s room?'),
        actions: <Widget>[
          TextButton(
            key: const Key('member-remove-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('member-remove-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await widget.conversation.remove(member.person);
  }

  List<Widget> _where(BuildContext context, ProjectMessages messages) {
    final text = Theme.of(context).textTheme;
    return <Widget>[
      Text('Over ${messages.transport}, on the server.', key: const Key('messages-where')),
      if (messages.conversation.isNotEmpty) SelectableText('Its room: ${messages.conversation}', style: text.bodySmall),
      Text(
        messages.ready
            ? 'This machine can carry its messages now.'
            : messages.detail.isEmpty
            ? 'This machine cannot carry its messages now.'
            : 'This machine cannot carry its messages now: ${messages.detail}',
        key: const Key('messages-ready'),
      ),
      if (messages.loopbackOnly)
        Text(
          'An offline project: its messages stay on this machine, and its conversation with them.',
          style: text.bodySmall,
        ),
    ];
  }

  /// On a host running its own homeserver: the person signs in with Element through the host's gate, with SSO,
  /// and accepts the invitation the host has sent their login.
  List<Widget> _throughElement(BuildContext context, String homeserver) {
    final model = widget.conversation;
    final text = Theme.of(context).textTheme;
    final login = model.hostLogin;
    final host = model.machine.hostCard?.name;
    final room = model.project.messages?.conversation;
    final accept = room == null || room.isEmpty
        ? 'Accept the invitation to ${model.project.name}’s room.'
        : 'Accept the invitation to ${model.project.name}’s room, $room.';
    return <Widget>[
      const SizedBox(height: Space.small),
      Text(
        'This host manages its people at its own homeserver: you sign in with Element through the host’s gate.',
        key: const Key('host-manages-people'),
      ),
      const SizedBox(height: Space.small),
      if (_elementHere == null) const Text('Looking for Element on this computer…'),
      if (_elementHere == true) ...<Widget>[
        Text('Element is installed on this computer', style: text.titleSmall),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            key: const Key('open-element-signed-in'),
            icon: const Icon(Icons.open_in_new),
            // An Element already open takes only the address from a start that is not separate: it is not signed
            // in to this host by it.
            label: Text(_separate ? 'Open Element signed in to this host' : 'Open Element with this host’s address'),
            onPressed: model.whyElementCannotOpen == null
                ? () => unawaited(_startElement(homeserver, _separate ? host : null))
                : null,
          ),
        ),
        if (model.whyElementCannotOpen case final why?) Text(why, key: const Key('element-not-reached')),
        SelectableText(
          _separate
              ? 'Sets the homeserver to $homeserver and goes straight to Continue with SSO'
                    '${login == null ? '' : ', where you sign in as $login'}; then accept the invitation.'
              : 'If Element is already open, choose the homeserver $homeserver there and Continue with SSO.',
          style: text.bodySmall,
        ),
        if (_elementProblem case final problem?)
          Text(
            'Element could not be started: $problem',
            key: const Key('element-problem'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        CheckboxListTile(
          key: const Key('element-separate-instance'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _separate,
          title: const Text('In a separate instance (keeps your open Element as it is)'),
          onChanged: (value) => setState(() => _separate = value ?? true),
        ),
      ],
      if (_elementHere == false) ...<Widget>[
        Text('Element is not installed on this computer', style: text.titleSmall),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const Key('install-element'),
            icon: const Icon(Icons.download),
            label: const Text('Install Element'),
            onPressed: () => unawaited(desk.open(_elementDownload)),
          ),
        ),
        SelectableText(_elementDownload, style: text.bodySmall),
        const SizedBox(height: Space.small),
        const Text('Or by hand:'),
        Row(
          children: <Widget>[
            Expanded(child: SelectableText('1. Choose the homeserver $homeserver', key: const Key('host-homeserver'))),
            IconButton(
              key: const Key('copy-homeserver'),
              icon: const Icon(Icons.copy, size: Sizes.rowIcon),
              tooltip: 'Copy the homeserver',
              visualDensity: VisualDensity.compact,
              onPressed: () => unawaited(Clipboard.setData(ClipboardData(text: homeserver))),
            ),
          ],
        ),
        Text(
          login == null ? '2. Continue with SSO.' : '2. Continue with SSO; you sign in as $login.',
          key: const Key('host-sso'),
        ),
        Text('3. $accept'),
      ],
      const SizedBox(height: Space.normal),
    ];
  }

  Future<void> _startElement(String homeserver, String? profile) async {
    // Asked again at the press: the connection may have dropped since the button was drawn.
    if (widget.conversation.whyElementCannotOpen case final why?) {
      setState(() => _elementProblem = why);
      return;
    }
    setState(() => _elementProblem = null);
    String? problem;
    try {
      await _element.open(homeserver: homeserver, profile: profile);
    } on FileSystemException catch (refused) {
      problem = refused.osError == null ? refused.message : '${refused.message}: ${refused.osError!.message}';
    } on ProcessException catch (refused) {
      problem = refused.message.isEmpty ? '${refused.executable} did not start' : refused.message;
    }
    if (!mounted) return;
    setState(() => _elementProblem = problem);
  }

  static Widget _secretIf(bool secret, Widget child) => secret ? WalkSecret(child: child) : child;

  // The person's existing account was invited into this room: they accept it where they are signed in already, and
  // no password exists to show.
  List<Widget> _invitation(BuildContext context, ProjectConversation model, MessagesJoined joined) {
    final text = Theme.of(context).textTheme;
    // An empty field says nothing, as an absent one: it is not named, and gets no row.
    String? given(String field) => switch (joined.login[field]) {
      final value? when value.isNotEmpty => value,
      _ => null,
    };
    final user = given('user');
    final room = given('room');
    return <Widget>[
      const SizedBox(height: Space.small),
      Text('Accept the invitation', style: text.titleSmall),
      Text(
        'The Matrix account ${user ?? 'they have already'} was invited into this room; nothing new was made.',
        key: const Key('login-invited'),
      ),
      Text('1. Open the Matrix client they already sign in to${user == null ? '' : ', signed in as $user'}.'),
      Text('2. Accept the invitation to the room${room == null ? '' : ' $room'}, then open it.'),
      const SizedBox(height: Space.tight),
      // Never the password: an invitation has none, and one sent anyway is not shown or copied.
      for (final (field, label) in _loginFields)
        if (field != 'password')
          if (given(field) case final value?) _loginRow(context, field, label, value),
      ..._forwardNotice(context, model, joined),
    ];
  }

  /// One field of a login, named as a Matrix client names it and copied on its own; the password blanked.
  Widget _loginRow(BuildContext context, String field, String label, String value) => Row(
    children: <Widget>[
      SizedBox(
        width: Sizes.fieldName,
        child: Text(label, style: Theme.of(context).textTheme.bodySmall),
      ),
      Expanded(
        // The password reads and writes in the project's room: blanked, and left out of what a walk writes down.
        child: _secretIf(
          field == 'password',
          SelectableText(
            value,
            key: ValueKey<String>('login $field'),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      ),
      IconButton(
        key: ValueKey<String>('login-copy $field'),
        icon: const Icon(Icons.copy, size: Sizes.rowIcon),
        tooltip: 'Copy the $label',
        visualDensity: VisualDensity.compact,
        onPressed: () => unawaited(Clipboard.setData(ClipboardData(text: value))),
      ),
    ],
  );

  /// Where a homeserver on the machine's loopback is reached from this computer, or nothing elsewhere.
  List<Widget> _forwardNotice(BuildContext context, ProjectConversation model, MessagesJoined joined) {
    final port = joined.port;
    if (!joined.loopback || port == null) return const <Widget>[];
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return <Widget>[
      const SizedBox(height: Space.small),
      Text(
        model.forwarded != null
            ? 'The homeserver is on ${model.machine.name}’s loopback; port $port is forwarded from this '
                  'computer while this window runs, so a Matrix client here reaches it at http://127.0.0.1:$port.'
            : model.forwardProblem ??
                  (model.machine.host.isNotEmpty
                      ? 'Forwarding port $port from ${model.machine.name}…'
                      : 'The homeserver is on this computer, at http://127.0.0.1:$port.'),
        key: const Key('login-forward'),
        style: model.forwardProblem == null ? text.bodySmall : TextStyle(color: scheme.error),
      ),
    ];
  }

  List<Widget> _login(BuildContext context, ProjectConversation model, MessagesJoined joined) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final element = openElementCommand();
    if (joined.invited) return _invitation(context, model, joined);
    return <Widget>[
      const SizedBox(height: Space.small),
      Text('Join with Element', style: text.titleSmall),
      const Text('1. Open Element.'),
      OutlinedButton.icon(
        key: ValueKey<String>(element.id),
        onPressed: element.run,
        icon: const Icon(Icons.open_in_new),
        label: Text(element.label),
      ),
      const Text('2. Choose Sign in, then Edit the homeserver.'),
      const Text('3. Paste the Homeserver URL shown below and continue.'),
      const Text('4. Sign in with the Matrix ID and Password shown below.'),
      const Text('5. Join the room by its name, shown below as Room.'),
      const SizedBox(height: Space.small),
      Text('Their login, shown once', style: text.titleSmall),
      Text(
        'Copy it into their Matrix client now: it is not kept, and seeing it again means a new password.',
        style: text.bodySmall,
      ),
      const SizedBox(height: Space.tight),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Space.small),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(Radii.small),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Named as a Matrix client names its fields, each copied on its own, since a client asks
            // for them one by one (walk 8: "user" is "Matrix ID" there, and nothing could be copied).
            for (final (field, label) in _loginFields)
              if (joined.login[field] case final value?) _loginRow(context, field, label, value),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const Key('login-copy-all'),
                icon: const Icon(Icons.copy_all, size: Sizes.rowIcon),
                label: const Text('Copy all of it'),
                onPressed: () => unawaited(
                  Clipboard.setData(
                    ClipboardData(
                      text: <String>[
                        for (final (field, label) in _loginFields)
                          if (joined.login[field] case final value?) '$label: $value',
                      ].join('\n'),
                    ),
                  ),
                ),
              ),
            ),
            Text(
              'Mention a task by picking it from your Matrix client’s list as a pill, rather than typing its name.',
              style: text.bodySmall,
            ),
          ],
        ),
      ),
      ..._forwardNotice(context, model, joined),
    ];
  }
}

class _LowerCaseName extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toLowerCase());
}

/// Where Element's installers are offered.
const String _elementDownload = 'https://element.io/download';

/// The login's fields, in the order a Matrix client asks for them, with the names it gives them.
const List<(String, String)> _loginFields = <(String, String)>[
  ('homeserver', 'Homeserver URL'),
  ('user', 'Matrix ID'),
  ('password', 'Password'),
  ('room', 'Room'),
];
