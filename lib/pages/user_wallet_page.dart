part of 'package:windblog_admin_flutter/main.dart';

class UserWalletPage extends StatefulWidget {
  const UserWalletPage({
    super.key,
    required this.api,
    required this.userId,
    required this.username,
    required this.onAuthError,
    required this.isSuperAdmin,
  });

  final AdminApiClient api;
  final int userId;
  final String username;
  final VoidCallback onAuthError;
  final bool isSuperAdmin;

  @override
  State<UserWalletPage> createState() => _UserWalletPageState();
}

class _UserWalletPageState extends State<UserWalletPage> {
  WalletInfo? walletInfo;
  WalletTransactionHistory? transactionHistory;
  bool loading = false;
  int page = 1;
  static const int pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadWallet();
    _loadTransactions();
  }

  Future<void> _loadWallet() async {
    setState(() => loading = true);
    try {
      walletInfo = await widget.api.getUserWallet(widget.userId);
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载钱包失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadTransactions() async {
    setState(() => loading = true);
    try {
      transactionHistory = await widget.api.getUserWalletTransactions(
        userId: widget.userId,
        page: page,
        pageSize: pageSize,
      );
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载交易记录失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _adjustPoints() async {
    if (!widget.isSuperAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('只有超级管理员可以调整积分')),
      );
      return;
    }

    final result = await showDialog<_AdjustPointsResult>(
      context: context,
      builder: (context) =>
          _AdjustPointsDialog(
            currentBalance: walletInfo?.pointsBalance ?? 0,
          ),
    );

    if (result == null) return;

    setState(() => loading = true);
    try {
      await widget.api.adjustUserWallet(
        widget.userId,
        newBalance: result.newBalance,
        description: result.description,
      );
      await _loadWallet();
      await _loadTransactions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('调整成功')),
        );
      }
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('调整失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.username}${t(context, 's_wallet')}'),
        actions: [
          if (widget.isSuperAdmin)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _adjustPoints,
              tooltip: t(context, 'adjust_points'),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadWallet();
              _loadTransactions();
            },
            tooltip: t(context, 'refresh'),
          ),
        ],
      ),
      body: loading && walletInfo == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // 钱包余额卡片
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme
                      .of(context)
                      .colorScheme
                      .primary,
                  Theme
                      .of(context)
                      .colorScheme
                      .secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  t(context, 'points_balance'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${walletInfo?.pointsBalance ?? 0}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${t(context, 'version')}：v${walletInfo?.version ?? 0}',
                  style: const TextStyle(
                    color: Color.fromRGBO(255, 255, 255, 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // 交易记录列表
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Text(
                        t(context, 'transaction_history'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '第 ${transactionHistory?.page ??
                            1} 页，共 ${transactionHistory?.total ?? 0} 条',
                        style: TextStyle(
                          color: Theme
                              .of(context)
                              .hintColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: transactionHistory == null ||
                      transactionHistory!.items.isEmpty
                      ? Center(
                    child: Text(
                      transactionHistory == null
                          ? t(context, 'loading')
                          : t(context, 'no_transactions'),
                      style: TextStyle(
                        color: Theme
                            .of(context)
                            .hintColor,
                      ),
                    ),
                  )
                      : ListView.separated(
                    itemCount: transactionHistory!.items.length,
                    separatorBuilder: (context, index) =>
                    const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = transactionHistory!.items[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: item.changeAmount >= 0
                              ? const Color.fromRGBO(76, 175, 80, 0.1)
                              : const Color.fromRGBO(244, 67, 54, 0.1),
                          child: Icon(
                            item.changeAmount >= 0
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: item.changeAmount >= 0
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                        title: Text(item.bizTypeText),
                        subtitle: item.description != null &&
                            item.description!.isNotEmpty
                            ? Text(item.description!)
                            : null,
                        trailing: Column(
                          mainAxisAlignment:
                          MainAxisAlignment.center,
                          crossAxisAlignment:
                          CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${item.changeAmount >= 0 ? '+' : ''}${item
                                  .changeAmount}',
                              style: TextStyle(
                                color: item.changeAmount >= 0
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '${t(context, 'balance')}：${item.balanceAfter}',
                              style: TextStyle(
                                color:
                                Theme
                                    .of(context)
                                    .hintColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                // 分页按钮
                if (transactionHistory != null)
                  PaginationBar(
                    currentPage: page,
                    totalPages: (transactionHistory!.total / pageSize)
                        .ceil()
                        .clamp(1, 999999),
                    totalItems: transactionHistory!.total,
                    onPageChanged: (newPage) {
                      setState(() => page = newPage);
                      _loadTransactions();
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdjustPointsDialog extends StatefulWidget {
  const _AdjustPointsDialog({
    required this.currentBalance,
  });

  final int currentBalance;

  @override
  State<_AdjustPointsDialog> createState() => _AdjustPointsDialogState();
}

class _AdjustPointsDialogState extends State<_AdjustPointsDialog> {
  late final TextEditingController balanceCtrl;
  late final TextEditingController descriptionCtrl;

  @override
  void initState() {
    super.initState();
    balanceCtrl = TextEditingController(text: widget.currentBalance.toString());
    descriptionCtrl = TextEditingController();
  }

  @override
  void dispose() {
    balanceCtrl.dispose();
    descriptionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t(context, 'adjust_points')),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: balanceCtrl,
              decoration: InputDecoration(
                labelText: t(context, 'new_balance'),
                hintText: t(context, 'new_balance_hint'),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionCtrl,
              decoration: InputDecoration(
                labelText: t(context, 'adjust_reason'),
                hintText: t(context, 'adjust_reason_hint'),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t(context, 'cancel')),
        ),
        FilledButton(
          onPressed: () {
            final newBalance = int.tryParse(balanceCtrl.text.trim());
            if (newBalance == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(t(context, 'invalid_number'))),
              );
              return;
            }
            if (newBalance < 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(t(context, 'balance_cannot_be_negative'))),
              );
              return;
            }
            Navigator.pop(
              context,
              _AdjustPointsResult(
                newBalance,
                descriptionCtrl.text.trim(),
              ),
            );
          },
          child: Text(t(context, 'confirm')),
        ),
      ],
    );
  }
}

class _AdjustPointsResult {
  _AdjustPointsResult(this.newBalance, this.description);

  final int newBalance;
  final String description;
}
