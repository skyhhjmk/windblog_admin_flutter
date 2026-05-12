part of 'package:windblog_admin_flutter/main.dart';

class MediaDetailDialog extends StatefulWidget {
  const MediaDetailDialog({
    super.key,
    required this.item,
    required this.api,
    this.onRetry,
    this.onScan,
  });

  static Future<void> show(BuildContext context, {
    required MediaItem item,
    required AdminApiClient api,
    Future<void> Function(MediaItem)? onRetry,
    Future<void> Function()? onScan,
  }) {
    return showDialog(
      context: context,
      builder: (context) =>
          MediaDetailDialog(
            item: item,
            api: api,
            onRetry: onRetry,
            onScan: onScan,
          ),
    );
  }

  final MediaItem item;
  final AdminApiClient api;
  final Future<void> Function(MediaItem)? onRetry;
  final Future<void> Function()? onScan;

  @override
  State<MediaDetailDialog> createState() => _MediaDetailDialogState();
}

class _MediaDetailDialogState extends State<MediaDetailDialog> {
  bool _loadOriginal = false;
  late MediaItem _item;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _loadOriginal = !_item.requiresManualOriginal;
  }

  void _openFullScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) =>
            _MediaFullScreenPreview(url: _item.url, api: widget.api),
      ),
    );
  }

  Future<void> _handleRetry() async {
    if (widget.onRetry == null) return;
    await widget.onRetry!(_item);
    // 重试后关闭弹窗，由页面刷新
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleScan() async {
    if (widget.onScan == null) return;
    await widget.onScan!();
    // 扫描后关闭弹窗，由页面刷新
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  String _formatBytes(int? bytes) {
    if (bytes == null) {
      return '-';
    }
    if (bytes < 1024) {
      return '$bytes B';
    }
    double kb = bytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }
    double mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 1000,
        height: 700,
        color: Colors.white,
        child: Row(
          children: [
            // 左侧预览区
            Expanded(
              flex: 3,
              child: _buildPreviewArea(),
            ),
            // 右侧侧边栏
            const VerticalDivider(width: 1, thickness: 1),
            SizedBox(
              width: 320,
              child: _buildSidebar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewArea() {
    return Container(
      color: const Color(0xFFF8F9FA),
      child: Stack(
        children: [
          Center(
            child: _buildMediaWidget(),
          ),
          // 全屏按钮悬浮
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.small(
              heroTag: 'full_screen_btn',
              onPressed: _openFullScreen,
              tooltip: t(context, 'full_screen'),
              child: const Icon(Icons.fullscreen),
            ),
          ),
          // 顶部关闭按钮
          Positioned(
            left: 16,
            top: 16,
            child: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaWidget() {
    if (_item.isImage) {
      if (_loadOriginal) {
        return Image.network(
          widget.api.normalizeUrl(_item.url),
          headers: const {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              Center(child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.broken_image, size: 64),
                  const SizedBox(height: 8),
                  Text('加载失败: $error',
                      style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              )),
        );
      }
      return _ProgressiveImage(
        previewUrl: _item.previewUrl,
        thumbnailUrl: _item.thumbnailUrl,
        fallbackUrl: _item.url,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.contain,
        api: widget.api,
      );
    }

    if (_item.isVideo) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
              Icons.play_circle_outline, size: 80, color: Colors.black54),
          const SizedBox(height: 12),
          Text(t(context, 'video_file'),
              style: const TextStyle(color: Colors.black54)),
        ],
      );
    }

    if (_item.isAudio) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.audiotrack, size: 64, color: Colors.orange),
          const SizedBox(width: 16),
          Text(t(context, 'audio_file'),
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      );
    }

    return const Icon(Icons.insert_drive_file, size: 80, color: Colors.grey);
  }

  Widget _buildSidebar() {
    return Column(
      children: [
        // 侧边栏标题
        Container(
          padding: const EdgeInsets.all(16),
          alignment: Alignment.centerLeft,
          child: Text(
            t(context, 'metadata'),
            style: Theme
                .of(context)
                .textTheme
                .titleLarge,
          ),
        ),
        const Divider(height: 1),
        // 内容滚动区
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoSection(),
                const SizedBox(height: 24),
                _buildImportSection(),
                const SizedBox(height: 24),
                _buildReferencesSection(),
                const SizedBox(height: 24),
                _buildMetadataSection(),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        // 底部操作区
        if (widget.onScan != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _handleScan,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(t(context, 'rescan_references')),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSidebarRow(t(context, 'media_name'), _item.fileName),
        _buildSidebarRow(t(context, 'media_type'), _item.mimeType),
        _buildSidebarRow(t(context, 'media_size'), _formatBytes(_item.size)),
        _buildSidebarRow(
            t(context, 'media_url'), _item.url, isSelectable: true),
        if (_item.requiresManualOriginal && !_loadOriginal)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: () => setState(() => _loadOriginal = true),
                child: Text(t(context, 'load_original_file')),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildImportSection() {
    bool isFailed = _isImportFailed();
    if (!isFailed) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t(context, 'import_info'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildSidebarRow(t(context, 'source_url'), _getSourceUrl(),
            isSelectable: true),
        _buildSidebarRow(t(context, 'failure_reason'), _getImportError(),
            isColorRed: true),
        _buildSidebarRow(
            t(context, 'last_retry_at'), _getMetadataValue('lastRetryAt')),
        const SizedBox(height: 8),
        if (widget.onRetry != null)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _handleRetry,
              icon: const Icon(Icons.replay),
              label: Text(t(context, 'retry')),
            ),
          ),
      ],
    );
  }

  Widget _buildReferencesSection() {
    if (_item.references.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t(context, 'references'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(t(context, 'none'),
              style: const TextStyle(color: Colors.black45, fontSize: 13)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t(context, 'references'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ..._item.references.map((ref) =>
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () {
                  // TODO: 跳转到文章编辑页
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.article_outlined,
                          size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ref.postTitle,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.blueAccent),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildMetadataSection() {
    if (_item.metadata.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t(context, 'all_metadata'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            children: _item.metadata.entries.map((e) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${e.key}: ',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold)),
                    Expanded(
                        child: Text('${e.value}',
                            style: const TextStyle(fontSize: 11))),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarRow(String label, String value,
      {bool isSelectable = false, bool isColorRed = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          if (isSelectable)
            SelectableText(
              value,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            )
          else
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: isColorRed ? Colors.red : Colors.black87,
              ),
            ),
        ],
      ),
    );
  }

  bool _isImportFailed() {
    Object? status = _item.metadata['importStatus'];
    if (status == null) {
      return false;
    }
    return status.toString() == 'failed';
  }

  String _getSourceUrl() {
    Object? sourceUrl = _item.metadata['sourceUrl'];
    if (sourceUrl == null) {
      return _item.url;
    }
    String urlText = sourceUrl.toString();
    if (urlText.isEmpty || urlText == 'null') {
      return _item.url;
    }
    return urlText;
  }

  String _getImportError() {
    Object? error = _item.metadata['importError'];
    if (error == null) {
      return t(context, 'unknown_error');
    }
    String errorText = error.toString();
    if (errorText.isEmpty || errorText == 'null') {
      return t(context, 'unknown_error');
    }
    return errorText;
  }

  String _getMetadataValue(String key) {
    Object? val = _item.metadata[key];
    if (val == null) {
      return '-';
    }
    return val.toString();
  }
}

class _MediaFullScreenPreview extends StatelessWidget {
  const _MediaFullScreenPreview({required this.url, required this.api});

  final String url;
  final AdminApiClient api;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.1,
              maxScale: 5.0,
              child: Image.network(
                api.normalizeUrl(url),
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                          : null,
                      color: Colors.white,
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
