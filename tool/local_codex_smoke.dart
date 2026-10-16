import 'dart:io';
import 'package:windblog_admin_flutter/services/local_codex/local_codex.dart';

Future<void> main() async {
  final result = await LocalCodex().generate(
    '你是写作助手。不要使用工具。请把“今天我们介绍博客写作。”润色成一句自然的中文，只返回句子。',
  );
  stdout.writeln(result);
}
