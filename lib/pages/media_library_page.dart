part of 'package:windblog_admin_flutter/main.dart';

enum MediaFilter {
  all,
  failed,
  unreferenced,
  referenced,
}

class MediaLibraryPage extends StatefulWidget {
  const MediaLibraryPage({
    super.key,
    required this.api,
    required this.onAuthError,
  });

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<MediaLibraryPage> createState() => _MediaLibraryPageState();
}

class _MediaLibraryPageState extends State<MediaLibraryPage> {
  MediaFilter _filter = MediaFilter.all;
  MediaListResult? mediaResult;
  MediaScanResult? scanResult;
  bool loading = true;
  bool scanning = false;
  bool batchRetrying = false;
  int page = 1;
  static const int pageSize = 24;

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  String _filterToLabel(MediaFilter filter) {
    switch (filter) {
      case MediaFilter.all:
        return t(context, 'media_library');
      case MediaFilter.failed:
        return t(context, 'failed_imports');
      case MediaFilter.unreferenced:
        return t(context, 'unreferenced_files');
      case MediaFilter.referenced:
        return t(context, 'referenced');
    }
  }

  Future<void> _onFilterChanged(MediaFilter newFilter) async {
    setState(() {
      _filter = newFilter;
      page = 1;
      mediaResult = null;
    });
    await _loadMedia();
  }

  Future<void> _loadMedia() async {
    setState(() => loading = true);
    try {
      bool failedOnly = false;
      bool unreferenced = false;

      switch (_filter) {
        case MediaFilter.failed:
          failedOnly = true;
          break;
        case MediaFilter.unreferenced:
          unreferenced = true;
          break;
        case MediaFilter.all:
          break;
        case MediaFilter.referenced:
          break;
      }

      mediaResult = await widget.api.listMedia(
        page: page,
        pageSize: pageSize,
        failedOnly: failedOnly,
        unreferenced: unreferenced,
      );

      if (_filter == MediaFilter.referenced && mediaResult != null) {
        List<MediaItem> filteredItems = [];
        for (int i = 0; i < mediaResult!.items.length; i++) {
          MediaItem item = mediaResult!.items[i];
          if (item.references.isNotEmpty) {
            filteredItems.add(item);
          }
        }
        mediaResult = MediaListResult(
          items: filteredItems,
          total: filteredItems.length,
          page: page,
          pageSize: pageSize,
        );
      }
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t(context, 'load_media_failed')}$e')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _retryImport(MediaItem item) async {
    try {
      await widget.api.retryMedia(item.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(context, 'retry_success'))),
        );
      }
      await _loadMedia();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t(context, 'retry_failed')}$e')),
        );
      }
    }
  }

  Future<void> _batchRetry() async {
    setState(() => batchRetrying = true);
    try {
      int retriedCount = await widget.api.batchRetryMedia();
      await _loadMedia();
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) =>
              AlertDialog(
                title: Text(t(dialogContext, 'batch_retry_result')),
                content: Text(
                    '${t(dialogContext, 'retried_count')}: $retriedCount'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(t(dialogContext, 'close')),
                  ),
                ],
              ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t(context, 'batch_retry_failed')}$e')),
        );
      }
    } finally {
      if (mounted) setState(() => batchRetrying = false);
    }
  }

  Future<void> _scanReferences() async {
    setState(() => scanning = true);
    try {
      scanResult = await widget.api.scanMedia();
      await _loadMedia();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t(context, 'rescan_failed')}$e')),
        );
      }
    } finally {
      if (mounted) setState(() => scanning = false);
    }
  }

  Future<void> _uploadMedia() async {
    final result = await FilePicker.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;
    final mimeType = _resolveMimeType(file);

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
      const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在上传，请稍候...'),
          ],
        ),
      ),
    );

    try {
      final mediaItem = await widget.api.uploadMedia(
        fileName: file.name,
        bytes: bytes,
        mimeType: mimeType,
      );

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      // 开始轮询进度
      _showProcessingProgress(mediaItem);
      
      await _loadMedia();
    } on UnauthorizedException {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t(context, 'delete_failed')}$e')),
      );
    }
  }

  void _showProcessingProgress(MediaItem item) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
          _ProcessingProgressDialog(
            api: widget.api,
            initialItem: item,
            onDone: () {
              _loadMedia();
            },
          ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildToolbar(),
          const SizedBox(height: 12),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : _buildGridView(),
          ),
          const SizedBox(height: 8),
          _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    int total = mediaResult?.total ?? 0;

    return Column(
      children: [
        Row(
          children: [
            FilledButton(
              onPressed: _uploadMedia,
              child: Text(t(context, 'upload')),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: scanning ? null : _scanReferences,
              child: Text(scanning ? t(context, 'scanning') : t(context, 'rescan')),
            ),
            const SizedBox(width: 8),
            DropdownButton<MediaFilter>(
              value: _filter,
              items: MediaFilter.values.map((MediaFilter filter) {
                return DropdownMenuItem<MediaFilter>(
                  value: filter,
                  child: Text(_filterToLabel(filter)),
                );
              }).toList(),
              onChanged: (MediaFilter? newValue) {
                if (newValue != null) {
                  _onFilterChanged(newValue);
                }
              },
            ),
            const Spacer(),
            if (_filter == MediaFilter.failed)
              FilledButton.icon(
                onPressed: batchRetrying ? null : _batchRetry,
                icon: batchRetrying
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(Icons.refresh),
                label: Text(t(context, 'batch_retry')),
              ),
            const SizedBox(width: 8),
            Text('${t(context, 'total')}: $total'),
          ],
        ),
        if (scanResult != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              t(context, 'scan_result')
                  .replaceAll('%d', scanResult!.postsScanned.toString())
                  .replaceFirst('%d', scanResult!.referencesCreated.toString())
                  .replaceFirst('%d', scanResult!.unreferenced.toString()),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  Widget _buildGridView() {
    List<MediaItem> items = mediaResult?.items ?? [];
    if (items.isEmpty) {
      return Center(child: Text(t(context, 'no_media_found')));
    }
    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        MediaItem item = items[index];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _openMediaDetail(item),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    color: Colors.grey.shade100,
                    child: item.isImage
                        ? _ProgressiveImage(
                      previewUrl: item.previewUrl,
                      thumbnailUrl: item.thumbnailUrl,
                      fallbackUrl: item.url,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      api: widget.api,
                    )
                        : item.isVideo
                        ? const Icon(
                        Icons.video_library, size: 48, color: Colors.blue)
                        : item.isAudio
                        ? const Icon(
                        Icons.audiotrack, size: 48, color: Colors.orange)
                        : const Icon(
                        Icons.insert_drive_file, size: 48, color: Colors.grey),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      Text(
                        item.fileName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme
                            .of(context)
                            .textTheme
                            .bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatBytes(item.size),
                        style: Theme
                            .of(context)
                            .textTheme
                            .bodySmall,
                      ),
                      if (item.metadata['importStatus'] == 'failed')
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: TextButton(
                            onPressed: () => _retryImport(item),
                            child: Text(t(context, 'retry')),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openMediaDetail(MediaItem item) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) =>
          MediaDetailDialog(
            item: item,
            api: widget.api,
            onRetry: _retryImport,
            onScan: _scanReferences,
          ),
    );
  }

  Widget _buildPagination() {
    int total = mediaResult?.total ?? 0;
    return PaginationBar(
      currentPage: page,
      totalPages: (total / pageSize).ceil().clamp(1, 999999),
      totalItems: total,
      onPageChanged: (newPage) {
        setState(() => page = newPage);
        _loadMedia();
      },
    );
  }

  String _formatBytes(int? bytes) {
    if (bytes == null) return '-';
    if (bytes < 1024) return '$bytes B';
    final double kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final double mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

}

class _ProcessingProgressDialog extends StatefulWidget {
  final AdminApiClient api;
  final MediaItem initialItem;
  final VoidCallback onDone;

  const _ProcessingProgressDialog({
    required this.api,
    required this.initialItem,
    required this.onDone,
  });

  @override
  State<_ProcessingProgressDialog> createState() =>
      _ProcessingProgressDialogState();
}

class _ProcessingProgressDialogState extends State<_ProcessingProgressDialog> {
  late MediaItem currentItem;
  bool finished = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    currentItem = widget.initialItem;
    if (currentItem.processingStatus != 'COMPLETED' &&
        currentItem.processingStatus != 'FAILED') {
      _startPolling();
    } else {
      finished = true;
    }
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(milliseconds: 800), (timer) async {
      try {
        final updated = await widget.api.getMediaItem(currentItem.id);
        if (mounted) {
          setState(() {
            currentItem = updated;
            if (updated.processingStatus == 'COMPLETED' ||
                updated.processingStatus == 'FAILED') {
              finished = true;
              _timer?.cancel();
            }
          });
        }
      } catch (e) {
        // Ignore errors during polling
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = currentItem.processingStatus ?? 'PENDING';
    final progress = (currentItem.processingProgress ?? 0) / 100.0;
    final isFailed = status == 'FAILED';

    return AlertDialog(
      title: Text(
          isFailed ? '处理失败' : (finished ? '处理完成' : '媒体处理中')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isFailed) ...[
            LinearProgressIndicator(value: finished ? 1.0 : progress),
            const SizedBox(height: 16),
            Text('状态: ${_getStatusLabel(status)}'),
            if (!finished) const Text('正在生成 WebP 转换和变体，请稍候...'),
          ] else
            ...[
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text('错误: ${currentItem.processingError ?? '未知错误'}'),
            ],
        ],
      ),
      actions: [
        if (finished)
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDone();
            },
            child: const Text('完成'),
          ),
      ],
    );
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'PENDING':
        return '等待中';
      case 'PROCESSING':
        return '处理中';
      case 'COMPLETED':
        return '已完成';
      case 'FAILED':
        return '失败';
      default:
        return status;
    }
  }
}
