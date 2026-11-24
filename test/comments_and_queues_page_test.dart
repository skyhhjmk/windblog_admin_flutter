import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windblog_admin_flutter/data/admin_api_client.dart';
import 'package:windblog_admin_flutter/data/models.dart';
import 'package:windblog_admin_flutter/main.dart';

class _FakeCommentAndQueueApi extends AdminApiClient {
  String? lastBatchAction;
  List<int>? lastBatchIds;
  bool? lastBatchSendEmailNotification;
  bool abortedCalled = false;

  @override
  Future<CommentListResult> listComments({
    required int page,
    required int pageSize,
    String? status,
    String? auditStatus,
    String? keyword,
    int? postId,
  }) async {
    return CommentListResult(
      items: [
        CommentItem(
          id: 101,
          postId: 1,
          postTitle: '测试文章 A',
          userId: 2,
          userName: 'Alice',
          content: '这是一条正在 AI 审核的评论',
          status: 0,
          auditStatus: abortedCalled ? 4 : 1,
          isReviewing: !abortedCalled,
          aiReviewData: abortedCalled
              ? {'aborted': true, 'reason': '已被管理员强制中断 AI 审核'}
              : null,
          aiAuditState: abortedCalled
              ? AiAuditState(
                  phase: 'ABORTED',
                  label: '已强制中断',
                  detail: '已被管理员强制中断 AI 审核',
                  stuck: false,
                  canAbort: false,
                )
              : AiAuditState(
                  phase: 'OUTBOX_RETRYING',
                  label: '卡在 Outbox 投递重试',
                  detail: '投递 RabbitMQ 失败（第 3/8 次），等待重试：Connection refused',
                  stuck: true,
                  canAbort: true,
                  attemptCount: 3,
                  maxAttempts: 8,
                  elapsedSeconds: 42,
                  lastError: 'Connection refused',
                ),
          createdAt: DateTime.utc(2026, 11, 23, 12, 0),
          clientIp: '223.5.5.5',
          ipLocation: '中国 浙江省 杭州市 (阿里)',
        ),
        CommentItem(
          id: 102,
          postId: 1,
          postTitle: '测试文章 A',
          userId: 3,
          userName: 'Bob',
          content: '普通待审核评论',
          status: 0,
          auditStatus: 0,
          isReviewing: false,
          aiAuditState: AiAuditState(
            phase: 'IDLE',
            label: '未审核',
            detail: '尚未发起 AI 审核',
            stuck: false,
            canAbort: false,
          ),
          createdAt: DateTime.utc(2026, 11, 23, 12, 1),
          clientIp: '1.1.1.1',
          ipLocation: 'Australia Queensland Brisbane',
        ),
      ],
      total: 2,
      page: 1,
      pageSize: 20,
    );
  }

  @override
  Future<CommentItem> abortCommentAudit(int id) async {
    abortedCalled = true;
    return CommentItem(
      id: id,
      postId: 1,
      postTitle: '测试文章 A',
      userId: 2,
      userName: 'Alice',
      content: '这是一条正在 AI 审核的评论',
      status: 0,
      auditStatus: 4,
      isReviewing: false,
      aiReviewData: {'aborted': true, 'reason': '已被管理员强制中断 AI 审核'},
      aiAuditState: AiAuditState(
        phase: 'ABORTED',
        label: '已强制中断',
        detail: '已被管理员强制中断 AI 审核',
        stuck: false,
        canAbort: false,
      ),
      createdAt: DateTime.utc(2026, 11, 23, 12, 0),
      clientIp: '223.5.5.5',
      ipLocation: '中国 浙江省 杭州市 (阿里)',
    );
  }

  @override
  Future<CommentBatchResult> batchComments({
    required List<int> ids,
    required String action,
    bool sendEmailNotification = true,
  }) async {
    lastBatchAction = action;
    lastBatchIds = List<int>.from(ids);
    lastBatchSendEmailNotification = sendEmailNotification;
    return CommentBatchResult(
      requested: ids.length,
      succeeded: ids.length,
      skipped: 0,
      failed: 0,
      failedIds: const [],
      message: '批量操作完成',
    );
  }

  @override
  Future<QueueMonitorOverview> getQueueMonitorOverview() async {
    return QueueMonitorOverview(
      summary: QueueSummary(
        brokerConnected: true,
        brokerHost: '127.0.0.1',
        brokerPort: 5672,
        nodeRole: 'primary',
        outboxEnabled: true,
        outboxPending: 2,
        outboxInFlight: 1,
        outboxFailed: 1,
        outboxPublished24h: 35,
        outboxOldestPendingSeconds: 12,
        activeTaskCount: 1,
        unprocessedDeadLetters: 2,
        reviewingCommentsCount: 3,
        checkedAt: DateTime.utc(2026, 11, 23, 12, 5),
      ),
      queues: [
        QueueInfo(
          name: 'ai-audit-tasks',
          description: 'AI 评论审核任务队列',
          messageCount: 4,
          consumerCount: 1,
          deadLetterQueue: 'ai-audit-dead-letter',
          deadLetterMessageCount: 2,
          isDeadLetter: false,
          exists: true,
          status: 'ACTIVE',
          activeTaskCount: 1,
          outboxEventType: 'AI_AUDIT',
          outboxPendingCount: 2,
          outboxInFlightCount: 1,
          outboxFailedCount: 1,
          unprocessedDeadLetterCount: 2,
        ),
      ],
      activeTasks: [
        ActiveQueueTask(
          runId: 'run-1',
          queueName: 'ai-audit-tasks',
          targetType: 'COMMENT',
          targetId: 88,
          stage: 'CALLING_AI',
          stageLabel: 'AI 模型调用中',
          stageDetail: '正在调用 AI 模型审核评论（超时上限 120s）',
          retryCount: 0,
          maxRetries: 3,
          elapsedSeconds: 15,
          aborting: false,
        ),
      ],
      recentEvents: [
        RecentQueueEvent(
          runId: 'run-0',
          queueName: 'ai-audit-tasks',
          targetType: 'COMMENT',
          targetId: 87,
          status: 'SUCCESS',
          detail: 'AI 审核完成：建议通过',
          retryCount: 0,
          maxRetries: 3,
          durationMs: 1250,
        ),
      ],
      recentOutboxIssues: [
        OutboxIssueItem(
          id: 9,
          eventType: 'AI_AUDIT',
          aggregateType: 'COMMENT',
          aggregateId: '86',
          status: 'FAILED',
          attemptCount: 8,
          lastError: 'RabbitMQ timeout',
        ),
      ],
    );
  }
}

void main() {
  testWidgets(
    'CommentsPage shows real AI audit state, checkboxes, batch bar, and force abort',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = _FakeCommentAndQueueApi();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommentsPage(api: api, onAuthError: () {}),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('卡在 Outbox 投递重试'), findsOneWidget);
      expect(find.textContaining('Connection refused'), findsOneWidget);
      expect(
        find.textContaining('IP: 223.5.5.5 · 中国 浙江省 杭州市 (阿里)'),
        findsOneWidget,
      );
      expect(
        find.textContaining('IP: 1.1.1.1 · Australia Queensland Brisbane'),
        findsOneWidget,
      );

      // 打开评论详情弹窗并验证 IP 与地理位置展示
      await tester.tap(find.text('Bob'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('1.1.1.1'), findsOneWidget);
      expect(find.text('Australia Queensland Brisbane'), findsOneWidget);
      await tester.tap(find.text('close'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsNWidgets(3));
      await tester.tap(checkboxes.first);
      await tester.pump();

      expect(find.text('已选 2 条'), findsOneWidget);
      expect(find.text('批量通过'), findsOneWidget);
      expect(find.text('批量中断 (1)'), findsOneWidget);

      await tester.tap(find.text('批量通过'));
      await tester.pump();
      expect(find.text('向被回复用户发送邮件通知'), findsOneWidget);
      final notifyCheckbox = tester.widget<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      expect(notifyCheckbox.value, isTrue);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.byType(FilledButton).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(api.lastBatchAction, 'APPROVE');
      expect(api.lastBatchIds, [101, 102]);
      expect(api.lastBatchSendEmailNotification, isFalse);

      await tester.tap(find.text('中断'));
      await tester.pump();
      await tester.tap(find.text('强制中断'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(api.abortedCalled, isTrue);
      expect(find.textContaining('已强制中断'), findsOneWidget);
    },
  );

  testWidgets(
    'QueuesPage renders broker status, active tasks, queues, and outbox issues',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = _FakeCommentAndQueueApi();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QueuesPage(api: api, onAuthError: () {}),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('RabbitMQ 已连接'), findsOneWidget);
      expect(find.textContaining('正在执行的实时任务 (1)'), findsOneWidget);
      expect(find.textContaining('AI 模型调用中'), findsOneWidget);
      expect(find.textContaining('ai-audit-tasks'), findsWidgets);
      expect(find.textContaining('RabbitMQ timeout'), findsOneWidget);
      expect(find.textContaining('AI 审核完成：建议通过'), findsOneWidget);
    },
  );
}
