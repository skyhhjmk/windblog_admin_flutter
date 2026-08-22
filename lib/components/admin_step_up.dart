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

    final password = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: password,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: '管理员密码'),
          onSubmitted: (_) => Navigator.pop(dialogContext, true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    final rawPassword = password.text;
    password.dispose();
    if (confirmed != true || rawPassword.isEmpty) return null;

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
