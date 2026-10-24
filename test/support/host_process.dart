import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_host/porelo_host.dart';

/// A host command driven entirely by the test, without a process or a real clock.
class HostProcess extends Fake implements Process {
  HostProcess() {
    _input.stream.listen((_) {});
    _stdin = IOSink(_input.sink);
  }

  final _input = StreamController<List<int>>();
  final _output = StreamController<List<int>>();
  final _errors = StreamController<List<int>>();
  final _exit = Completer<int>();
  late final IOSink _stdin;

  void line(Step step) => raw(step.toLine());
  void raw(String line) => _output.add(utf8.encode('$line\n'));
  void words(String line) => _errors.add(utf8.encode('$line\n'));
  void end(int code) {
    unawaited(_output.close());
    unawaited(_errors.close());
    _exit.complete(code);
  }

  @override
  IOSink get stdin => _stdin;
  @override
  Stream<List<int>> get stdout => _output.stream;
  @override
  Stream<List<int>> get stderr => _errors.stream;
  @override
  Future<int> get exitCode => _exit.future;
}
