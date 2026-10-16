class LocalCodex {
  bool get supported => false;
  Future<List<String>> availableModels() async => [];
  Future<String> generate(
    String prompt, {
    String executable = 'codex',
    String? model,
  }) async {
    throw UnsupportedError('浏览器无法直接启动本机 Codex，请使用桌面客户端。');
  }

  void cancel() {}
}
