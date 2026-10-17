// Linux only: it opens a pty with libc; Windows' terminal is ConPTY, tested on Windows by hand.
@Tags(<String>['linux'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/pty.dart';

/// The terminal, against the real kernel.
///
/// **This is the one thing in this repository that cannot be proven with a fake.** Everything
/// above it is held by the session's own tests; what is here is whether a pty is really a
/// terminal — and the way to know is to ask the far end, in its own words, rather than to assert
/// that this code called the functions it calls.
void main() {
  Future<String> whatItPrinted(Pty pty) =>
      pty.output.transform(utf8.decoder).join();

  test('the far end is a terminal, and knows the size it was given', () async {
    // `stty` fails outright without a controlling terminal, so an answer at all is the proof
    // that one was acquired — and the numbers prove the size arrived. Rows first, as stty says
    // them.
    final pty = Pty.start('sh', <String>['-c', 'stty size'], columns: 100, rows: 30);
    final said = await whatItPrinted(pty);

    expect(said.trim(), '30 100');
    expect(await pty.ended, 0);
  });

  test('a new size reaches what is already running', () async {
    final pty = Pty.start(
      'sh',
      // Waits for a line, so the resize below lands while it is running rather than before it
      // starts — which is the case that matters and the one a fixed size would pass anyway.
      <String>['-c', 'read line; stty size'],
      columns: 80,
      rows: 24,
    );
    addTearDown(pty.close);
    final printed = whatItPrinted(pty);

    pty.resize(columns: 132, rows: 43);
    pty.send('go\n');

    expect((await printed).trim().split('\n').last.trim(), '43 132');
  });

  test('what it exits with is what is reported', () async {
    final pty = Pty.start('sh', <String>['-c', 'exit 69']);
    await whatItPrinted(pty);

    // 69 is the code `porelo task attach` refuses with, so this is the number a session reads to
    // tell "it would not open" from "somebody typed exit".
    expect(await pty.ended, 69);
  });

  test('what it exits with is reported while the runtime reaps children of its own', () async {
    // Any dart:io process running makes the runtime reap every child of this process, ours
    // included, and discard the status: an ssh forward always is, for a machine elsewhere. Before
    // the code had a pipe of its own, this read -1 after a command that succeeded.
    final beside = await Process.start('sleep', <String>['5']);
    addTearDown(beside.kill);
    final pty = Pty.start('sh', <String>['-c', 'exit 3']);
    await whatItPrinted(pty);

    expect(await pty.ended, 3);
  });

  test('the command is not handed the descriptor its code is reported on', () async {
    final pty = Pty.start('sh', <String>['-c', 'if [ -e /dev/fd/3 ]; then echo held; else echo not held; fi']);

    expect((await whatItPrinted(pty)).trim(), 'not held');
    expect(await pty.ended, 0);
  });

  test('Ctrl+C typed into it ends what runs there, as an interrupt', () async {
    final pty = Pty.start('sh', <String>['-c', 'sleep 30']);
    unawaited(whatItPrinted(pty));
    await Future<void>.delayed(const Duration(milliseconds: 200));

    pty.send('\x03');

    expect(await pty.ended.timeout(const Duration(seconds: 5)), 130);
  });

  test('a file that cannot be run never opens either, and says so', () {
    final directory = Directory.systemTemp.createTempSync('pty-');
    addTearDown(() => directory.deleteSync(recursive: true));
    File('${directory.path}/not-runnable').writeAsStringSync('#!/bin/sh\n');

    expect(
      () => Pty.start('${directory.path}/not-runnable', const <String>[]),
      throwsA(isA<PtyRefused>().having((refused) => refused.words, 'words', contains('cannot be run'))),
    );
  });

  test('a program that is not there never opens, rather than opening and dying', () async {
    // A shell reports a missing command as exit 127, and this deliberately does not: libc says
    // so before anything runs, so **the missing CLI is a refusal to open** and never a session
    // that appeared for an instant. The two read differently on screen and should.
    expect(
      () => Pty.start('porelo-does-not-exist', const <String>[]),
      throwsA(isA<PtyRefused>().having((refused) => refused.words, 'words',
          contains('no `porelo-does-not-exist` on this machine'))),
    );
  });

  test('what is typed reaches it, and what it prints comes back', () async {
    final pty = Pty.start('sh', <String>['-c', 'read line; echo "heard: \$line"']);
    addTearDown(pty.close);
    final printed = whatItPrinted(pty);

    pty.send('hello\n');

    expect(await printed, contains('heard: hello'));
    expect(await pty.ended, 0);
  });

  test('a long paste arrives whole, rather than as much as one write took', () async {
    // A pty master takes what fits and reports that. Believing the call loses the tail of a
    // paste, silently — which reads as an agent that ignored half of what it was told.
    //
    // **Counted at the far end, in raw mode.** The first version sent it through `cat` in the
    // terminal's default canonical mode and counted what came back, echo included. Measured
    // under CPU load: canonical mode hands a program at most 4095 characters of one line,
    // and the kernel drops echo it cannot get rid of, so that count moved between 120,542 and
    // 204,095 while every byte had been sent. A session is tmux in raw mode, where neither applies.
    final pty = Pty.start(
        'sh', <String>['-c', r"stty raw -echo; echo ready; head -c 200001 | tr -cd x | wc -c"]);
    addTearDown(pty.close);
    final said = StringBuffer();
    final ready = Completer<void>();
    final printed = Completer<void>();
    pty.output.transform(utf8.decoder).listen((text) {
      said.write(text);
      if (!ready.isCompleted && '$said'.contains('ready')) ready.complete();
    }, onDone: printed.complete);
    // stty has to have run before the paste, or the start of it meets canonical mode after all.
    await ready.future.timeout(const Duration(seconds: 10),
        onTimeout: () => fail('the far end never said raw mode was set'));

    pty.send('${'x' * 200000}\n');
    // Inside the test's own 30 seconds, so a lost tail fails with this sentence, not a timeout.
    await printed.future.timeout(const Duration(seconds: 20),
        onTimeout: () => fail('the far end never received the whole paste'));

    expect(int.tryParse('$said'.trim().split(RegExp(r'\s+')).last), 200000,
        reason: 'part of what was typed went nowhere');
  });

  test('closing a session whose far end has ended signals nothing', () async {
    // A pid is a number the kernel hands out again. While the child is a zombie it cannot be
    // reused; once it is reaped, sending SIGHUP to that number is sending it to a stranger.
    final pty = Pty.start('sh', <String>['-c', 'exit 0']);
    await pty.output.drain<void>();
    expect(await pty.ended, 0);

    await pty.close();

    expect(pty.signalledOnClose, isFalse);
  });

  test('closing a session that is still running does signal it', () async {
    final pty = Pty.start('sh', <String>['-c', 'sleep 30']);
    // Long enough to be running, short enough not to slow the suite down.
    await Future<void>.delayed(const Duration(milliseconds: 200));

    await pty.close();

    expect(pty.signalledOnClose, isTrue);
  });

  test('closing it ends the far end rather than leaving it running', () async {
    final pty = Pty.start('sh', <String>['-c', 'sleep 30']);
    unawaited(whatItPrinted(pty));

    await pty.close();

    // SIGHUP is what a terminal window closing sends, and 128 + 1 is how a signal reads as an
    // exit code. Anything else here would mean a session left behind on the machine.
    expect(await pty.ended.timeout(const Duration(seconds: 5)), 129);
  });

  test('closing it ends what runs there, and not only the shell that reports its code', () async {
    final pty = Pty.start('sh', <String>['-c', r'echo $$; exec sleep 30']);
    final printed = StringBuffer();
    final reading = pty.output.transform(utf8.decoder).listen(printed.write);
    while (int.tryParse(printed.toString().trim()) == null) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    final running = int.parse(printed.toString().trim());

    await pty.close();
    await pty.ended.timeout(const Duration(seconds: 5));
    await reading.cancel();

    // Asked until it is gone: hung up, it ends at once, and under load the kernel may take a
    // moment to take it away. Two seconds is far more than that and far less than its 30. What is
    // held is that the command ends; whether by the group's SIGHUP or by the terminal hanging up
    // when the shell leading it is gone, both end it, so this does not tell the two apart.
    final by = DateTime.now().add(const Duration(seconds: 2));
    while (Process.killPid(running, ProcessSignal.sigcont) && DateTime.now().isBefore(by)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(Process.killPid(running, ProcessSignal.sigcont), isFalse, reason: 'sleep $running is left running');
  });
}
