import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:windblog_admin_flutter/services/local_codex/local_codex.dart';

void main() {
  test(
    'passes prompt through stdin and reads final output without shell evaluation',
    () async {
      if (!Platform.isLinux && !Platform.isMacOS) return;
      final dir = await Directory.systemTemp.createTemp('fake-codex-');
      try {
        final script = File('${dir.path}/fake codex');
        await script.writeAsString('''#!/bin/sh
out=''
model=''
while [ "\$#" -gt 0 ]; do
  if [ "\$1" = '--model' ]; then shift; model="\$1"; fi
  if [ "\$1" = '-o' ]; then shift; out="\$1"; fi
  shift
done
if [ -n "\$model" ]; then printf '%s\\n' "\$model" > "\$out"; cat >> "\$out"; else cat > "\$out"; fi
''');
        await Process.run('chmod', ['700', script.path]);
        final client = LocalCodex();
        const prompt = '中文文章 \$(touch should-not-exist) `echo test`';
        expect(await client.generate(prompt, executable: script.path), prompt);
        expect(
          await client.generate(
            prompt,
            executable: script.path,
            model: ' custom-model ',
          ),
          'custom-model\n$prompt',
        );
        expect(
          await client.generate(prompt, executable: script.path, model: '  '),
          prompt,
        );
        expect(await File('should-not-exist').exists(), false);
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );

  test('missing executable returns actionable error', () async {
    if (!Platform.isLinux && !Platform.isMacOS && !Platform.isWindows) return;
    await expectLater(
      LocalCodex().generate('test', executable: '/missing/codex'),
      throwsA(isA<StateError>()),
    );
  });
}
