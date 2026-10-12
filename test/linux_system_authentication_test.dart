import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:windblog_admin_flutter/utils/linux_system_authentication.dart';

void main() {
  if (!Platform.isLinux) return;
  late Directory temporary;
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('windblog-auth-test-');
  });
  tearDown(() => temporary.delete(recursive: true));

  Future<List<String>> command(String body) async {
    final file = File('${temporary.path}/command.py');
    await file.writeAsString(body);
    return ['/usr/bin/python3', file.path];
  }

  test('waiting for fingerprint keeps event-loop timers responsive', () async {
    final auth = LinuxSystemAuthentication(
      verifyCommand: await command(
        'import time\ntime.sleep(0.3)\nprint("Verify result: verify-match (done)")',
      ),
    );
    var ticks = 0;
    final timer = Timer.periodic(
      const Duration(milliseconds: 20),
      (_) => ticks++,
    );
    try {
      expect(await auth.authenticate(), isTrue);
      expect(ticks, greaterThan(5));
    } finally {
      timer.cancel();
    }
  });

  test('exit zero without verify-match does not authenticate', () async {
    final auth = LinuxSystemAuthentication(
      verifyCommand: await command(
        'print("Verify result: verify-no-match (done)")',
      ),
    );
    expect(await auth.authenticate(), isFalse);
  });

  test('cancel terminates pending verification without fingerprint', () async {
    final auth = LinuxSystemAuthentication(
      verifyCommand: await command('import time\ntime.sleep(60)'),
    );
    final pending = auth.authenticate();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(await auth.authenticate(), isFalse);
    auth.cancel();
    expect(await pending.timeout(const Duration(seconds: 2)), isFalse);
  });

  test('verification timeout terminates child and fails closed', () async {
    final auth = LinuxSystemAuthentication(
      verifyCommand: await command('import time\ntime.sleep(60)'),
      authenticationTimeout: const Duration(milliseconds: 100),
    );
    expect(
      await auth.authenticate().timeout(const Duration(seconds: 2)),
      isFalse,
    );
  });

  test(
    'availability requires enrolled fingers rather than zero exit',
    () async {
      final cmd = await command('print("User has no fingers enrolled")');
      final auth = LinuxSystemAuthentication(listCommand: cmd);
      expect(await auth.isAvailable(), isFalse);
      await File(cmd.last).writeAsString('print(" - #0: right-index-finger")');
      expect(await auth.isAvailable(), isTrue);
    },
  );

  test('availability timeout fails closed', () async {
    final auth = LinuxSystemAuthentication(
      listCommand: await command('import time\ntime.sleep(60)'),
      availabilityTimeout: const Duration(milliseconds: 100),
    );
    expect(
      await auth.isAvailable().timeout(const Duration(seconds: 2)),
      isFalse,
    );
  });
}
