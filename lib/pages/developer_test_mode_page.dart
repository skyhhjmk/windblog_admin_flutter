part of 'package:windblog_admin_flutter/main.dart';

/// Descriptor for a class or widget that can be manually invoked and rendered
/// inside [AdminDeveloperTestMenuPage].
class AdminClassTestEntry {
  const AdminClassTestEntry({
    required this.id,
    required this.className,
    required this.packageOrModule,
    required this.title,
    required this.category,
    required this.description,
    required this.icon,
    required this.builder,
  });

  final String id;
  final String className;
  final String packageOrModule;
  final String title;
  final String category;
  final String description;
  final IconData icon;
  final WidgetBuilder builder;
}

/// Registry of classes/widgets available for manual invocation in Test Mode.
class AdminDeveloperTestRegistry {
  AdminDeveloperTestRegistry._();

  static final List<AdminClassTestEntry> _customEntries =
      <AdminClassTestEntry>[];

  static void register(AdminClassTestEntry entry) {
    _customEntries.removeWhere((item) => item.id == entry.id);
    _customEntries.add(entry);
  }

  static List<AdminClassTestEntry> get entries => <AdminClassTestEntry>[
    ..._builtInEntries,
    ..._customEntries,
  ];

  static final List<AdminClassTestEntry>
  _builtInEntries = <AdminClassTestEntry>[
    AdminClassTestEntry(
      id: 'asciicast_editor',
      className: 'AsciicastEditor / AsciicastEditorController',
      packageOrModule: 'package:asciicast_editor',
      title: 'AsciicastEditor 非线性终端录屏编辑器',
      category: '独立插件 (Packages)',
      description:
          '手动调用 asciicast_editor 非线性编辑器（NLE）与 termui_flutter 终端预览渲染，测试多轨时间轴、剃刀分割、倍速、标记自动暂停、查看最终结果与 .cast 导出。',
      icon: Icons.movie_creation_outlined,
      builder: (context) => const AsciicastEditorTestBench(),
    ),
    AdminClassTestEntry(
      id: 'asciicast_terminal_preview',
      className: 'AsciicastTerminalPreview',
      packageOrModule: 'package:asciicast_editor',
      title: 'AsciicastTerminalPreview 终端监视器渲染组件',
      category: '独立插件 (Packages)',
      description:
          '单独挂载 AsciicastTerminalPreview 终端画布组件，测试 termui_flutter 字符网格、ANSI 256 色渲染、亮暗主题切换及自定义 ANSI 序列实时注入。',
      icon: Icons.terminal_outlined,
      builder: (context) => const _AsciicastTerminalPreviewTestBench(),
    ),
    AdminClassTestEntry(
      id: 'asciinema_preview_card',
      className: 'AsciinemaPreviewCard',
      packageOrModule: 'components/markdown_protocol.dart',
      title: 'AsciinemaPreviewCard Markdown 录屏块卡片',
      category: '编辑器与协议组件',
      description:
          '手动调用后台文章编辑器中的 ::: asciinema-player 自定义容器预览卡片，测试属性解析、内嵌终端预览与 NLE 剪辑入口。',
      icon: Icons.smart_display_outlined,
      builder: (context) => const _AsciinemaPreviewCardTestBench(),
    ),
    AdminClassTestEntry(
      id: 'diff_viewer',
      className: 'DiffViewer',
      packageOrModule: 'components/diff_viewer.dart',
      title: 'DiffViewer 文本差异对比渲染器',
      category: '基础 UI 组件',
      description: '手动传入新旧文本，测试 DiffViewer 的语义级差异高亮渲染效果。',
      icon: Icons.difference_outlined,
      builder: (context) => const _DiffViewerTestBench(),
    ),
    AdminClassTestEntry(
      id: 'synonym_rule_editor',
      className: 'SynonymRuleEditor',
      packageOrModule: 'pages/elasticsearch_synonyms_page.dart',
      title: 'SynonymRuleEditor 同义词规则卡片组件',
      category: '业务表单组件',
      description: '独立挂载 Elasticsearch 同义词结构化卡片编辑器，测试词条增删与方向切换。',
      icon: Icons.rule_folder_outlined,
      builder: (context) => const _SynonymRuleEditorTestBench(),
    ),
  ];
}

/// Global coordinator for opening Developer Options (`\`` shortcut) and
/// navigating to the manual Class Test Menu.
class AdminDeveloperOptions {
  AdminDeveloperOptions._();

  static bool _isDialogOpen = false;
  static bool _isTestMenuOpen = false;

  static bool get isDialogOpen => _isDialogOpen;
  static bool get isTestMenuOpen => _isTestMenuOpen;

  static Future<void> show(BuildContext context) async {
    if (_isDialogOpen || !context.mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _isDialogOpen = true;
    try {
      await showDialog<void>(
        context: context,
        useRootNavigator: true,
        builder: (dialogContext) =>
            AdminDeveloperOptionsDialog(hostContext: context),
      );
    } finally {
      _isDialogOpen = false;
    }
  }

  static Future<void> openTestMenu(
    BuildContext context, {
    String initialEntryId = 'asciicast_editor',
  }) async {
    if (!context.mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final navigator = Navigator.of(context, rootNavigator: true);
    _isTestMenuOpen = true;
    try {
      await navigator.push<void>(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/developer/test-menu'),
          builder: (_) =>
              AdminDeveloperTestMenuPage(initialEntryId: initialEntryId),
        ),
      );
    } finally {
      _isTestMenuOpen = false;
    }
  }
}

/// Dialog opened when pressing the "`" key on the keyboard.
class AdminDeveloperOptionsDialog extends StatelessWidget {
  const AdminDeveloperOptionsDialog({super.key, required this.hostContext});

  final BuildContext hostContext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final entries = AdminDeveloperTestRegistry.entries;

    return Dialog(
      key: const Key('adminDeveloperOptionsDialog'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AdminTheme.brandColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.developer_mode_outlined,
                      color: AdminTheme.brandColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '开发者选项',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '快捷键: `',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '调试、主题预览与独立调用各模块类/组件的开发工具箱',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭 (Esc)',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AdminTheme.brandColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.science_outlined,
                          size: 20,
                          color: AdminTheme.brandColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '类与组件手动测试模式 (Test Mode)',
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text('已注册 ${entries.length} 个类'),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '无需登录后端或准备线上数据，直接手动实例化并渲染指定类（默认包含 AsciicastEditor 非线性终端录屏编辑器、AsciicastTerminalPreview、AsciinemaPreviewCard 等）。',
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          key: const Key('enterDeveloperTestMenuButton'),
                          onPressed: () {
                            Navigator.of(context).pop();
                            AdminDeveloperOptions.openTestMenu(hostContext);
                          },
                          icon: const Icon(Icons.widgets_outlined, size: 18),
                          label: const Text('进入测试菜单'),
                        ),
                        OutlinedButton.icon(
                          key: const Key('quickOpenAsciicastEditorTestButton'),
                          onPressed: () {
                            Navigator.of(context).pop();
                            AdminDeveloperOptions.openTestMenu(
                              hostContext,
                              initialEntryId: 'asciicast_editor',
                            );
                          },
                          icon: const Icon(
                            Icons.movie_creation_outlined,
                            size: 18,
                          ),
                          label: const Text('直接测试 AsciicastEditor 渲染'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.palette_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '外观主题快速切换',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  SegmentedButton<ThemeMode>(
                    segments: const <ButtonSegment<ThemeMode>>[
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_outlined, size: 16),
                        label: Text('浅色'),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_outlined, size: 16),
                        label: Text('深色'),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto_outlined, size: 16),
                        label: Text('系统'),
                      ),
                    ],
                    selected: <ThemeMode>{
                      AppThemeController.instance.themeMode,
                    },
                    onSelectionChanged: (selection) {
                      if (selection.isNotEmpty) {
                        AppThemeController.instance.setThemeMode(
                          selection.first,
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Interactive Test Menu page for manually invoking and rendering classes.
class AdminDeveloperTestMenuPage extends StatefulWidget {
  const AdminDeveloperTestMenuPage({
    super.key,
    this.initialEntryId = 'asciicast_editor',
  });

  final String initialEntryId;

  @override
  State<AdminDeveloperTestMenuPage> createState() =>
      _AdminDeveloperTestMenuPageState();
}

class _AdminDeveloperTestMenuPageState
    extends State<AdminDeveloperTestMenuPage> {
  final TextEditingController _searchController = TextEditingController();
  late String _selectedEntryId;
  String _searchQuery = '';
  bool _sidebarCollapsed = false;

  @override
  void initState() {
    super.initState();
    _selectedEntryId = widget.initialEntryId;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AdminClassTestEntry> get _filteredEntries {
    final all = AdminDeveloperTestRegistry.entries;
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((entry) {
      return entry.className.toLowerCase().contains(q) ||
          entry.title.toLowerCase().contains(q) ||
          entry.packageOrModule.toLowerCase().contains(q) ||
          entry.category.toLowerCase().contains(q) ||
          entry.description.toLowerCase().contains(q);
    }).toList();
  }

  AdminClassTestEntry get _activeEntry {
    final all = AdminDeveloperTestRegistry.entries;
    for (final entry in all) {
      if (entry.id == _selectedEntryId) return entry;
    }
    return all.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final active = _activeEntry;
    final filtered = _filteredEntries;

    return Scaffold(
      key: const Key('adminDeveloperTestMenuPage'),
      appBar: AppBar(
        titleSpacing: 8,
        title: Row(
          children: [
            const Icon(
              Icons.science_outlined,
              color: AdminTheme.brandColor,
              size: 22,
            ),
            const SizedBox(width: 10),
            const Text(
              '开发者测试菜单',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AdminTheme.brandColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                active.className,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AdminTheme.brandColor,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _sidebarCollapsed ? '展开类列表侧栏' : '收起类列表侧栏 (全屏查看当前类)',
            onPressed: () {
              setState(() => _sidebarCollapsed = !_sidebarCollapsed);
            },
            icon: Icon(
              _sidebarCollapsed
                  ? Icons.view_sidebar_outlined
                  : Icons.fullscreen_outlined,
            ),
          ),
          IconButton(
            tooltip: isDark ? '切换为浅色主题' : '切换为深色主题',
            onPressed: () {
              AppThemeController.instance.setThemeMode(
                isDark ? ThemeMode.light : ThemeMode.dark,
              );
            },
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_sidebarCollapsed)
            Container(
              width: 300,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFF8FAFC),
                border: Border(right: BorderSide(color: theme.dividerColor)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      key: const Key('developerTestClassSearchField'),
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() => _searchQuery = value);
                      },
                      decoration: InputDecoration(
                        hintText: '搜索类名、模块或关键字...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: _searchQuery.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              ),
                        isDense: true,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('未找到匹配的类'))
                        : ListView.separated(
                            padding: const EdgeInsets.all(8),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              final selected = item.id == active.id;
                              return Material(
                                color: selected
                                    ? AdminTheme.brandColor.withValues(
                                        alpha: isDark ? 0.22 : 0.12,
                                      )
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                child: InkWell(
                                  key: Key('developerTestEntry_${item.id}'),
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () {
                                    setState(() => _selectedEntryId = item.id);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              item.icon,
                                              size: 18,
                                              color: selected
                                                  ? AdminTheme.brandColor
                                                  : null,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                item.title,
                                                style: TextStyle(
                                                  fontWeight: selected
                                                      ? FontWeight.w700
                                                      : FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.className,
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 11,
                                            color: AdminTheme.brandColor,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          item.packageOrModule,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(fontSize: 11),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          item.description,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(fontSize: 11.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: KeyedSubtree(
              key: ValueKey<String>(active.id),
              child: active.builder(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Interactive workbench for testing [AsciicastEditor],
/// [AsciicastEditorController], and [AsciicastEditorDialog].
class AsciicastEditorTestBench extends StatefulWidget {
  const AsciicastEditorTestBench({super.key});

  @override
  State<AsciicastEditorTestBench> createState() =>
      _AsciicastEditorTestBenchState();
}

class _AsciicastEditorTestBenchState extends State<AsciicastEditorTestBench> {
  int _selectedPresetIndex = 0;
  late AsciicastEditorController _controller;
  String? _lastExportedCast;

  static const List<({String name, String clipName, String cast})> _presets = [
    (
      name: '预设 1：Quarkus 原生构建演练 (彩色 ANSI + 4 个标记 + 键盘输入)',
      clipName: 'quarkus-native-build.cast',
      cast:
          '{"version": 2, "width": 92, "height": 26, "timestamp": 1710000000, "title": "WindBlog Quarkus Native Build", "idle_time_limit": 2}\n'
          '[0.10, "o", "\\u001b[1;36mhhjmk@windblog\\u001b[0m:\\u001b[1;34m~/windblog_quarkus\\u001b[0m\$ "]\n'
          '[0.35, "i", "./mvnw package -Dnative"]\n'
          '[0.50, "o", "./mvnw package -Dnative\\r\\n"]\n'
          '[0.80, "m", "1. 关键命令：启动 GraalVM Native 构建"]\n'
          '[1.10, "o", "\\u001b[1;32m[INFO]\\u001b[0m Scanning for projects...\\r\\n"]\n'
          '[1.50, "o", "\\u001b[1;32m[INFO]\\u001b[0m Building \\u001b[1mwindblog-quarkus 1.0.0\\u001b[0m\\r\\n"]\n'
          '[2.00, "o", "\\u001b[36m[1/4] Initializing...\\u001b[0m                                            (2.1s @ 0.45GB)\\r\\n"]\n'
          '[2.60, "m", "2. 字节码分析与静态可达性扫描"]\n'
          '[2.80, "o", "\\u001b[36m[2/4] Performing analysis...\\u001b[0m  [\\u001b[32m████████████████████\\u001b[0m] 54,120 types  (5.4s @ 1.82GB)\\r\\n"]\n'
          '[3.50, "o", "\\u001b[36m[3/4] Compiling methods...\\u001b[0m    [\\u001b[33m████████████████████\\u001b[0m]  8,910 methods (4.2s @ 2.15GB)\\r\\n"]\n'
          '[4.20, "m", "3. 生成可执行二进制镜像"]\n'
          '[4.50, "o", "\\u001b[36m[4/4] Creating image...\\u001b[0m       [\\u001b[35m████████████████████\\u001b[0m]  68.4 MB       (1.9s @ 1.40GB)\\r\\n"]\n'
          '[5.10, "o", "\\r\\n┌──────────────────────────┬──────────────┬────────────┐\\r\\n"]\n'
          '[5.20, "o", "│ Artifact                 │ Size         │ Startup    │\\r\\n"]\n'
          '[5.30, "o", "├──────────────────────────┼──────────────┼────────────┤\\r\\n"]\n'
          '[5.40, "o", "│ windblog-1.0.0-runner    │ \\u001b[1;32m68.4 MB\\u001b[0m      │ \\u001b[1;32m0.042 s\\u001b[0m    │\\r\\n"]\n'
          '[5.50, "o", "└──────────────────────────┴──────────────┴────────────┘\\r\\n"]\n'
          '[6.00, "m", "4. 最终结果：Native 镜像构建完成"]\n'
          '[6.30, "o", "\\u001b[1;32mBUILD SUCCESS\\u001b[0m — Ready for container deployment.\\r\\n"]\n'
          '[6.60, "o", "\\u001b[1;36mhhjmk@windblog\\u001b[0m:\\u001b[1;34m~/windblog_quarkus\\u001b[0m\$ "]\n',
    ),
    (
      name: '预设 2：长停顿与敏感 Token 录屏 (测试空闲压缩 & 敏感词脱敏)',
      clipName: 'idle-and-secret-redact.cast',
      cast:
          '{"version": 2, "width": 84, "height": 24, "timestamp": 1710000100, "title": "Idle Compression & Secret Redaction Demo"}\n'
          '[0.10, "o", "\\u001b[32madmin@prod\\u001b[0m:\$ export API_TOKEN=sk-prod-9876543210abcdef\\r\\n"]\n'
          '[0.40, "i", "curl -H \\"Authorization: Bearer sk-prod-9876543210abcdef\\" https://api.example.com/v1/health"]\n'
          '[0.60, "o", "Connecting to api.example.com (waiting 5.5s idle)...\\r\\n"]\n'
          '[6.10, "m", "长停顿后响应到达"]\n'
          '[6.20, "o", "{\\"status\\": \\"UP\\", \\"token_hint\\": \\"sk-prod-9876543210abcdef\\"}\\r\\n"]\n'
          '[6.50, "o", "\\u001b[32madmin@prod\\u001b[0m:\$ "]\n',
    ),
    (
      name: '预设 3：ANSI 256 色色板与终端光标定位压测',
      clipName: 'ansi-palette-stress.cast',
      cast:
          '{"version": 2, "width": 80, "height": 24, "timestamp": 1710000200, "title": "ANSI Color Matrix"}\n'
          '[0.10, "o", "\\u001b[1;37m=== termui_flutter ANSI Color & Box Drawing Verification ===\\u001b[0m\\r\\n\\r\\n"]\n'
          '[0.30, "o", "Standard: \\u001b[31m■ Red \\u001b[32m■ Green \\u001b[33m■ Yellow \\u001b[34m■ Blue \\u001b[35m■ Magenta \\u001b[36m■ Cyan\\u001b[0m\\r\\n"]\n'
          '[0.60, "o", "Bright:   \\u001b[91m■ BRed \\u001b[92m■ BGreen \\u001b[93m■ BYellow \\u001b[94m■ BBlue \\u001b[95m■ BMag \\u001b[96m■ BCyan\\u001b[0m\\r\\n\\r\\n"]\n'
          '[0.90, "m", "渲染双线边框矩阵"]\n'
          '[1.10, "o", "╔══════════════════════════════════════════════╗\\r\\n"]\n'
          '[1.30, "o", "║  \\u001b[44;97m AsciicastEditor + termui_flutter Preview \\u001b[0m  ║\\r\\n"]\n'
          '[1.50, "o", "╚══════════════════════════════════════════════╝\\r\\n"]\n',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initController(0);
  }

  void _initController(int index) {
    final preset = _presets[index];
    _controller = AsciicastEditorController(
      initialCastContent: preset.cast,
      initialClipName: preset.clipName,
    );
  }

  void _selectPreset(int index) {
    final old = _controller;
    setState(() {
      _selectedPresetIndex = index;
      _initController(index);
    });
    old.dispose();
  }

  Future<void> _pickLocalCastFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['cast', 'txt', 'json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;
    final content = utf8.decode(bytes, allowMalformed: true);
    _controller.loadCastString(content, clipName: file.name);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已载入本地录屏文件：${file.name}')));
    }
  }

  Future<void> _openAsModalDialog() async {
    final currentCast = _controller.exportCast();
    final edited = await AsciicastEditorDialog.show(
      context,
      initialCastContent: currentCast,
      initialFileName: _presets[_selectedPresetIndex].clipName,
    );
    if (edited != null && mounted) {
      setState(() => _lastExportedCast = edited.castContent);
      _controller.loadCastString(edited.castContent, clipName: edited.fileName);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('模态编辑器已返回结果（共 ${edited.castContent.length} 字符）'),
        ),
      );
    }
  }

  void _showExportedCastDialog(String castContent) {
    setState(() => _lastExportedCast = castContent);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('导出的 .cast 文件内容'),
        content: SizedBox(
          width: 640,
          height: 360,
          child: SelectableText(
            castContent,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: castContent));
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已复制导出的 .cast 内容到剪贴板')),
              );
            },
            child: const Text('复制内容'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const Key('asciicastEditorTestBench'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(
                Icons.video_settings_outlined,
                size: 18,
                color: AdminTheme.brandColor,
              ),
              const Text(
                '测试数据源:',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              DropdownButton<int>(
                key: const Key('asciicastPresetSelector'),
                value: _selectedPresetIndex,
                isDense: true,
                underline: const SizedBox.shrink(),
                items: [
                  for (var i = 0; i < _presets.length; i++)
                    DropdownMenuItem<int>(
                      value: i,
                      child: Text(
                        _presets[i].name,
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) _selectPreset(value);
                },
              ),
              OutlinedButton.icon(
                onPressed: _pickLocalCastFile,
                icon: const Icon(Icons.folder_open_outlined, size: 16),
                label: const Text('加载本地 .cast'),
              ),
              OutlinedButton.icon(
                key: const Key('asciicastJumpFinalResultButton'),
                onPressed: () => _controller.jumpToFinalResult(),
                icon: const Icon(Icons.done_all_rounded, size: 16),
                label: const Text('调用 jumpToFinalResult()'),
              ),
              OutlinedButton.icon(
                key: const Key('asciicastModalInvokeButton'),
                onPressed: _openAsModalDialog,
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('弹窗调用 AsciicastEditorDialog'),
              ),
              if (_lastExportedCast != null)
                TextButton.icon(
                  onPressed: () => _showExportedCastDialog(_lastExportedCast!),
                  icon: const Icon(Icons.code_rounded, size: 16),
                  label: Text('查看最近导出 (${_lastExportedCast!.length} B)'),
                ),
            ],
          ),
        ),
        Expanded(
          child: AsciicastEditor(
            controller: _controller,
            initialFileName: _presets[_selectedPresetIndex].clipName,
            onExport: (result) => _showExportedCastDialog(result.castContent),
          ),
        ),
      ],
    );
  }
}

class _AsciicastTerminalPreviewTestBench extends StatefulWidget {
  const _AsciicastTerminalPreviewTestBench();

  @override
  State<_AsciicastTerminalPreviewTestBench> createState() =>
      _AsciicastTerminalPreviewTestBenchState();
}

class _AsciicastTerminalPreviewTestBenchState
    extends State<_AsciicastTerminalPreviewTestBench> {
  late final AsciicastEditorController _controller;
  final TextEditingController _ansiInputController = TextEditingController(
    text: r'\x1b[1;33m[Custom ANSI]\x1b[0m Hello from termui_flutter!\r\n',
  );

  @override
  void initState() {
    super.initState();
    _controller = AsciicastEditorController();
    _controller.jumpToFinalResult();
  }

  @override
  void dispose() {
    _ansiInputController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _appendCustomAnsiOutput() {
    final raw = _ansiInputController.text
        .replaceAll(r'\x1b', '\x1b')
        .replaceAll(r'\r', '\r')
        .replaceAll(r'\n', '\n');
    final exported = _controller.exportCast();
    final nextTime = (_controller.totalDuration + 0.25).toStringAsFixed(3);
    final updated = '$exported[$nextTime, "o", ${jsonEncode(raw)}]\n';
    _controller.loadCastString(updated, clipName: 'custom-ansi.cast');
    _controller.jumpToFinalResult();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ansiInputController,
                  decoration: const InputDecoration(
                    labelText: '追加自定义 ANSI 序列到终端缓冲区',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _appendCustomAnsiOutput,
                icon: const Icon(Icons.send_outlined, size: 16),
                label: const Text('注入并渲染'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(child: AsciicastTerminalPreview(controller: _controller)),
        ],
      ),
    );
  }
}

class _AsciinemaPreviewCardTestBench extends StatelessWidget {
  const _AsciinemaPreviewCardTestBench();

  @override
  Widget build(BuildContext context) {
    final element =
        md.Element('div', <md.Node>[
            md.Text('title: 终端录屏协议块测试\nsrc: /assets/demo.cast'),
          ])
          ..attributes['src'] = '/assets/demo.cast'
          ..attributes['title'] = 'WindBlog 终端录屏组件预览 (AsciinemaPreviewCard)'
          ..attributes['idletimelimit'] = '2'
          ..attributes['speed'] = '1.5'
          ..attributes['pauseonmarkers'] = 'true';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: AsciinemaPreviewCard(element: element),
        ),
      ),
    );
  }
}

class _DiffViewerTestBench extends StatefulWidget {
  const _DiffViewerTestBench();

  @override
  State<_DiffViewerTestBench> createState() => _DiffViewerTestBenchState();
}

class _DiffViewerTestBenchState extends State<_DiffViewerTestBench> {
  final TextEditingController _oldCtrl = TextEditingController(
    text:
        'AsciinemaPlayer.create("/assets/demo.cast", el, {\n  controls: true,\n});',
  );
  final TextEditingController _newCtrl = TextEditingController(
    text:
        'AsciinemaPlayer.create("/assets/demo.cast", el, {\n  controls: true,\n  idleTimeLimit: 2,\n  pauseOnMarkers: true,\n});',
  );

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _oldCtrl,
                maxLines: 5,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: '旧文本 (oldText)'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _newCtrl,
                maxLines: 5,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: '新文本 (newText)'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        DiffViewer(
          title: 'DiffViewer 实时渲染结果',
          oldText: _oldCtrl.text,
          newText: _newCtrl.text,
        ),
      ],
    );
  }
}

class _SynonymRuleEditorTestBench extends StatefulWidget {
  const _SynonymRuleEditorTestBench();

  @override
  State<_SynonymRuleEditorTestBench> createState() =>
      _SynonymRuleEditorTestBenchState();
}

class _SynonymRuleEditorTestBenchState
    extends State<_SynonymRuleEditorTestBench> {
  List<Map<String, dynamic>> _rules = <Map<String, dynamic>>[
    <String, dynamic>{
      'type': 'equivalent',
      'terms': <String>['asciinema', 'asciicast', '终端录屏'],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SynonymRuleEditor(
          initialValue: _rules,
          onChanged: (next) {
            setState(() => _rules = next);
          },
        ),
        const SizedBox(height: 16),
        SelectableText(
          '当前输出数据: ${jsonEncode(_rules)}',
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      ],
    );
  }
}
