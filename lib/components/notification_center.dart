part of 'package:windblog_admin_flutter/main.dart';

enum AdminNotificationKind { transient, persistent }

enum AdminNotificationSeverity { info, success, warning, error }

enum AdminNotificationProgressMode { none, determinate, indeterminate }

typedef AdminNotificationReopen = Future<void> Function(BuildContext context);

class AdminNotification {
  AdminNotification({
    required this.id,
    required this.sequence,
    required this.kind,
    required this.title,
    required this.message,
    required this.severity,
    this.taskId,
    this.progressMode = AdminNotificationProgressMode.none,
    this.progress,
    this.reopen,
    this.actionLabel,
    this.onAction,
    this.persistenceData = const <String, dynamic>{},
  }) : createdAt = DateTime.now();

  final String id;
  final int sequence;
  final String? taskId;
  final DateTime createdAt;
  final Map<String, dynamic> persistenceData;
  AdminNotificationKind kind;
  String title;
  String message;
  AdminNotificationSeverity severity;
  AdminNotificationProgressMode progressMode;
  double? progress;
  AdminNotificationReopen? reopen;
  String? actionLabel;
  VoidCallback? onAction;
  bool completed = false;
  int navigationLeaves = 0;
}

/// Mirrors in-app notification-stack entries to the operating system's
/// notification service. Web deliberately stays in-app: browser notifications
/// require a separate browser-permission and service-worker integration.
class _AdminSystemNotificationBridge {
  static const _channelId = 'windblog_admin_notifications';
  static const _channelName = 'WindBlog 管理通知';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  Future<bool>? _initialization;

  Future<void> show(int id, AdminNotification notification) async {
    if (kIsWeb || !await _ensureInitialized()) return;
    try {
      await _plugin.show(
        id: id,
        title: notification.title,
        body: notification.message,
        notificationDetails: _detailsFor(notification),
        payload: notification.id,
      );
    } catch (_) {
      // Native notifications are an enhancement; the in-app stack remains
      // available when a platform service or test environment is unavailable.
    }
  }

  Future<void> cancel(int id) async {
    if (kIsWeb || !await _ensureInitialized()) return;
    try {
      await _plugin.cancel(id: id);
    } catch (_) {
      // See show(): cancellation must not affect the in-app notification.
    }
  }

  Future<bool> _ensureInitialized() {
    return _initialization ??= _initialize();
  }

  Future<bool> _initialize() async {
    try {
      final initialized = await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_windblog'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: false,
            requestSoundPermission: true,
          ),
          macOS: DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: false,
            requestSoundPermission: true,
          ),
          linux: LinuxInitializationSettings(defaultActionName: '打开通知'),
          windows: WindowsInitializationSettings(
            appName: 'WindBlog Admin',
            appUserModelId: 'com.biliwind.blog.admin.windblog',
            guid: '8d11c9e5-07bb-4a24-9350-2c0f593fcf9a',
          ),
        ),
      );
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
      }
      return initialized ?? true;
    } catch (_) {
      return false;
    }
  }

  NotificationDetails _detailsFor(AdminNotification notification) {
    final isActiveTask =
        notification.kind == AdminNotificationKind.persistent &&
        !notification.completed;
    final progress =
        notification.progressMode ==
                AdminNotificationProgressMode.determinate &&
            notification.progress != null
        ? (notification.progress! * 100).round()
        : 0;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'WindBlog 管理后台的任务和操作通知',
        importance: isActiveTask
            ? Importance.low
            : Importance.defaultImportance,
        priority: isActiveTask ? Priority.low : Priority.defaultPriority,
        ongoing: isActiveTask,
        onlyAlertOnce: isActiveTask,
        showProgress:
            notification.progressMode != AdminNotificationProgressMode.none,
        maxProgress: 100,
        progress: progress,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: true,
      ),
      macOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: true,
      ),
      linux: LinuxNotificationDetails(
        category: LinuxNotificationCategory.im,
        resident: isActiveTask,
        transient: !isActiveTask,
        defaultActionName: '打开通知',
      ),
      windows: WindowsNotificationDetails(
        duration: isActiveTask
            ? WindowsNotificationDuration.long
            : WindowsNotificationDuration.short,
      ),
    );
  }
}

class AdminNotificationController extends ChangeNotifier {
  static const int transientLimit = 5;
  static const int persistentVisibleLimit = 10;
  static const Duration transientDuration = Duration(seconds: 5);

  final List<AdminNotification> _notifications = <AdminNotification>[];
  final Map<String, Timer> _expirationTimers = <String, Timer>{};
  final Map<String, Timer> _mediaPollingTimers = <String, Timer>{};
  final _AdminSystemNotificationBridge _systemNotifications =
      _AdminSystemNotificationBridge();
  final Map<String, int> _systemNotificationIds = <String, int>{};
  int _nextSystemNotificationId = 1;
  Timer? _persistenceTimer;
  DateTime? _lastPersistenceWrite;
  AdminApiClient? _api;
  bool _restoring = false;
  int _nextSequence = 0;

  List<AdminNotification> get notifications {
    final result = List<AdminNotification>.from(_notifications);
    result.sort((a, b) => b.sequence.compareTo(a.sequence));
    return List<AdminNotification>.unmodifiable(result);
  }

  List<AdminNotification> get persistentNotifications =>
      List<AdminNotification>.unmodifiable(
        notifications
            .where((item) => item.kind == AdminNotificationKind.persistent)
            .toList(),
      );

  List<AdminNotification> get transientNotifications =>
      List<AdminNotification>.unmodifiable(
        notifications
            .where((item) => item.kind == AdminNotificationKind.transient)
            .toList(),
      );

  String showTransient({
    required String message,
    String title = '提示',
    AdminNotificationSeverity severity = AdminNotificationSeverity.info,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final notification = AdminNotification(
      id: _newId(),
      sequence: _nextSequence++,
      kind: AdminNotificationKind.transient,
      title: title,
      message: message,
      severity: severity,
      actionLabel: actionLabel,
      onAction: onAction,
    );
    _notifications.add(notification);
    while (transientNotifications.length > transientLimit) {
      final oldest = transientNotifications.last;
      _remove(oldest.id, notify: false);
    }
    _scheduleExpiration(notification);
    _showSystemNotification(notification);
    notifyListeners();
    return notification.id;
  }

  String showPersistent({
    required String taskId,
    required String title,
    required String message,
    AdminNotificationSeverity severity = AdminNotificationSeverity.info,
    AdminNotificationProgressMode progressMode =
        AdminNotificationProgressMode.indeterminate,
    double? progress,
    AdminNotificationReopen? reopen,
    Map<String, dynamic> persistenceData = const <String, dynamic>{},
  }) {
    final existing = _findTask(taskId);
    if (existing != null) {
      existing.title = title;
      existing.message = message;
      existing.severity = severity;
      existing.progressMode = progressMode;
      existing.progress = _normalizeProgress(progress);
      existing.reopen = reopen ?? existing.reopen;
      existing.persistenceData.addAll(persistenceData);
      existing.completed = false;
      existing.navigationLeaves = 0;
      _showSystemNotification(existing);
      notifyListeners();
      _persistActiveTasks();
      return existing.id;
    }

    final notification = AdminNotification(
      id: _newId(),
      sequence: _nextSequence++,
      taskId: taskId,
      kind: AdminNotificationKind.persistent,
      title: title,
      message: message,
      severity: severity,
      progressMode: progressMode,
      progress: _normalizeProgress(progress),
      reopen: reopen,
      persistenceData: Map<String, dynamic>.from(persistenceData),
    );
    _notifications.add(notification);
    _showSystemNotification(notification);
    notifyListeners();
    _persistActiveTasks();
    return notification.id;
  }

  void updatePersistent({
    required String taskId,
    String? title,
    String? message,
    AdminNotificationSeverity? severity,
    AdminNotificationProgressMode? progressMode,
    double? progress,
    AdminNotificationReopen? reopen,
  }) {
    final notification = _findTask(taskId);
    if (notification == null) return;
    if (title != null) notification.title = title;
    if (message != null) notification.message = message;
    if (severity != null) notification.severity = severity;
    if (progressMode != null) notification.progressMode = progressMode;
    if (progress != null) {
      notification.progress = _normalizeProgress(progress);
    }
    if (reopen != null) notification.reopen = reopen;
    // Polling may update this object every few seconds. Keep those updates in
    // the in-app notification stack; re-showing the native notification here
    // makes the operating system alert on every poll.
    notifyListeners();
    if (!notification.completed) _persistActiveTasks();
  }

  void completePersistent({
    required String taskId,
    required String message,
    bool failed = false,
    AdminNotificationReopen? reopen,
  }) {
    final notification = _findTask(taskId);
    if (notification == null) return;
    notification.message = message;
    notification.severity = failed
        ? AdminNotificationSeverity.error
        : AdminNotificationSeverity.success;
    notification.progressMode = AdminNotificationProgressMode.determinate;
    notification.progress = failed ? notification.progress : 1.0;
    notification.completed = true;
    notification.reopen = reopen ?? notification.reopen;
    _mediaPollingTimers.remove(taskId)?.cancel();
    _showSystemNotification(notification);
    notifyListeners();
    _persistActiveTasks(immediate: true);
  }

  void dismiss(String id) {
    _remove(id);
  }

  void clear() {
    for (final timer in _expirationTimers.values) {
      timer.cancel();
    }
    for (final timer in _mediaPollingTimers.values) {
      timer.cancel();
    }
    _expirationTimers.clear();
    _mediaPollingTimers.clear();
    _persistenceTimer?.cancel();
    _persistenceTimer = null;
    _notifications.clear();
    for (final id in _systemNotificationIds.values) {
      unawaited(_systemNotifications.cancel(id));
    }
    _systemNotificationIds.clear();
    _api = null;
    _restoring = false;
    unawaited(_clearPersistedTasks());
    notifyListeners();
  }

  void recordNavigation() {
    final completed = _notifications
        .where(
          (item) =>
              item.kind == AdminNotificationKind.persistent && item.completed,
        )
        .toList();
    for (final notification in completed) {
      notification.navigationLeaves++;
      if (notification.navigationLeaves < 3) continue;
      notification.kind = AdminNotificationKind.transient;
      notification.navigationLeaves = 0;
      _scheduleExpiration(notification);
    }
    if (completed.isNotEmpty) {
      _persistActiveTasks();
      notifyListeners();
    }
  }

  void attachApi(AdminApiClient api) {
    if (identical(_api, api) && (_restoring || api.token == null)) return;
    _api = api;
    if (api.token == null || api.token!.isEmpty) return;
    if (_restoring) return;
    _restoring = true;
    unawaited(_restoreActiveTasks());
  }

  void trackTopicDiscovery({
    required AdminApiClient api,
    required Map<String, dynamic> run,
    VoidCallback? onCompleted,
  }) {
    final runId = toInt(run['id']);
    if (runId == null) return;
    final taskId = 'codex-topic-run-$runId';
    final reopen = _taskDetailsReopen(taskId);
    final status = run['status']?.toString() ?? 'QUEUED';
    showPersistent(
      taskId: taskId,
      title: '正在生成话题',
      message: _topicRunMessage(run),
      progressMode: AdminNotificationProgressMode.indeterminate,
      reopen: reopen,
      persistenceData: <String, dynamic>{
        'type': 'codex-topic-run',
        'runId': runId,
      },
    );
    if (status == 'SUCCEEDED' || status == 'FAILED') {
      completePersistent(
        taskId: taskId,
        message: _topicRunMessage(run),
        failed: status == 'FAILED',
        reopen: reopen,
      );
      onCompleted?.call();
      return;
    }
    _mediaPollingTimers.remove(taskId)?.cancel();
    _mediaPollingTimers[taskId] = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _pollTopicRun(
        api: api,
        taskId: taskId,
        runId: runId,
        reopen: reopen,
        onCompleted: onCompleted,
      ),
    );
  }

  void trackDraftGeneration({
    required AdminApiClient api,
    required Map<String, dynamic> job,
    bool regeneration = false,
    VoidCallback? onCompleted,
  }) {
    final jobId = toInt(job['id']);
    if (jobId == null) return;
    final taskId = 'codex-draft-job-$jobId';
    final reopen = _taskDetailsReopen(taskId);
    final status = job['status']?.toString() ?? 'REQUESTED';
    showPersistent(
      taskId: taskId,
      title: regeneration ? '正在重新生成草稿' : '正在生成草稿',
      message: _draftJobMessage(job, regeneration: regeneration),
      progressMode: AdminNotificationProgressMode.indeterminate,
      reopen: reopen,
      persistenceData: <String, dynamic>{
        'type': 'codex-draft-job',
        'jobId': jobId,
        'regeneration': regeneration,
      },
    );
    if (status == 'DRAFT_CREATED' || status == 'FAILED') {
      completePersistent(
        taskId: taskId,
        message: _draftJobMessage(job, regeneration: regeneration),
        failed: status == 'FAILED',
        reopen: reopen,
      );
      onCompleted?.call();
      return;
    }
    _mediaPollingTimers.remove(taskId)?.cancel();
    _mediaPollingTimers[taskId] = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _pollDraftJob(
        api: api,
        taskId: taskId,
        jobId: jobId,
        regeneration: regeneration,
        reopen: reopen,
        onCompleted: onCompleted,
      ),
    );
  }

  void trackMediaProcessing({
    required AdminApiClient api,
    required MediaItem item,
    required String fileName,
    String? taskId,
    AdminNotificationReopen? reopen,
    VoidCallback? onCompleted,
  }) {
    final resolvedTaskId = taskId ?? 'media-processing-${item.id}';
    final isTerminal = _isTerminal(item);
    if (isTerminal) {
      showPersistent(
        taskId: resolvedTaskId,
        title: '媒体处理完成',
        message: _mediaStatusMessage(item),
        severity: item.processingStatus == 'FAILED'
            ? AdminNotificationSeverity.error
            : AdminNotificationSeverity.success,
        progressMode: AdminNotificationProgressMode.determinate,
        progress: item.processingStatus == 'FAILED' ? null : 1,
        reopen: reopen,
        persistenceData: <String, dynamic>{
          'type': 'media-processing',
          'mediaId': item.id,
          'fileName': fileName,
        },
      );
      completePersistent(
        taskId: resolvedTaskId,
        message: _mediaStatusMessage(item),
        failed: item.processingStatus == 'FAILED',
        reopen: reopen,
      );
      onCompleted?.call();
      return;
    }

    showPersistent(
      taskId: resolvedTaskId,
      title: '正在处理媒体',
      message: '$fileName：${_mediaStatusMessage(item)}',
      progressMode: _progressMode(item),
      progress: _mediaProgress(item),
      reopen: reopen,
      persistenceData: <String, dynamic>{
        'type': 'media-processing',
        'mediaId': item.id,
        'fileName': fileName,
      },
    );
    _mediaPollingTimers.remove(resolvedTaskId)?.cancel();
    _mediaPollingTimers[resolvedTaskId] = Timer.periodic(
      const Duration(milliseconds: 900),
      (_) => _pollMediaTask(
        api: api,
        taskId: resolvedTaskId,
        mediaId: item.id,
        fileName: fileName,
        reopen: reopen,
        onCompleted: onCompleted,
      ),
    );
  }

  Future<MediaItem> uploadMediaWithNotification({
    required AdminApiClient api,
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    VoidCallback? onCompleted,
  }) async {
    final taskId = 'media-upload-${DateTime.now().microsecondsSinceEpoch}';

    Future<void> reopenUpload(BuildContext context) async {
      await showDialog<void>(
        context: context,
        builder: (_) =>
            _AdminNotificationDetailsDialog(taskId: taskId, controller: this),
      );
    }

    showPersistent(
      taskId: taskId,
      title: '正在上传媒体',
      message: '$fileName：准备上传',
      progressMode: AdminNotificationProgressMode.indeterminate,
      reopen: reopenUpload,
      persistenceData: <String, dynamic>{
        'type': 'media-upload',
        'fileName': fileName,
      },
    );

    DateTime? lastUploadProgressUpdate;
    try {
      final item = await api.uploadMediaResumable(
        fileName: fileName,
        bytes: bytes,
        mimeType: mimeType,
        onProgress: (progress) {
          final now = DateTime.now();
          if (progress < 1.0 &&
              lastUploadProgressUpdate != null &&
              now.difference(lastUploadProgressUpdate!) <
                  const Duration(milliseconds: 100)) {
            return;
          }
          lastUploadProgressUpdate = now;
          updatePersistent(
            taskId: taskId,
            message: '$fileName：上传 ${(progress * 100).round()}%',
            progressMode: AdminNotificationProgressMode.determinate,
            progress: progress,
          );
        },
      );

      Future<void> reopenProcessing(BuildContext context) async {
        final currentItem = await api.getMediaItem(item.id);
        if (!context.mounted) return;
        await showDialog<void>(
          context: context,
          builder: (_) => _ProcessingProgressDialog(
            api: api,
            initialItem: currentItem,
            onDone: () {},
          ),
        );
      }

      trackMediaProcessing(
        api: api,
        item: item,
        fileName: fileName,
        taskId: taskId,
        reopen: reopenProcessing,
        onCompleted: onCompleted,
      );
      return item;
    } on UnauthorizedException {
      completePersistent(
        taskId: taskId,
        message: '登录已过期，上传未完成',
        failed: true,
        reopen: reopenUpload,
      );
      rethrow;
    } catch (error) {
      completePersistent(
        taskId: taskId,
        message: '上传失败：$error',
        failed: true,
        reopen: reopenUpload,
      );
      rethrow;
    }
  }

  void _scheduleExpiration(AdminNotification notification) {
    _expirationTimers.remove(notification.id)?.cancel();
    _expirationTimers[notification.id] = Timer(transientDuration, () {
      _remove(notification.id);
    });
  }

  Future<void> _pollMediaTask({
    required AdminApiClient api,
    required String taskId,
    required int mediaId,
    required String fileName,
    required AdminNotificationReopen? reopen,
    required VoidCallback? onCompleted,
  }) async {
    final notification = _findTask(taskId);
    if (notification == null || notification.completed) return;
    try {
      final item = await api.getMediaItem(mediaId);
      if (_isTerminal(item)) {
        completePersistent(
          taskId: taskId,
          message: '$fileName：${_mediaStatusMessage(item)}',
          failed: item.processingStatus == 'FAILED',
          reopen: reopen,
        );
        onCompleted?.call();
        return;
      }
      updatePersistent(
        taskId: taskId,
        message: '$fileName：${_mediaStatusMessage(item)}',
        progressMode: _progressMode(item),
        progress: _mediaProgress(item),
        reopen: reopen,
      );
    } catch (_) {
      updatePersistent(
        taskId: taskId,
        message: '$fileName：正在等待服务器返回处理状态',
        progressMode: AdminNotificationProgressMode.indeterminate,
      );
    }
  }

  Future<void> _restoreActiveTasks() async {
    final api = _api;
    if (api == null) return;
    List<Map<String, dynamic>> records;
    try {
      records = await StorageService.getNotificationTasks();
    } catch (_) {
      return;
    }
    for (final record in records) {
      if (record['type'] == 'codex-topic-run') {
        final runId = toInt(record['runId']);
        if (runId == null) continue;
        try {
          trackTopicDiscovery(
            api: api,
            run: await api.codexCreatorTopicRun(runId),
          );
        } catch (_) {
          trackTopicDiscovery(
            api: api,
            run: <String, dynamic>{'id': runId, 'status': 'QUEUED'},
          );
          updatePersistent(
            taskId: 'codex-topic-run-$runId',
            title: '话题生成等待恢复',
            message: '暂时无法获取服务端状态，将继续等待',
          );
        }
        continue;
      }
      if (record['type'] == 'codex-draft-job') {
        final jobId = toInt(record['jobId']);
        if (jobId == null) continue;
        final regeneration = record['regeneration'] == true;
        try {
          trackDraftGeneration(
            api: api,
            job: await api.codexCreatorDraftJob(jobId),
            regeneration: regeneration,
          );
        } catch (_) {
          trackDraftGeneration(
            api: api,
            job: <String, dynamic>{'id': jobId, 'status': 'REQUESTED'},
            regeneration: regeneration,
          );
          updatePersistent(
            taskId: 'codex-draft-job-$jobId',
            title: regeneration ? '草稿重新生成等待恢复' : '草稿生成等待恢复',
            message: '暂时无法获取服务端状态，将继续等待',
          );
        }
        continue;
      }
      if (record['type'] != 'media-processing') continue;
      final mediaId = toInt(record['mediaId']);
      if (mediaId == null) continue;
      final fileName = record['fileName']?.toString() ?? '媒体文件';
      try {
        final item = await api.getMediaItem(mediaId);
        if (_isTerminal(item)) continue;
        final reopen = _mediaReopen(api, mediaId, fileName);
        trackMediaProcessing(
          api: api,
          item: item,
          fileName: fileName,
          reopen: reopen,
        );
      } catch (_) {
        showPersistent(
          taskId: 'media-processing-$mediaId',
          title: '媒体处理等待恢复',
          message: '$fileName：暂时无法获取服务端状态',
          progressMode: AdminNotificationProgressMode.indeterminate,
          reopen: _mediaReopen(api, mediaId, fileName),
          persistenceData: record,
        );
      }
    }
    _persistActiveTasks(immediate: true);
  }

  Future<void> _pollTopicRun({
    required AdminApiClient api,
    required String taskId,
    required int runId,
    required AdminNotificationReopen reopen,
    required VoidCallback? onCompleted,
  }) async {
    final notification = _findTask(taskId);
    if (notification == null || notification.completed) return;
    try {
      final run = await api.codexCreatorTopicRun(runId);
      final status = run['status']?.toString() ?? '';
      if (status == 'SUCCEEDED' || status == 'FAILED') {
        completePersistent(
          taskId: taskId,
          message: _topicRunMessage(run),
          failed: status == 'FAILED',
          reopen: reopen,
        );
        onCompleted?.call();
        return;
      }
      updatePersistent(taskId: taskId, message: _topicRunMessage(run));
    } catch (_) {
      updatePersistent(taskId: taskId, message: '话题生成中，正在等待服务器状态');
    }
  }

  Future<void> _pollDraftJob({
    required AdminApiClient api,
    required String taskId,
    required int jobId,
    required bool regeneration,
    required AdminNotificationReopen reopen,
    required VoidCallback? onCompleted,
  }) async {
    final notification = _findTask(taskId);
    if (notification == null || notification.completed) return;
    try {
      final job = await api.codexCreatorDraftJob(jobId);
      final status = job['status']?.toString() ?? '';
      if (status == 'DRAFT_CREATED' || status == 'FAILED') {
        completePersistent(
          taskId: taskId,
          message: _draftJobMessage(job, regeneration: regeneration),
          failed: status == 'FAILED',
          reopen: reopen,
        );
        onCompleted?.call();
        return;
      }
      updatePersistent(
        taskId: taskId,
        message: _draftJobMessage(job, regeneration: regeneration),
      );
    } catch (_) {
      updatePersistent(taskId: taskId, message: '草稿生成中，正在等待服务器状态');
    }
  }

  String _topicRunMessage(Map<String, dynamic> run) {
    final status = run['status']?.toString() ?? 'QUEUED';
    if (status == 'SUCCEEDED') {
      return '话题生成完成，共生成或更新 ${toInt(run['topicCount']) ?? 0} 个话题';
    }
    if (status == 'FAILED') return '话题生成失败：${run['error'] ?? '未知错误'}';
    if (status == 'RUNNING') return '正在检索资料并生成话题';
    return '话题任务已进入队列';
  }

  String _draftJobMessage(
    Map<String, dynamic> job, {
    required bool regeneration,
  }) {
    final status = job['status']?.toString() ?? 'REQUESTED';
    if (status == 'DRAFT_CREATED') {
      final postId = toInt(job['postId']);
      return regeneration
          ? '草稿已重新生成${postId == null ? '' : '，文章 #$postId 已创建新修订'}'
          : '草稿生成完成${postId == null ? '' : '，已保存为文章 #$postId'}';
    }
    if (status == 'FAILED') return '草稿生成失败：${job['error'] ?? '未知错误'}';
    if (status == 'REGENERATING') return '正在重新研究并生成草稿新修订';
    if (status == 'READY') return '内容已生成，正在保存到 WindBlog';
    return regeneration ? '正在重新生成草稿' : '正在研究并生成草稿';
  }

  AdminNotificationReopen _taskDetailsReopen(String taskId) {
    return (BuildContext context) async {
      await showDialog<void>(
        context: context,
        builder: (_) =>
            _AdminNotificationDetailsDialog(taskId: taskId, controller: this),
      );
    };
  }

  AdminNotificationReopen _mediaReopen(
    AdminApiClient api,
    int mediaId,
    String fileName,
  ) {
    return (BuildContext context) async {
      try {
        final item = await api.getMediaItem(mediaId);
        if (!context.mounted) return;
        await showDialog<void>(
          context: context,
          barrierDismissible: true,
          builder: (_) => _ProcessingProgressDialog(
            api: api,
            initialItem: item,
            onDone: () {},
          ),
        );
      } catch (error) {
        if (context.mounted) {
          AdminFeedback.error(context, '无法打开媒体处理状态：$error');
        }
      }
    };
  }

  void _persistActiveTasks({bool immediate = false}) {
    final now = DateTime.now();
    final lastWrite = _lastPersistenceWrite;
    if (!immediate &&
        lastWrite != null &&
        now.difference(lastWrite) < const Duration(milliseconds: 300)) {
      _persistenceTimer ??= Timer(const Duration(milliseconds: 300), () {
        _persistenceTimer = null;
        _persistActiveTasks(immediate: true);
      });
      return;
    }
    _persistenceTimer?.cancel();
    _persistenceTimer = null;
    _lastPersistenceWrite = now;
    unawaited(_savePersistedTasks());
  }

  Future<void> _savePersistedTasks() async {
    try {
      await StorageService.saveNotificationTasks(
        _notifications
            .where(
              (item) =>
                  item.kind == AdminNotificationKind.persistent &&
                  !item.completed,
            )
            .map((item) => item.persistenceData)
            .toList(),
      );
    } catch (_) {
      // Storage is optional in tests and on platforms without preferences.
    }
  }

  Future<void> _clearPersistedTasks() async {
    try {
      await StorageService.clearNotificationTasks();
    } catch (_) {
      // Storage is optional in tests and on platforms without preferences.
    }
  }

  AdminNotification? _findTask(String taskId) {
    for (final notification in _notifications) {
      if (notification.taskId == taskId) return notification;
    }
    return null;
  }

  void _remove(String id, {bool notify = true}) {
    final index = _notifications.indexWhere((item) => item.id == id);
    if (index < 0) return;
    _expirationTimers.remove(id)?.cancel();
    final notification = _notifications.removeAt(index);
    final systemId = _systemNotificationIds.remove(id);
    if (systemId != null) unawaited(_systemNotifications.cancel(systemId));
    if (notification.taskId != null) {
      _mediaPollingTimers.remove(notification.taskId!)?.cancel();
    }
    _persistActiveTasks(immediate: true);
    if (notify) notifyListeners();
  }

  String _newId() {
    return '${DateTime.now().microsecondsSinceEpoch}-${_notifications.length}';
  }

  void _showSystemNotification(AdminNotification notification) {
    final id = _systemNotificationIds.putIfAbsent(
      notification.id,
      () => _nextSystemNotificationId++,
    );
    unawaited(_systemNotifications.show(id, notification));
  }

  double? _normalizeProgress(double? progress) {
    if (progress == null) return null;
    if (progress.isNaN || progress.isInfinite) return null;
    return progress.clamp(0.0, 1.0);
  }

  bool _isTerminal(MediaItem item) {
    return item.processingStatus == 'COMPLETED' ||
        item.processingStatus == 'FAILED';
  }

  AdminNotificationProgressMode _progressMode(MediaItem item) {
    final progress = item.processingProgress;
    if (progress == null ||
        (progress <= 0 && item.processingStatus == 'PENDING')) {
      return AdminNotificationProgressMode.indeterminate;
    }
    return AdminNotificationProgressMode.determinate;
  }

  double? _mediaProgress(MediaItem item) {
    final progress = item.processingProgress;
    if (progress == null) return null;
    return (progress / 100).clamp(0.0, 1.0);
  }

  String _mediaStatusMessage(MediaItem item) {
    if (item.processingStatus == 'FAILED') {
      return item.processingError?.isNotEmpty == true
          ? '处理失败：${item.processingError}'
          : '处理失败';
    }
    if (item.processingStatus == 'COMPLETED') return '处理完成';
    final progress = item.processingProgress;
    if (progress == null || progress <= 0) return '等待处理';
    return '处理进度 $progress%';
  }
}

class AdminNotificationScope
    extends InheritedNotifier<AdminNotificationController> {
  const AdminNotificationScope({
    super.key,
    required AdminNotificationController controller,
    required super.child,
  }) : super(notifier: controller);

  static AdminNotificationController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AdminNotificationScope>()
        ?.notifier;
  }

  static AdminNotificationController of(BuildContext context) {
    final controller = maybeOf(context);
    if (controller == null) {
      throw FlutterError('AdminNotificationScope is missing');
    }
    return controller;
  }
}

class AdminNotificationHost extends StatelessWidget {
  const AdminNotificationHost({
    super.key,
    required this.api,
    required this.controller,
    required this.child,
  });

  final AdminApiClient api;
  final AdminNotificationController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    controller.attachApi(api);
    return AdminNotificationScope(
      controller: controller,
      child: Stack(
        fit: StackFit.expand,
        children: [child, const _AdminNotificationPanel()],
      ),
    );
  }
}

class _AdminNotificationPanel extends StatelessWidget {
  const _AdminNotificationPanel();

  @override
  Widget build(BuildContext context) {
    final controller = AdminNotificationScope.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final items = controller.notifications;
        if (items.isEmpty) return const SizedBox.shrink();
        return Positioned(
          right: 16,
          bottom: 16,
          child: SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: AdminBreakpoints.isPhone(context) ? 420 : 440,
                maxHeight: MediaQuery.sizeOf(context).height * 0.72,
              ),
              child: SizedBox(
                width: AdminBreakpoints.isPhone(context)
                    ? MediaQuery.sizeOf(context).width - 32
                    : 420,
                child: MouseRegion(
                  child: Card(
                    margin: EdgeInsets.zero,
                    elevation: 12,
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.bottomRight,
                      child: Scrollbar(
                        thumbVisibility:
                            items.length >
                            AdminNotificationController.persistentVisibleLimit,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(10),
                          shrinkWrap: true,
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return _AdminNotificationCard(
                              key: ValueKey<String>(item.id),
                              item: item,
                              onDismiss: () => controller.dismiss(item.id),
                              onTap: item.reopen == null
                                  ? null
                                  : () => item.reopen!(context),
                            );
                          },
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AdminNotificationDetailsDialog extends StatelessWidget {
  const _AdminNotificationDetailsDialog({
    required this.taskId,
    required this.controller,
  });

  final String taskId;
  final AdminNotificationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        AdminNotification? item;
        for (final candidate in controller.notifications) {
          if (candidate.taskId == taskId) {
            item = candidate;
            break;
          }
        }
        if (item == null) {
          return const AlertDialog(content: Text('任务已结束或通知已关闭'));
        }
        return AlertDialog(
          title: Text(item.title),
          content: Row(
            children: [
              _NotificationProgressIndicator(
                item: item,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(item.message)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }
}

class _AdminNotificationCard extends StatelessWidget {
  const _AdminNotificationCard({
    super.key,
    required this.item,
    required this.onDismiss,
    this.onTap,
  });

  final AdminNotification item;
  final VoidCallback onDismiss;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(context, item.severity);
    final card = Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NotificationProgressIndicator(item: item, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  item.message,
                  maxLines: item.kind == AdminNotificationKind.persistent
                      ? 3
                      : 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (item.reopen != null &&
                    item.kind == AdminNotificationKind.persistent) ...[
                  const SizedBox(height: 6),
                  Text('点击查看详情', style: TextStyle(color: color, fontSize: 11)),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close, size: 18),
            visualDensity: VisualDensity.compact,
            tooltip: '关闭通知',
          ),
          if (item.actionLabel != null && item.onAction != null)
            TextButton(
              onPressed: item.onAction,
              child: Text(item.actionLabel!),
            ),
        ],
      ),
    );
    final interactiveCard = onTap == null
        ? card
        : InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: card,
          );
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutQuart,
      tween: Tween<double>(begin: 0, end: 1),
      child: interactiveCard,
      builder: (context, progress, child) {
        final remaining = 1 - progress;
        return Opacity(
          opacity: progress.clamp(0.0, 1.0),
          child: Transform.translate(
            // The panel is anchored to the lower right, so new cards enter
            // from the right instead of travelling diagonally across it.
            offset: Offset(48 * remaining, 0),
            child: Transform.scale(
              scale: 0.98 + (0.02 * progress),
              alignment: Alignment.centerRight,
              child: child,
            ),
          ),
        );
      },
    );
  }

  Color _severityColor(
    BuildContext context,
    AdminNotificationSeverity severity,
  ) {
    switch (severity) {
      case AdminNotificationSeverity.success:
        return Colors.green.shade700;
      case AdminNotificationSeverity.warning:
        return Colors.orange.shade800;
      case AdminNotificationSeverity.error:
        return Theme.of(context).colorScheme.error;
      case AdminNotificationSeverity.info:
        return Theme.of(context).colorScheme.primary;
    }
  }
}

class _NotificationProgressIndicator extends StatelessWidget {
  const _NotificationProgressIndicator({
    required this.item,
    required this.color,
  });

  final AdminNotification item;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (item.progressMode == AdminNotificationProgressMode.none) {
      return Icon(_iconForSeverity(item.severity), color: color, size: 28);
    }
    return SizedBox(
      width: 30,
      height: 30,
      child: CircularProgressIndicator(
        value: item.progressMode == AdminNotificationProgressMode.determinate
            ? item.progress
            : null,
        strokeWidth: 3,
        color: color,
        backgroundColor: color.withValues(alpha: 0.15),
      ),
    );
  }

  IconData _iconForSeverity(AdminNotificationSeverity severity) {
    switch (severity) {
      case AdminNotificationSeverity.success:
        return Icons.check_circle;
      case AdminNotificationSeverity.warning:
        return Icons.warning_amber;
      case AdminNotificationSeverity.error:
        return Icons.error;
      case AdminNotificationSeverity.info:
        return Icons.info;
    }
  }
}
