import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Runs fprintd without blocking Flutter's platform or Dart UI thread.
class LinuxSystemAuthentication {
  LinuxSystemAuthentication({
    this.listCommand = const ['/usr/bin/fprintd-list'],
    this.verifyCommand = const ['/usr/bin/fprintd-verify'],
    this.availabilityTimeout = const Duration(seconds: 5),
    this.authenticationTimeout = const Duration(seconds: 30),
  });

  final List<String> listCommand;
  final List<String> verifyCommand;
  final Duration availabilityTimeout;
  final Duration authenticationTimeout;
  Process? _verification;
  bool _authenticating = false;
  bool _canceled = false;

  Future<bool> isAvailable() async {
    final user = Platform.environment['USER'];
    if (user == null || user.isEmpty) return false;
    Process? process;
    try {
      process = await Process.start(
        listCommand.first,
        [...listCommand.skip(1), user],
        environment: {'LC_ALL': 'C'},
      );
      final output = process.stdout.transform(utf8.decoder).join();
      final errors = process.stderr.drain<void>();
      final code = await process.exitCode.timeout(availabilityTimeout);
      final text = await output.timeout(availabilityTimeout);
      await errors.timeout(availabilityTimeout);
      // fprintd-list can exit successfully even when no fingers are enrolled.
      return code == 0 &&
          RegExp(r'^\s*- #\d+:', multiLine: true).hasMatch(text);
    } catch (_) {
      return false;
    } finally {
      process?.kill(ProcessSignal.sigkill);
    }
  }

  Future<bool> authenticate() async {
    if (_authenticating) return false;
    _authenticating = true;
    _canceled = false;
    Process? process;
    try {
      process = await Process.start(
        verifyCommand.first,
        verifyCommand.skip(1).toList(),
        environment: {'LC_ALL': 'C'},
      );
      _verification = process;
      if (_canceled) process.kill(ProcessSignal.sigkill);
      final output = process.stdout.transform(utf8.decoder).join();
      final errors = process.stderr.drain<void>();
      final code = await process.exitCode.timeout(authenticationTimeout);
      final text = await output.timeout(availabilityTimeout);
      await errors.timeout(availabilityTimeout);
      return !_canceled &&
          code == 0 &&
          RegExp(
            r'^Verify result: verify-match \(done\)\s*$',
            multiLine: true,
          ).hasMatch(text);
    } catch (_) {
      return false;
    } finally {
      process?.kill(ProcessSignal.sigkill);
      _verification = null;
      _authenticating = false;
    }
  }

  void cancel() {
    _canceled = true;
    _verification?.kill(ProcessSignal.sigkill);
  }
}
