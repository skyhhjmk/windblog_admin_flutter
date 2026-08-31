part of 'package:windblog_admin_flutter/main.dart';

/// Shares a short-lived step-up credential across protected admin actions.
/// It is tied to the current bearer token and intentionally remains in memory
/// only; logging out or changing accounts invalidates the cached credential.
class AdminStepUpAuthorization {
  static String? _bearerToken;
  static String? _stepUpToken;
  static DateTime? _expiresAt;

  static void clear() {
    _bearerToken = null;
    _stepUpToken = null;
    _expiresAt = null;
  }

  static Future<String?> obtain(
    BuildContext context,
    AdminApiClient api, {
    required String title,
  }) async {
    final bearerToken = api.token;
    if (bearerToken == null || bearerToken.isEmpty) return null;
    final expiresAt = _expiresAt;
    if (_bearerToken == bearerToken &&
        _stepUpToken != null &&
        expiresAt != null &&
        DateTime.now().isBefore(expiresAt)) {
      return _stepUpToken;
    }

    final rawPassword = await showDialog<String>(
      context: context,
      builder: (_) => _AdminStepUpDialog(title: title),
    );
    if (rawPassword == null || rawPassword.isEmpty) return null;

    try {
      final token = await api.issueAdminStepUp(rawPassword);
      _bearerToken = bearerToken;
      _stepUpToken = token;
      // The backend accepts it for five minutes; leave room for request delay.
      _expiresAt = DateTime.now().add(const Duration(minutes: 4, seconds: 30));
      return token;
    } catch (error) {
      if (error is UnauthorizedException) {
        clear();
      }
      if (context.mounted) {
        AdminFeedback.showSnackBar(
          context,
          SnackBar(
            content: Text('高风险操作授权失败：$error'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }
}

/// Owns the password controller for exactly as long as the dialog's route is
/// mounted. `showDialog` completes when the route starts popping, which is too
/// early to dispose a controller captured by the still-running exit animation.
class _AdminStepUpDialog extends StatefulWidget {
  const _AdminStepUpDialog({required this.title});

  final String title;

  @override
  State<_AdminStepUpDialog> createState() => _AdminStepUpDialogState();
}

class _AdminStepUpDialogState extends State<_AdminStepUpDialog> {
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _submit(BuildContext dialogContext) {
    Navigator.pop(dialogContext, _password.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _password,
        obscureText: true,
        autofocus: true,
        decoration: const InputDecoration(labelText: '管理员密码'),
        onSubmitted: (_) => _submit(context),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => _submit(context),
          child: AdminShortcutText(
            '确认',
            AdminShortcutDefinitions.keyByAction['submit']!,
          ),
        ),
      ],
    );
  }
}
