part of 'package:windblog_admin_flutter/main.dart';

class ImportDataPage extends StatefulWidget {
  const ImportDataPage({
    super.key,
    required this.api,
    required this.onAuthError,
  });

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<ImportDataPage> createState() => _ImportDataPageState();
}

class _ImportDataPageState extends State<ImportDataPage> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController(
      text: 'jdbc:postgresql://localhost:5432/windblog');
  final _usernameController = TextEditingController(text: 'postgres');
  final _passwordController = TextEditingController(text: 'postgres');
  final _assetPrefixController = TextEditingController(text: 'https://');
  final String _driver = 'org.postgresql.Driver';

  bool _importCategories = true;
  bool _importTags = true;
  bool _importPosts = true;
  bool _importLinks = true;
  bool _importMedia = true;
  final bool _importComments = false;

  bool _isTesting = false;
  bool _isImporting = false;
  String? _result;
  final List<String> _logs = [];
  final ScrollController _logScrollController = ScrollController();
  StreamSubscription? _importSub;

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _result = null;
    });
    try {
      final res = await widget.api.testImportConnection({
        'driver': _driver,
        'url': _urlController.text,
        'username': _usernameController.text,
        'password': _passwordController.text,
      });
      if (mounted) {
        setState(() {
          _result = res['message']?.toString() ?? '测试完成';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _result = '测试失败: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  Future<void> _startImport() async {
    final types = <String>[];
    if (_importCategories) types.add('categories');
    if (_importTags) types.add('tags');
    if (_importPosts) types.add('posts');
    if (_importLinks) types.add('links');
    if (_importMedia) types.add('media');
    if (_importComments) types.add('comments');

    if (types.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(context, 'please_select_at_least_one'))),
      );
      return;
    }

    setState(() {
      _isImporting = true;
      _result = null;
      _logs.clear();
      _logs.add('🚀 开始导入任务...');
    });

    // 启动 SSE 监听
    _importSub = widget.api.importStream().listen((event) {
      if (mounted) {
        setState(() {
          final type = event['type']?.toString();
          final message = event['message']?.toString() ?? '';
          final status = event['status']?.toString();
          String prefix = '';
          if (type == 'info') prefix = 'ℹ️ ';
          if (type == 'error') prefix = '❌ ';
          if (type == 'progress') prefix = '📈 ';
          if (type == 'end') prefix = '✅ ';

          String finalMsg = '$prefix $message';
          if (status != null) {
            finalMsg += ' [$status]';
          }
          _logs.add(finalMsg);

          // 自动滚动到底部
          Future.delayed(const Duration(milliseconds: 100), () {
            if (_logScrollController.hasClients) {
              _logScrollController.animateTo(
                _logScrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
            }
          });
        });
      }
    }, onError: (e) {
      if (mounted) {
        setState(() {
          _logs.add('❌ 连接流错误: $e');
        });
      }
    });

    try {
      final res = await widget.api.doImport({
        'driver': _driver,
        'url': _urlController.text,
        'username': _usernameController.text,
        'password': _passwordController.text,
        'types': types,
        'assetPrefix': _assetPrefixController.text,
        'clearExisting': false,
      });
      if (mounted) {
        setState(() {
          if (res['success'] == true) {
            _result = '导入成功！\n'
                '分类: ${res['importedCategories']}\n'
                '标签: ${res['importedTags']}\n'
                '文章: ${res['importedPosts']}\n'
                '链接: ${res['importedLinks']}';
          } else {
            _result = res['message']?.toString() ?? '导入失败';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _result = '导入出错: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
          _importSub?.cancel();
        });
      }
    }
  }

  @override
  void dispose() {
    _importSub?.cancel();
    _logScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t(context, 'import_data')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t(context, 'db_config'), style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: 'PostgreSQL',
                        readOnly: true,
                        decoration: InputDecoration(
                            labelText: t(context, 'db_type')),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _urlController,
                        decoration: const InputDecoration(
                            labelText: 'JDBC URL'),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _usernameController,
                        decoration: InputDecoration(labelText: t(context,
                            'username')),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(labelText: t(context,
                            'password')),
                        obscureText: true,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _assetPrefixController,
                        decoration: const InputDecoration(
                            labelText: '附件相对地址补全前缀',
                            hintText: '例如: https://your-old-site.com'),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _isTesting ? null : _testConnection,
                        icon: _isTesting
                            ? const SizedBox(width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.cable),
                        label: Text(t(context, 'test_connection')),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t(context, 'select_import_content'),
                          style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        title: Text(t(context, 'categories')),
                        value: _importCategories,
                        onChanged: (v) =>
                            setState(() => _importCategories = v!),
                      ),
                      CheckboxListTile(
                        title: Text(t(context, 'tags')),
                        value: _importTags,
                        onChanged: (v) => setState(() => _importTags = v!),
                      ),
                      CheckboxListTile(
                        title: Text(t(context, 'posts')),
                        value: _importPosts,
                        onChanged: (v) => setState(() => _importPosts = v!),
                      ),
                      CheckboxListTile(
                        title: Text(t(context, 'links')),
                        value: _importLinks,
                        onChanged: (v) => setState(() => _importLinks = v!),
                      ),
                      CheckboxListTile(
                        title: Text(t(context, 'media_library_import')),
                        value: _importMedia,
                        onChanged: (v) => setState(() => _importMedia = v!),
                      ),
                      // CheckboxListTile(
                      //   title: const Text('评论 (暂不支持)'),
                      //   value: false,
                      //   onChanged: null,
                      // ),
                    ],
                  ),
                ),
              ),
              if (_logs.isNotEmpty)
                Card(
                  color: Colors.grey[900],
                  child: Container(
                    height: 300,
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.terminal, color: Colors.green,
                                size: 16),
                            const SizedBox(width: 8),
                            Text(t(context, 'import_logs'),
                                style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Divider(color: Colors.grey),
                        Expanded(
                          child: ListView.builder(
                            controller: _logScrollController,
                            itemCount: _logs.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 2),
                                child: Text(
                                  _logs[index],
                                  style: const TextStyle(color: Colors.white70,
                                      fontSize: 12,
                                      fontFamily: 'monospace'),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              if (_result != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: _result!.contains('成功') ? Colors.green[50] : Colors
                        .red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: _result!.contains('成功') ? Colors.green : Colors
                            .red),
                  ),
                  child: Text(_result!, style: TextStyle(
                      color: _result!.contains('成功')
                          ? Colors.green[900]
                          : Colors.red[900])),
                ),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: _isImporting ? null : _startImport,
                  icon: _isImporting ? const SizedBox(width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white)) : const Icon(
                      Icons.input),
                  label: Text(_isImporting ? t(context, 'importing') : t(
                      context, 'start_import')),
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange[800]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
