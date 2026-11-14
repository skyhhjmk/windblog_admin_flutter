part of 'package:windblog_admin_flutter/main.dart';

class _SidebarAreaSpec {
  const _SidebarAreaSpec({
    required this.code,
    required this.label,
    required this.description,
    required this.icon,
  });

  final String code;
  final String label;
  final String description;
  final IconData icon;
}

class _SidebarWidgetCatalogItem {
  const _SidebarWidgetCatalogItem({
    required this.type,
    required this.label,
    required this.description,
    required this.icon,
    this.postOnly = false,
    this.singleton = true,
  });

  final String type;
  final String label;
  final String description;
  final IconData icon;
  final bool postOnly;
  final bool singleton;
}

class SidebarLayoutSettingsEditor extends StatefulWidget {
  const SidebarLayoutSettingsEditor({
    super.key,
    required this.initialValues,
    required this.onSave,
    required this.isFrozen,
  });

  final Map<String, dynamic> initialValues;
  final ValueChanged<Map<String, dynamic>> onSave;
  final bool isFrozen;

  @override
  State<SidebarLayoutSettingsEditor> createState() =>
      _SidebarLayoutSettingsEditorState();
}

class _SidebarLayoutSettingsEditorState
    extends State<SidebarLayoutSettingsEditor> {
  static const List<_SidebarAreaSpec> _areaSpecs = <_SidebarAreaSpec>[
    _SidebarAreaSpec(
      code: 'home',
      label: '首页侧边栏',
      description: '博客首页文章列表右侧显示的侧边栏区域。',
      icon: Icons.home_outlined,
    ),
    _SidebarAreaSpec(
      code: 'archive',
      label: '分类 / 标签 / 搜索页',
      description: '分类归档、标签归档与全站搜索结果页共用此侧边栏区域。',
      icon: Icons.category_outlined,
    ),
    _SidebarAreaSpec(
      code: 'link',
      label: '友链页侧边栏',
      description: '友情链接列表、友链详情与友链申请页显示的侧边栏区域。',
      icon: Icons.link_outlined,
    ),
    _SidebarAreaSpec(
      code: 'post',
      label: '文章详情页侧边栏',
      description: '文章阅读页侧边栏，支持文章目录、阅读偏好、教程进度、付费解锁与附件等专属小工具。',
      icon: Icons.article_outlined,
    ),
    _SidebarAreaSpec(
      code: 'default',
      label: '默认 / 工具与通用页',
      description: '实用工具箱、法务说明等未单独指定侧边栏的页面默认回退区域。',
      icon: Icons.widgets_outlined,
    ),
  ];

  static const List<_SidebarWidgetCatalogItem> _catalog =
      <_SidebarWidgetCatalogItem>[
        _SidebarWidgetCatalogItem(
          type: 'stats',
          label: '站点统计',
          description: '展示文章、评论、分类与标签数量统计卡片。',
          icon: Icons.analytics_outlined,
        ),
        _SidebarWidgetCatalogItem(
          type: 'recent_posts',
          label: '最新文章',
          description: '展示最新发布文章列表，可配置条数与是否显示日期。',
          icon: Icons.schedule_outlined,
        ),
        _SidebarWidgetCatalogItem(
          type: 'categories',
          label: '分类目录',
          description: '展示启用的文章分类及文章数量徽章。',
          icon: Icons.folder_outlined,
        ),
        _SidebarWidgetCatalogItem(
          type: 'tags',
          label: '标签云',
          description: '展示站点标签胶囊云，可配置最大显示数量。',
          icon: Icons.label_outlined,
        ),
        _SidebarWidgetCatalogItem(
          type: 'custom_html',
          label: '自定义 HTML / 公告',
          description: '支持任意自定义 HTML、公告文本或外链卡片，可添加多个实例。',
          icon: Icons.code_outlined,
          singleton: false,
        ),
        _SidebarWidgetCatalogItem(
          type: 'post_access',
          label: '付费内容权限',
          description: '付费文章专属：展示解锁积分价格与当前读者解锁状态。',
          icon: Icons.lock_open_outlined,
          postOnly: true,
        ),
        _SidebarWidgetCatalogItem(
          type: 'tutorial_tracker',
          label: '教程步骤进度',
          description: '教程模式文章专属：自动追踪并记录读者的章节学习进度。',
          icon: Icons.checklist_rtl_outlined,
          postOnly: true,
        ),
        _SidebarWidgetCatalogItem(
          type: 'toc',
          label: '文章目录 (TOC)',
          description: '文章页专属：自动提取正文标题生成滚动高亮目录。',
          icon: Icons.toc_outlined,
          postOnly: true,
        ),
        _SidebarWidgetCatalogItem(
          type: 'block_manager',
          label: '阅读偏好与区块大纲',
          description: '文章页专属：提供隐藏内容呈现方式、难度过滤与区块大纲。',
          icon: Icons.tune_outlined,
          postOnly: true,
        ),
        _SidebarWidgetCatalogItem(
          type: 'post_attachments',
          label: '文章附件列表',
          description: '文章页专属：当文章包含附件时展示附件下载/积分购买卡片。',
          icon: Icons.attach_file_outlined,
          postOnly: true,
        ),
        _SidebarWidgetCatalogItem(
          type: 'related_store',
          label: '关联商品推荐',
          description: '文章页专属：当文章关联了商店商品时展示推荐卡片。',
          icon: Icons.storefront_outlined,
          postOnly: true,
        ),
      ];

  String _selectedArea = 'home';
  late Map<String, List<Map<String, dynamic>>> _areas;
  final Set<String> _expandedWidgetIds = <String>{};
  int _idCounter = 1;

  @override
  void initState() {
    super.initState();
    _loadFromInitialValues();
  }

  @override
  void didUpdateWidget(covariant SidebarLayoutSettingsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValues != widget.initialValues) {
      _loadFromInitialValues();
    }
  }

  void _loadFromInitialValues() {
    final defaults = _buildDefaultAreas();
    final rawAreas = widget.initialValues['areas'];
    final loaded = <String, List<Map<String, dynamic>>>{};

    if (rawAreas is Map) {
      for (final spec in _areaSpecs) {
        final rawList = rawAreas[spec.code];
        if (rawList is List) {
          loaded[spec.code] = rawList
              .whereType<Map>()
              .map(
                (item) => _normalizeWidgetMap(
                  Map<String, dynamic>.from(item),
                  spec.code,
                ),
              )
              .toList();
        } else {
          loaded[spec.code] = List<Map<String, dynamic>>.from(
            defaults[spec.code]!.map((item) => Map<String, dynamic>.from(item)),
          );
        }
      }
    } else {
      for (final spec in _areaSpecs) {
        loaded[spec.code] = List<Map<String, dynamic>>.from(
          defaults[spec.code]!.map((item) => Map<String, dynamic>.from(item)),
        );
      }
    }

    _areas = loaded;
  }

  Map<String, dynamic> _normalizeWidgetMap(
    Map<String, dynamic> raw,
    String areaCode,
  ) {
    final type = (raw['type']?.toString() ?? 'stats').trim();
    final rawId = (raw['id']?.toString() ?? '').trim();
    final id = rawId.isNotEmpty
        ? rawId
        : '$areaCode-$type-${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';
    return <String, dynamic>{
      'id': id,
      'type': type,
      'enabled': raw['enabled'] is bool ? raw['enabled'] as bool : true,
      'title': raw['title']?.toString() ?? '',
      'limit': _parseInt(raw['limit'], _defaultLimitForType(type)),
      'showCount': raw['showCount'] is bool ? raw['showCount'] as bool : true,
      'showDate': raw['showDate'] is bool ? raw['showDate'] as bool : true,
      'showPosts': raw['showPosts'] is bool ? raw['showPosts'] as bool : true,
      'showComments': raw['showComments'] is bool
          ? raw['showComments'] as bool
          : true,
      'showCategories': raw['showCategories'] is bool
          ? raw['showCategories'] as bool
          : true,
      'showTags': raw['showTags'] is bool ? raw['showTags'] as bool : true,
      'content': raw['content']?.toString() ?? '',
      'showCardWrapper': raw['showCardWrapper'] is bool
          ? raw['showCardWrapper'] as bool
          : true,
    };
  }

  int _parseInt(dynamic val, int fallback) {
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? fallback;
    return fallback;
  }

  int _defaultLimitForType(String type) => switch (type) {
    'recent_posts' => 5,
    'categories' => 20,
    'tags' => 50,
    _ => 5,
  };

  Map<String, List<Map<String, dynamic>>> _buildDefaultAreas() {
    return <String, List<Map<String, dynamic>>>{
      'home': <Map<String, dynamic>>[
        _createDefaultWidget('home', 'stats', id: 'home-stats'),
        _createDefaultWidget('home', 'recent_posts', id: 'home-recent-posts'),
        _createDefaultWidget('home', 'categories', id: 'home-categories'),
        _createDefaultWidget('home', 'tags', id: 'home-tags'),
      ],
      'archive': <Map<String, dynamic>>[
        _createDefaultWidget('archive', 'categories', id: 'archive-categories'),
        _createDefaultWidget('archive', 'tags', id: 'archive-tags'),
        _createDefaultWidget(
          'archive',
          'recent_posts',
          id: 'archive-recent-posts',
        ),
        _createDefaultWidget('archive', 'stats', id: 'archive-stats'),
      ],
      'link': <Map<String, dynamic>>[
        _createDefaultWidget('link', 'stats', id: 'link-stats'),
        _createDefaultWidget('link', 'recent_posts', id: 'link-recent-posts'),
        _createDefaultWidget('link', 'tags', id: 'link-tags'),
      ],
      'post': <Map<String, dynamic>>[
        _createDefaultWidget('post', 'post_access', id: 'post-access'),
        _createDefaultWidget('post', 'tutorial_tracker', id: 'post-tutorial'),
        _createDefaultWidget('post', 'toc', id: 'post-toc'),
        _createDefaultWidget('post', 'block_manager', id: 'post-blocks'),
        _createDefaultWidget(
          'post',
          'post_attachments',
          id: 'post-attachments',
        ),
        _createDefaultWidget('post', 'related_store', id: 'post-store'),
        _createDefaultWidget('post', 'recent_posts', id: 'post-recent-posts'),
        _createDefaultWidget('post', 'tags', id: 'post-tags'),
      ],
      'default': <Map<String, dynamic>>[
        _createDefaultWidget('default', 'stats', id: 'default-stats'),
        _createDefaultWidget(
          'default',
          'recent_posts',
          id: 'default-recent-posts',
        ),
        _createDefaultWidget('default', 'tags', id: 'default-tags'),
      ],
    };
  }

  Map<String, dynamic> _createDefaultWidget(
    String areaCode,
    String type, {
    String? id,
  }) {
    final resolvedId =
        id ??
        '$areaCode-$type-${DateTime.now().millisecondsSinceEpoch}-${_idCounter++}';
    return <String, dynamic>{
      'id': resolvedId,
      'type': type,
      'enabled': true,
      'title': type == 'custom_html' ? '公告栏' : '',
      'limit': _defaultLimitForType(type),
      'showCount': true,
      'showDate': true,
      'showPosts': true,
      'showComments': true,
      'showCategories': true,
      'showTags': true,
      'content': type == 'custom_html' ? '<p>欢迎访问本站！</p>' : '',
      'showCardWrapper': true,
    };
  }

  _SidebarAreaSpec get _currentAreaSpec =>
      _areaSpecs.firstWhere((a) => a.code == _selectedArea);

  List<Map<String, dynamic>> get _currentWidgets =>
      _areas[_selectedArea] ?? <Map<String, dynamic>>[];

  _SidebarWidgetCatalogItem _catalogForType(String type) {
    return _catalog.firstWhere(
      (c) => c.type == type,
      orElse: () => _SidebarWidgetCatalogItem(
        type: type,
        label: type,
        description: '侧边栏小工具',
        icon: Icons.extension_outlined,
      ),
    );
  }

  bool _isTypeAlreadyInCurrentArea(String type) {
    return _currentWidgets.any((w) => w['type'] == type);
  }

  void _addWidgetToCurrentArea(String type) {
    if (widget.isFrozen) return;
    final catalogItem = _catalogForType(type);
    if (catalogItem.postOnly && _selectedArea != 'post') {
      setState(() {
        _selectedArea = 'post';
      });
    }
    final targetArea = catalogItem.postOnly ? 'post' : _selectedArea;
    final newWidget = _createDefaultWidget(targetArea, type);
    setState(() {
      _areas.putIfAbsent(targetArea, () => <Map<String, dynamic>>[]);
      _areas[targetArea]!.add(newWidget);
      if (type == 'custom_html') {
        _expandedWidgetIds.add(newWidget['id'] as String);
      }
    });
  }

  void _resetCurrentAreaToDefault() {
    if (widget.isFrozen) return;
    final defaults = _buildDefaultAreas();
    setState(() {
      _areas[_selectedArea] = List<Map<String, dynamic>>.from(
        defaults[_selectedArea]!,
      );
    });
  }

  void _resetAllAreasToDefault() {
    if (widget.isFrozen) return;
    setState(() {
      _areas = _buildDefaultAreas();
      _expandedWidgetIds.clear();
    });
  }

  void _saveLayout() {
    if (widget.isFrozen) return;
    final serializedAreas = <String, dynamic>{};
    for (final spec in _areaSpecs) {
      final list = _areas[spec.code] ?? const <Map<String, dynamic>>[];
      serializedAreas[spec.code] = list
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    widget.onSave(<String, dynamic>{'areas': serializedAreas});
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAreaTabs(context),
        const SizedBox(height: 16),
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 300, child: _buildWidgetPalette(context)),
              const SizedBox(width: 16),
              Expanded(child: _buildActiveAreaEditor(context)),
            ],
          )
        else ...[
          _buildActiveAreaEditor(context),
          const SizedBox(height: 16),
          _buildWidgetPalette(context),
        ],
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: widget.isFrozen ? null : _resetAllAreasToDefault,
              icon: const Icon(Icons.restore, size: 18),
              label: const Text('重置全部区域默认'),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: widget.isFrozen ? null : _saveLayout,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: Text(
                widget.isFrozen
                    ? '配置验证锁定中'
                    : t(context, 'sidebar_save_config', fallback: '保存侧边栏配置'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAreaTabs(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.view_sidebar_outlined,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '选择侧边栏场景区域（不同页面区域可独立配置小工具顺序与参数）',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _areaSpecs.map((spec) {
              final selected = spec.code == _selectedArea;
              final list = _areas[spec.code] ?? const <Map<String, dynamic>>[];
              final enabledCount = list
                  .where((w) => w['enabled'] == true)
                  .length;
              return ChoiceChip(
                avatar: Icon(spec.icon, size: 16),
                label: Text('${spec.label} ($enabledCount/${list.length})'),
                selected: selected,
                onSelected: (_) {
                  setState(() {
                    _selectedArea = spec.code;
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWidgetPalette(BuildContext context) {
    final theme = Theme.of(context);
    final isPostArea = _selectedArea == 'post';
    final generalItems = _catalog.where((c) => !c.postOnly).toList();
    final postOnlyItems = _catalog.where((c) => c.postOnly).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '可用小工具库',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '可拖拽小工具到右侧区域，或点击「+」直接添加。',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 12),
          Text(
            '通用小工具（全场景可用）',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          for (final item in generalItems)
            _buildPaletteItemCard(context, item, enabledInArea: true),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '文章详情页专属小工具',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ),
              if (!isPostArea)
                TextButton(
                  onPressed: () => setState(() => _selectedArea = 'post'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  child: const Text('切换到文章页', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (final item in postOnlyItems)
            _buildPaletteItemCard(context, item, enabledInArea: isPostArea),
        ],
      ),
    );
  }

  Widget _buildPaletteItemCard(
    BuildContext context,
    _SidebarWidgetCatalogItem item, {
    required bool enabledInArea,
  }) {
    final theme = Theme.of(context);
    final alreadyAdded =
        item.singleton && _isTypeAlreadyInCurrentArea(item.type);

    final cardContent = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: alreadyAdded
              ? theme.dividerColor.withValues(alpha: 0.4)
              : theme.colorScheme.primary.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        children: [
          Icon(
            item.icon,
            size: 18,
            color: enabledInArea
                ? theme.colorScheme.primary
                : theme.disabledColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (alreadyAdded && enabledInArea) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '已添加',
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: enabledInArea ? '添加到当前侧边栏' : '切换到文章详情页并添加',
            icon: const Icon(Icons.add_circle_outline, size: 20),
            visualDensity: VisualDensity.compact,
            onPressed: widget.isFrozen
                ? null
                : () => _addWidgetToCurrentArea(item.type),
          ),
        ],
      ),
    );

    if (widget.isFrozen || !enabledInArea) {
      return cardContent;
    }

    return Draggable<String>(
      data: item.type,
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 240,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.primary),
          ),
          child: Row(
            children: [
              Icon(item.icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.45, child: cardContent),
      child: cardContent,
    );
  }

  Widget _buildActiveAreaEditor(BuildContext context) {
    final theme = Theme.of(context);
    final areaSpec = _currentAreaSpec;
    final widgets = _currentWidgets;

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        if (widget.isFrozen) return false;
        final item = _catalogForType(details.data);
        if (item.postOnly && _selectedArea != 'post') return false;
        return true;
      },
      onAcceptWithDetails: (details) {
        _addWidgetToCurrentArea(details.data);
      },
      builder: (context, candidateData, rejectedData) {
        final isHoveringDrop = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isHoveringDrop
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.18)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isHoveringDrop
                  ? theme.colorScheme.primary
                  : theme.dividerColor.withValues(alpha: 0.6),
              width: isHoveringDrop ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(areaSpec.icon, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            areaSpec.label,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            areaSpec.description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.hintColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: widget.isFrozen
                            ? null
                            : () => _addWidgetToCurrentArea('custom_html'),
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(
                          t(
                            context,
                            'sidebar_add_custom_html',
                            fallback: '新增自定义 HTML',
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: widget.isFrozen
                            ? null
                            : _resetCurrentAreaToDefault,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('恢复当前区域默认'),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),
              if (isHoveringDrop)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.colorScheme.primary),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_box_outlined,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '松开鼠标即可将小工具添加到「${areaSpec.label}」',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              if (widgets.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 36,
                    horizontal: 16,
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(
                        Icons.widgets_outlined,
                        size: 36,
                        color: theme.disabledColor,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '当前侧边栏区域暂无小工具',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '从左侧小工具库拖拽或点击「+」添加组件，或点击右上角「恢复当前区域默认」。',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: widgets.length,
                  onReorderItem: (oldIndex, newIndex) {
                    if (widget.isFrozen) return;
                    setState(() {
                      final moved = widgets.removeAt(oldIndex);
                      widgets.insert(newIndex, moved);
                    });
                  },
                  itemBuilder: (context, index) {
                    final item = widgets[index];
                    final id =
                        item['id']?.toString() ?? '$_selectedArea-$index';
                    return _buildActiveWidgetCard(
                      context,
                      key: ValueKey('sidebar-widget-$id'),
                      widgetItem: item,
                      index: index,
                      totalCount: widgets.length,
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActiveWidgetCard(
    BuildContext context, {
    required Key key,
    required Map<String, dynamic> widgetItem,
    required int index,
    required int totalCount,
  }) {
    final theme = Theme.of(context);
    final id = widgetItem['id']?.toString() ?? '$index';
    final type = widgetItem['type']?.toString() ?? 'stats';
    final enabled = widgetItem['enabled'] == true;
    final customTitle = (widgetItem['title']?.toString() ?? '').trim();
    final catalog = _catalogForType(type);
    final expanded = _expandedWidgetIds.contains(id);

    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: enabled
              ? theme.dividerColor.withValues(alpha: 0.7)
              : theme.dividerColor.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              setState(() {
                if (expanded) {
                  _expandedWidgetIds.remove(id);
                } else {
                  _expandedWidgetIds.add(id);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  ReorderableDragStartListener(
                    index: index,
                    enabled: !widget.isFrozen,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      child: Icon(
                        Icons.drag_indicator,
                        size: 20,
                        color: widget.isFrozen
                            ? theme.disabledColor
                            : theme.hintColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    catalog.icon,
                    size: 18,
                    color: enabled
                        ? theme.colorScheme.primary
                        : theme.disabledColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                customTitle.isNotEmpty
                                    ? '${catalog.label} · $customTitle'
                                    : catalog.label,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: enabled ? null : theme.disabledColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '#${index + 1}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.hintColor,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _widgetSummarySubtitle(widgetItem, catalog),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            color: theme.hintColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: enabled,
                    onChanged: widget.isFrozen
                        ? null
                        : (val) {
                            setState(() {
                              widgetItem['enabled'] = val;
                            });
                          },
                  ),
                  IconButton(
                    tooltip: expanded ? '收起参数设置' : '展开参数设置',
                    icon: Icon(
                      expanded ? Icons.expand_less : Icons.tune_outlined,
                      size: 18,
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      setState(() {
                        if (expanded) {
                          _expandedWidgetIds.remove(id);
                        } else {
                          _expandedWidgetIds.add(id);
                        }
                      });
                    },
                  ),
                  IconButton(
                    tooltip: '移除此小工具',
                    icon: const Icon(Icons.delete_outline, size: 18),
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.isFrozen
                        ? null
                        : () {
                            setState(() {
                              _currentWidgets.removeAt(index);
                              _expandedWidgetIds.remove(id);
                            });
                          },
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: _buildWidgetConfigForm(context, widgetItem, catalog),
            ),
          ],
        ],
      ),
    );
  }

  String _widgetSummarySubtitle(
    Map<String, dynamic> widgetItem,
    _SidebarWidgetCatalogItem catalog,
  ) {
    final type = widgetItem['type']?.toString() ?? '';
    switch (type) {
      case 'recent_posts':
        final limit = widgetItem['limit'] ?? 5;
        final showDate = widgetItem['showDate'] != false;
        return '显示 $limit 篇最新文章 · ${showDate ? '含发布日期' : '隐藏日期'}';
      case 'categories':
        final limit = widgetItem['limit'] ?? 20;
        final showCount = widgetItem['showCount'] != false;
        return '最多显示 $limit 个分类 · ${showCount ? '显示文章数徽章' : '隐藏文章数'}';
      case 'tags':
        final limit = widgetItem['limit'] ?? 50;
        return '最多显示 $limit 个标签';
      case 'custom_html':
        final content = (widgetItem['content']?.toString() ?? '').trim();
        return content.isEmpty ? '尚未填写 HTML 内容' : content;
      default:
        return catalog.description;
    }
  }

  Widget _buildWidgetConfigForm(
    BuildContext context,
    Map<String, dynamic> widgetItem,
    _SidebarWidgetCatalogItem catalog,
  ) {
    final type = widgetItem['type']?.toString() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          initialValue: widgetItem['title']?.toString() ?? '',
          enabled: !widget.isFrozen,
          decoration: InputDecoration(
            labelText: '自定义标题（可选）',
            hintText: '留空则使用默认多语言标题（${catalog.label}）',
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (val) {
            setState(() {
              widgetItem['title'] = val;
            });
          },
        ),
        if (type == 'recent_posts') ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: '${widgetItem['limit'] ?? 5}',
                  enabled: !widget.isFrozen,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '显示文章条数 (1 - 20)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (val) {
                    final parsed = int.tryParse(val);
                    if (parsed != null) {
                      setState(() {
                        widgetItem['limit'] = parsed.clamp(1, 20);
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('显示发布日期'),
                  value: widgetItem['showDate'] != false,
                  onChanged: widget.isFrozen
                      ? null
                      : (val) => setState(() => widgetItem['showDate'] = val),
                ),
              ),
            ],
          ),
        ],
        if (type == 'categories') ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: '${widgetItem['limit'] ?? 20}',
                  enabled: !widget.isFrozen,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '最大显示分类数 (1 - 200)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (val) {
                    final parsed = int.tryParse(val);
                    if (parsed != null) {
                      setState(() {
                        widgetItem['limit'] = parsed.clamp(1, 200);
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('显示文章数徽章'),
                  value: widgetItem['showCount'] != false,
                  onChanged: widget.isFrozen
                      ? null
                      : (val) => setState(() => widgetItem['showCount'] = val),
                ),
              ),
            ],
          ),
        ],
        if (type == 'tags') ...[
          const SizedBox(height: 12),
          TextFormField(
            initialValue: '${widgetItem['limit'] ?? 50}',
            enabled: !widget.isFrozen,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '最大显示标签数 (1 - 500)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (val) {
              final parsed = int.tryParse(val);
              if (parsed != null) {
                setState(() {
                  widgetItem['limit'] = parsed.clamp(1, 500);
                });
              }
            },
          ),
        ],
        if (type == 'stats') ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              FilterChip(
                label: const Text('显示文章数'),
                selected: widgetItem['showPosts'] != false,
                onSelected: widget.isFrozen
                    ? null
                    : (val) => setState(() => widgetItem['showPosts'] = val),
              ),
              FilterChip(
                label: const Text('显示评论数'),
                selected: widgetItem['showComments'] != false,
                onSelected: widget.isFrozen
                    ? null
                    : (val) => setState(() => widgetItem['showComments'] = val),
              ),
              FilterChip(
                label: const Text('显示分类数'),
                selected: widgetItem['showCategories'] != false,
                onSelected: widget.isFrozen
                    ? null
                    : (val) =>
                          setState(() => widgetItem['showCategories'] = val),
              ),
              FilterChip(
                label: const Text('显示标签数'),
                selected: widgetItem['showTags'] != false,
                onSelected: widget.isFrozen
                    ? null
                    : (val) => setState(() => widgetItem['showTags'] = val),
              ),
            ],
          ),
        ],
        if (type == 'custom_html') ...[
          const SizedBox(height: 12),
          TextFormField(
            initialValue: widgetItem['content']?.toString() ?? '',
            enabled: !widget.isFrozen,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'HTML 或公告内容',
              hintText: '支持 HTML 标签（如 <p>、<a>、<img> 等）或纯文本',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            onChanged: (val) {
              setState(() {
                widgetItem['content'] = val;
              });
            },
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('使用标准侧边栏卡片外框样式'),
            subtitle: const Text('关闭后将直接渲染原始 HTML，不包裹默认圆角卡片边框'),
            value: widgetItem['showCardWrapper'] != false,
            onChanged: widget.isFrozen
                ? null
                : (val) => setState(() => widgetItem['showCardWrapper'] = val),
          ),
        ],
      ],
    );
  }
}
