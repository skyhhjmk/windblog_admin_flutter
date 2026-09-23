part of 'package:windblog_admin_flutter/main.dart';

class UserWalletPage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$username${t(context, 's_wallet')}')),
      body: UserWalletPanel(
        api: api,
        userId: userId,
        onAuthError: onAuthError,
        isSuperAdmin: isSuperAdmin,
      ),
    );
  }
}

class UserWalletPanel extends StatefulWidget {
  const UserWalletPanel({
    super.key,
    required this.api,
    required this.userId,
    required this.onAuthError,
    required this.isSuperAdmin,
  });

  final AdminApiClient api;
  final int userId;
  final VoidCallback onAuthError;
  final bool isSuperAdmin;

  @override
  State<UserWalletPanel> createState() => _UserWalletPanelState();
}

class _UserWalletPanelState extends State<UserWalletPanel> {
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
    if (mounted) setState(() => loading = true);
    try {
      walletInfo = await widget.api.getUserWallet(widget.userId);
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      _showMessage('加载钱包失败：$error', error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadTransactions() async {
    if (mounted) setState(() => loading = true);
    try {
      transactionHistory = await widget.api.getUserWalletTransactions(
        userId: widget.userId,
        page: page,
        pageSize: pageSize,
      );
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      _showMessage('加载交易记录失败：$error', error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _refresh() async {
    await Future.wait([_loadWallet(), _loadTransactions()]);
  }

  Future<void> _adjustPoints() async {
    if (!widget.isSuperAdmin) {
      _showMessage('只有超级管理员可以调整积分', error: true);
      return;
    }

    final result = await showDialog<_AdjustPointsResult>(
      context: context,
      builder: (context) =>
          _AdjustPointsDialog(currentBalance: walletInfo?.pointsBalance ?? 0),
    );
    if (result == null || !mounted) return;

    final stepUpToken = await AdminStepUpAuthorization.obtain(
      context,
      widget.api,
      title: '确认调整用户钱包余额',
    );
    if (stepUpToken == null || !mounted) return;

    setState(() => loading = true);
    try {
      await widget.api.adjustUserWallet(
        widget.userId,
        newBalance: result.newBalance,
        description: result.description,
        stepUpToken: stepUpToken,
      );
      await _refresh();
      _showMessage('调整成功');
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (error) {
      _showMessage('调整失败：$error', error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    AdminFeedback.showSnackBar(
      context,
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final history = transactionHistory;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Row(
            children: [
              Text('积分钱包', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              if (widget.isSuperAdmin)
                FilledButton.tonalIcon(
                  onPressed: loading ? null : _adjustPoints,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('调整余额'),
                ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: loading ? null : _refresh,
                icon: const Icon(Icons.refresh),
                tooltip: t(context, 'refresh'),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.secondary,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('当前余额', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 3),
                  Text(
                    '${walletInfo?.pointsBalance ?? 0}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                'v${walletInfo?.version ?? 0}',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Text('交易记录', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            Text(
              '第 ${history?.page ?? 1} 页，共 ${history?.total ?? 0} 条',
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: history == null || history.items.isEmpty
              ? Center(
                  child: Text(
                    history == null
                        ? t(context, 'loading')
                        : t(context, 'no_transactions'),
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                )
              : ListView.separated(
                  itemCount: history.items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = history.items[index];
                    final positive = item.changeAmount >= 0;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: positive
                            ? Colors.green.withAlpha(25)
                            : Colors.red.withAlpha(25),
                        child: Icon(
                          positive ? Icons.arrow_downward : Icons.arrow_upward,
                          color: positive ? Colors.green : Colors.red,
                        ),
                      ),
                      title: Text(item.bizTypeText),
                      subtitle: item.description?.isNotEmpty == true
                          ? Text(item.description!)
                          : null,
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${positive ? '+' : ''}${item.changeAmount}',
                            style: TextStyle(
                              color: positive ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '余额：${item.balanceAfter}',
                            style: TextStyle(
                              color: Theme.of(context).hintColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        if (history != null)
          PaginationBar(
            currentPage: page,
            totalPages: (history.total / pageSize).ceil().clamp(1, 999999),
            totalItems: history.total,
            onPageChanged: (newPage) {
              setState(() => page = newPage);
              _loadTransactions();
            },
          ),
      ],
    );
  }
}

class _AdjustPointsDialog extends StatefulWidget {
  const _AdjustPointsDialog({required this.currentBalance});

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
      title: const Text('调整钱包余额'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: balanceCtrl,
              decoration: const InputDecoration(labelText: '新余额'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionCtrl,
              decoration: const InputDecoration(labelText: '调整原因'),
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
            final value = int.tryParse(balanceCtrl.text.trim());
            if (value == null || value < 0) {
              AdminFeedback.showSnackBar(
                context,
                const SnackBar(content: Text('余额必须是非负整数')),
              );
              return;
            }
            Navigator.pop(
              context,
              _AdjustPointsResult(value, descriptionCtrl.text.trim()),
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
