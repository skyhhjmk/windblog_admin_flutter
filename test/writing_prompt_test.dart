import 'package:flutter_test/flutter_test.dart';
import 'package:windblog_admin_flutter/services/local_codex/writing_prompt.dart';

void main() {
  String build(String template, {String task = '润色', bool html = false}) =>
      buildWritingPrompt(
        template: template,
        task: task,
        requirements: '简洁',
        title: '标题',
        content: '正文 {{title}}',
        html: html,
      );

  test('custom prompt inserts variables once and preserves article text', () {
    expect(
      build('{{title}} / {{content}} / {{requirements}} / {{unknown}}'),
      '标题 / 正文 {{title}} / 简洁 / {{unknown}}',
    );
    expect(build('只返回一句话'), '只返回一句话');
  });
  test('default rules distinguish continuation, summary and HTML', () {
    expect(build(defaultWritingPrompt, task: '续写'), contains('只返回新增段落。'));
    expect(build(defaultWritingPrompt, task: '摘要'), contains('返回纯文本摘要。'));
    expect(build(defaultWritingPrompt, html: true), contains('HTML 正文片段'));
  });
}
