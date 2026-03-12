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
        title: Text('${widget.username} 的钱包'),
        actions: [
          if (widget.isSuperAdmin)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _adjustPoints,
              tooltip: '调整积分',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadWallet();
              _loadTransactions();
            },
            tooltip: '刷新',
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
                const Text(
                  '积分余额',
                  style: TextStyle(
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
                  '版本号：v${walletInfo?.version ?? 0}',
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
                      const Text(
                        '交易记录',
                        style: TextStyle(
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
                          ? '加载中...'
                          : '暂无交易记录',
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
                              '余额：${item.balanceAfter}',
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
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: page <= 1
                              ? null
                              : () {
                            setState(() => page--);
                            _loadTransactions();
                          },
                          icon: const Icon(Icons.chevron_left),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed:
                          page * pageSize >= transactionHistory!.total
                              ? null
                              : () {
                            setState(() => page++);
                            _loadTransactions();
                          },
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
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
      title: const Text('调整积分'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: balanceCtrl,
              decoration: const InputDecoration(
                labelText: '新余额',
                hintText: '请输入新的积分余额',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionCtrl,
              decoration: const InputDecoration(
                labelText: '调整说明',
                hintText: '请输入调整原因或说明',
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final newBalance = int.tryParse(balanceCtrl.text.trim());
            if (newBalance == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请输入有效的数字')),
              );
              return;
            }
            if (newBalance < 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('余额不能为负数')),
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
          child: const Text('确定'),
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
