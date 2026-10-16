import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Runs the device's installed CLI without passing article text to a shell.
class LocalCodex {
  Process? _process;
  bool _cancelled = false;
  bool _running = false;
  bool get supported =>
      Platform.isLinux || Platform.isMacOS || Platform.isWindows;

  /// Local CLI cache is a convenience list, not a guarantee of account access.
  Future<List<String>> availableModels() async {
    final home = Platform.environment['CODEX_HOME'];
    final userHome =
        Platform.environment[Platform.isWindows ? 'USERPROFILE' : 'HOME'];
    final root = home ?? (userHome == null ? null : '$userHome/.codex');
    if (root == null) return [];
    try {
      final data = jsonDecode(
        await File('$root/models_cache.json').readAsString(),
      );
      return (data['models'] as List)
          .whereType<Map<String, dynamic>>()
          .map((m) => m['slug'])
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
    } catch (_) {
      return [];
    }
  }

  Future<String> generate(
    String prompt, {
    String executable = 'codex',
    String? model,
  }) async {
    if (!supported) {
      throw UnsupportedError('此功能需要桌面设备上安装并登录 Codex CLI。');
    }
    if (_running) throw StateError('已有写作任务正在运行');
    _running = true;
    _cancelled = false;
    Directory? workspace;
    try {
      workspace = await Directory.systemTemp.createTemp('windblog-writing-');
      if (_cancelled) throw StateError('已取消');
      final output = File('${workspace.path}/result.txt');
      final process = await Process.start(executable.trim(), [
        '-a',
        'never',
        'exec',
        if (model != null && model.trim().isNotEmpty) ...[
          '--model',
          model.trim(),
        ],
        '--sandbox',
        'read-only',
        '--skip-git-repo-check',
        '--ephemeral',
        '--color',
        'never',
        '-c',
        'mcp_servers={}',
        '-c',
        'features.shell_tool=false',
        '-c',
        'features.memories=false',
        '-C',
        workspace.path,
        '-o',
        output.path,
        '-',
      ], runInShell: false);
      _process = process;
      if (_cancelled) process.kill();
      // Drain both pipes immediately to avoid blocking on a full OS pipe.
      final stdoutDone = process.stdout.drain<void>();
      final errors = StringBuffer();
      final stderrDone = process.stderr.transform(utf8.decoder).listen((chunk) {
        if (errors.length < 8192) errors.write(chunk);
      }).asFuture<void>();
      process.stdin.write(prompt);
      await process.stdin.close();
      final code = await process.exitCode.timeout(
        const Duration(minutes: 3),
        onTimeout: () {
          process.kill();
          throw TimeoutException('写作超时，请重试');
        },
      );
      await Future.wait([stdoutDone, stderrDone]);
      if (_cancelled) throw StateError('已取消');
      if (code != 0) {
        // CLI diagnostics can contain prompts or credentials. Do not expose them.
        throw StateError(
          'Codex 调用失败（退出码 $code），请在终端检查 codex login status 和 Codex 配置。',
        );
      }
      final result = await output.exists()
          ? (await output.readAsString()).trim()
          : '';
      if (result.isEmpty) throw StateError('Codex 未返回写作结果');
      return result;
    } on ProcessException {
      throw StateError('无法启动 Codex，请安装并登录 CLI，或填写可执行文件的绝对路径。');
    } finally {
      _process = null;
      _running = false;
      if (workspace != null) await workspace.delete(recursive: true);
    }
  }

  void cancel() {
    _cancelled = true;
    _process?.kill();
  }
}
