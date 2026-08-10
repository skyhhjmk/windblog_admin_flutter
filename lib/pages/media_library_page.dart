part of 'package:windblog_admin_flutter/main.dart';

enum MediaFilter { all, failed, unreferenced, referenced }

String mediaVirusScanStatusLabel(BuildContext context, String status) {
  switch (status) {
    case 'CLEAN':
      return t(context, 'virus_scan_clean');
    case 'SCANNING':
      return t(context, 'virus_scan_scanning');
    case 'INFECTED':
      return t(context, 'virus_scan_infected');
    case 'UNAVAILABLE':
      return t(context, 'virus_scan_unavailable');
    case 'DISABLED':
      return t(context, 'virus_scan_disabled');
    case 'NOT_SCANNED':
    default:
      return t(context, 'virus_scan_not_scanned');
  }
}

Color mediaVirusScanStatusColor(BuildContext context, String status) {
  switch (status) {
    case 'CLEAN':
      return Colors.green.shade700;
    case 'SCANNING':
      return Theme.of(context).colorScheme.primary;
    case 'INFECTED':
      return Theme.of(context).colorScheme.error;
    case 'UNAVAILABLE':
      return Colors.orange.shade800;
    case 'DISABLED':
    case 'NOT_SCANNED':
    default:
      return Colors.grey.shade700;
  }
}

IconData mediaVirusScanStatusIcon(String status) {
  switch (status) {
    case 'CLEAN':
      return Icons.verified_user;
    case 'SCANNING':
      return Icons.sync;
    case 'INFECTED':
      return Icons.gpp_bad;
    case 'UNAVAILABLE':
      return Icons.warning_amber;
    case 'DISABLED':
      return Icons.security_update_warning;
    case 'NOT_SCANNED':
    default:
      return Icons.help_outline;
  }
}

class MediaVirusScanBadge extends StatelessWidget {
  const MediaVirusScanBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  final String status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = mediaVirusScanStatusColor(context, status);
    return Chip(
      avatar: Icon(
        mediaVirusScanStatusIcon(status),
        size: compact ? 14 : 18,
        color: color,
      ),
      label: Text(
        mediaVirusScanStatusLabel(context, status),
        style: TextStyle(
          color: color,
          fontSize: compact ? 11 : 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: color.withValues(alpha: 0.10),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      visualDensity: VisualDensity.compact,
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 2)
          : const EdgeInsets.symmetric(horizontal: 6),
    );
  }
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
  final Set<int> virusScanningIds = <int>{};
  int page = 1;
  static const int pageSize = 24;
  bool hasLoadedInitialMedia = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (hasLoadedInitialMedia) {
      return;
    }

    hasLoadedInitialMedia = true;
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
    final String loadFailedMessage = _loadMediaFailedMessage(context);
    await AdminRequestRunner.runVoid(
      context: context,
      mounted: mounted,
      onAuthError: widget.onAuthError,
      task: () async {
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
      },
      errorMessageBuilder: (error) {
        return '$loadFailedMessage$error';
      },
    );
    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> _retryImport(MediaItem item) async {
    final String retrySuccessMessage = _retrySuccessMessage(context);
    final String retryFailedMessage = _retryFailedMessage(context);
    await AdminRequestRunner.runVoid(
      context: context,
      mounted: mounted,
      onAuthError: widget.onAuthError,
      task: () async {
        await widget.api.retryMedia(item.id);
        if (mounted) {
          AdminFeedback.showSnackBar(
            context,
            SnackBar(content: Text(retrySuccessMessage)),
          );
        }
        await _loadMedia();
      },
      errorMessageBuilder: (error) {
        return '$retryFailedMessage$error';
      },
    );
  }

  Future<void> _batchRetry() async {
    setState(() => batchRetrying = true);
    final String batchRetryFailedMessage = _batchRetryFailedMessage(context);
    await AdminRequestRunner.runVoid(
      context: context,
      mounted: mounted,
      onAuthError: widget.onAuthError,
      task: () async {
        int retriedCount = await widget.api.batchRetryMedia();
        await _loadMedia();
        if (mounted) {
          await showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(t(dialogContext, 'batch_retry_result')),
              content: Text(
                '${t(dialogContext, 'retried_count')}: $retriedCount',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(t(dialogContext, 'close')),
                ),
              ],
            ),
          );
        }
      },
      errorMessageBuilder: (error) {
        return '$batchRetryFailedMessage$error';
      },
    );
    if (mounted) {
      setState(() => batchRetrying = false);
    }
  }

  Future<void> _scanReferences() async {
    setState(() => scanning = true);
    final String rescanFailedMessage = _rescanFailedMessage(context);
    await AdminRequestRunner.runVoid(
      context: context,
      mounted: mounted,
      onAuthError: widget.onAuthError,
      task: () async {
        scanResult = await widget.api.scanMedia();
        await _loadMedia();
      },
      errorMessageBuilder: (error) {
        return '$rescanFailedMessage$error';
      },
    );
    if (mounted) {
      setState(() => scanning = false);
    }
  }

  Future<MediaItem?> _scanVirus(MediaItem item) async {
    if (virusScanningIds.contains(item.id)) {
      return null;
    }
    setState(() => virusScanningIds.add(item.id));
    final notifications = AdminNotificationScope.of(context);
    final scanFailedMessage = _virusScanFailedMessage(context);
    final taskId = 'media-virus-scan-${item.id}';
    Future<void> reopenScan(BuildContext notificationContext) async {
      await MediaDetailDialog.show(
        notificationContext,
        item: item,
        api: widget.api,
        onVirusScan: (currentItem) {
          return widget.api.scanMediaVirus(currentItem.id);
        },
      );
    }

    notifications.showPersistent(
      taskId: taskId,
      title: '正在扫描媒体',
      message: item.fileName,
      progressMode: AdminNotificationProgressMode.indeterminate,
      reopen: reopenScan,
      persistenceData: <String, dynamic>{
        'type': 'media-virus-scan',
        'mediaId': item.id,
        'fileName': item.fileName,
      },
    );
    MediaItem? updated;
    try {
      final scannedItem = await widget.api.scanMediaVirus(item.id);
      updated = scannedItem;
      final status = mounted
          ? mediaVirusScanStatusLabel(context, scannedItem.virusScanStatus)
          : scannedItem.virusScanStatus;
      notifications.completePersistent(
        taskId: taskId,
        message: '$status: ${scannedItem.fileName}',
        failed: scannedItem.virusScanStatus == 'INFECTED',
        reopen: reopenScan,
      );
      if (mounted) {
        await _loadMedia();
      }
    } on UnauthorizedException {
      notifications.completePersistent(
        taskId: taskId,
        message: '登录已过期，病毒扫描未完成',
        failed: true,
        reopen: reopenScan,
      );
      if (mounted) widget.onAuthError();
    } catch (error) {
      notifications.completePersistent(
        taskId: taskId,
        message: '$scanFailedMessage$error',
        failed: true,
        reopen: reopenScan,
      );
    } finally {
      if (mounted) {
        setState(() => virusScanningIds.remove(item.id));
      }
    }
    return updated;
  }

  String _loadMediaFailedMessage(BuildContext context) {
    return t(context, 'load_media_failed');
  }

  String _retrySuccessMessage(BuildContext context) {
    return t(context, 'retry_success');
  }

  String _retryFailedMessage(BuildContext context) {
    return t(context, 'retry_failed');
  }

  String _batchRetryFailedMessage(BuildContext context) {
    return t(context, 'batch_retry_failed');
  }

  String _rescanFailedMessage(BuildContext context) {
    return t(context, 'rescan_failed');
  }

  String _virusScanFailedMessage(BuildContext context) {
    return t(context, 'virus_scan_failed');
  }

  Future<void> _uploadMedia() async {
    final result = await FilePicker.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;
    final mimeType = _resolveMimeType(file);

    if (!mounted) return;
    final notifications = AdminNotificationScope.of(context);

    try {
      await notifications.uploadMediaWithNotification(
        api: widget.api,
        fileName: file.name,
        bytes: bytes,
        mimeType: mimeType,
        onCompleted: () {
          if (mounted) unawaited(_loadMedia());
        },
      );
      if (mounted) await _loadMedia();
    } on UnauthorizedException {
      if (mounted) widget.onAuthError();
    } catch (_) {
      // 上传失败已经由持久通知显示，页面保持可操作。
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      title: t(context, 'media_library'),
      filters: _buildToolbar(),
      body: loading
          ? const AdminStatusView.loading(title: '正在加载媒体')
          : _buildGridView(),
      footer: _buildPagination(),
    );
  }

  Widget _buildToolbar() {
    int total = mediaResult?.total ?? 0;

    return AdminToolbar(
      children: [
        AdminActionButton(
          label: t(context, 'upload'),
          icon: Icons.upload_file,
          onPressed: _uploadMedia,
        ),
        AdminActionButton(
          label: scanning ? t(context, 'scanning') : t(context, 'rescan'),
          icon: Icons.sync,
          onPressed: scanning ? null : _scanReferences,
          isBusy: scanning,
        ),
        SizedBox(
          width: AdminBreakpoints.isPhone(context) ? double.infinity : 180,
          child: DropdownButtonFormField<MediaFilter>(
            initialValue: _filter,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.filter_list),
            ),
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
        ),
        if (_filter == MediaFilter.failed)
          AdminActionButton(
            label: t(context, 'batch_retry'),
            icon: Icons.refresh,
            onPressed: batchRetrying ? null : _batchRetry,
            isBusy: batchRetrying,
          ),
        Chip(label: Text('${t(context, 'total')}: $total')),
        if (scanResult != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
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
      return AdminStatusView.empty(title: t(context, 'no_media_found'));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        int columnCount = 4;
        if (constraints.maxWidth < 520) {
          columnCount = 2;
        } else if (constraints.maxWidth < 850) {
          columnCount = 3;
        } else if (constraints.maxWidth > 1400) {
          columnCount = 5;
        }

        return GridView.builder(
          physics: const BouncingScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnCount,
            childAspectRatio: 0.78,
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
                                Icons.video_library,
                                size: 48,
                                color: Colors.blue,
                              )
                            : item.isAudio
                            ? const Icon(
                                Icons.audiotrack,
                                size: 48,
                                color: Colors.orange,
                              )
                            : const Icon(
                                Icons.insert_drive_file,
                                size: 48,
                                color: Colors.grey,
                              ),
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
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatBytes(item.size),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          MediaVirusScanBadge(
                            status: item.virusScanStatus,
                            compact: true,
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
      },
    );
  }

  Future<void> _openMediaDetail(MediaItem item) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => MediaDetailDialog(
        item: item,
        api: widget.api,
        onRetry: _retryImport,
        onScan: _scanReferences,
        onVirusScan: _scanVirus,
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
  static const Duration _pollingTimeout = Duration(minutes: 2);
  static const int _maxConsecutivePollingErrors = 10;

  late MediaItem currentItem;
  bool finished = false;
  Timer? _timer;
  DateTime? _pollingStartedAt;
  bool _pollingRequestInFlight = false;
  int _consecutivePollingErrors = 0;
  String? _localError;

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
    _pollingStartedAt = DateTime.now();
    _timer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      _pollOnce();
    });
  }

  Future<void> _pollOnce() async {
    if (!mounted || finished || _pollingRequestInFlight) return;

    _pollingRequestInFlight = true;
    try {
      final updated = await widget.api.getMediaItem(currentItem.id);
      if (!mounted) return;

      _consecutivePollingErrors = 0;
      final bool terminal =
          updated.processingStatus == 'COMPLETED' ||
          updated.processingStatus == 'FAILED';
      setState(() {
        currentItem = updated;
        _localError = null;
        if (terminal) {
          finished = true;
        }
      });
      if (terminal) {
        _timer?.cancel();
      } else if (_hasTimedOut()) {
        _finishWithLocalError('后台媒体处理超时，请刷新媒体库查看最终状态');
      }
    } catch (error) {
      if (!mounted) return;
      _consecutivePollingErrors++;
      if (_consecutivePollingErrors >= _maxConsecutivePollingErrors ||
          _hasTimedOut()) {
        _finishWithLocalError('无法获取媒体处理状态，请刷新媒体库重试');
      }
    } finally {
      _pollingRequestInFlight = false;
    }
  }

  bool _hasTimedOut() {
    final startedAt = _pollingStartedAt;
    return startedAt != null &&
        DateTime.now().difference(startedAt) >= _pollingTimeout;
  }

  void _finishWithLocalError(String message) {
    if (!mounted) return;
    _timer?.cancel();
    setState(() {
      _localError = message;
      finished = true;
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
    final progressValue = (currentItem.processingProgress ?? 0).clamp(0, 100);
    final progress = progressValue / 100.0;
    final isFailed = status == 'FAILED' || _localError != null;
    final processingWarning = currentItem.metadata['processingWarning']
        ?.toString();

    return AlertDialog(
      title: Text(isFailed ? '处理失败' : (finished ? '处理完成' : '媒体处理中')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isFailed) ...[
            LinearProgressIndicator(value: finished ? 1.0 : progress),
            const SizedBox(height: 16),
            Text('状态: ${_getStatusLabel(status)}'),
            if (!finished) const Text('正在生成 WebP 转换和变体，请稍候...'),
            if (finished && processingWarning != null) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(child: Text('部分变体未生成：$processingWarning')),
                ],
              ),
            ],
          ] else ...[
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text('错误: ${currentItem.processingError ?? _localError ?? '未知错误'}'),
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
