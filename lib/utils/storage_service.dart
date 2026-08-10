import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class StorageService {
  static const String _keyBaseUrl = 'admin_base_url';
  static const String _keyToken = 'admin_auth_token';
  static const String _keyNotificationTasks = 'admin_notification_tasks';

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// 保存会话信息
  static Future<void> saveSession(String baseUrl, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBaseUrl, baseUrl);
    await _secureStorage.write(key: _keyToken, value: token);
  }

  /// 获取保存的会话信息
  static Future<Map<String, String?>> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString(_keyBaseUrl);
    final token = await _secureStorage.read(key: _keyToken);

    return {'baseUrl': baseUrl, 'token': token};
  }

  /// 清除会话（退出登录时调用）
  static Future<void> clearSession() async {
    await _secureStorage.delete(key: _keyToken);
    // baseUrl 通常保留，方便下次登录，但如果需要也可以清除
  }

  static Future<List<Map<String, dynamic>>> getNotificationTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyNotificationTasks);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  static Future<void> saveNotificationTasks(
    List<Map<String, dynamic>> tasks,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNotificationTasks, jsonEncode(tasks));
  }

  static Future<void> clearNotificationTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyNotificationTasks);
  }
}
