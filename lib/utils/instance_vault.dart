import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AdminInstance {
  const AdminInstance({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.account,
    required this.password,
  });

  final String id;
  final String name;
  final String baseUrl;
  final String account;
  final String password;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'baseUrl': baseUrl,
    'account': account,
    'password': password,
  };

  factory AdminInstance.fromJson(Map<String, dynamic> json) => AdminInstance(
    id: json['id'] as String,
    name: json['name'] as String,
    baseUrl: json['baseUrl'] as String,
    account: json['account'] as String,
    password: json['password'] as String,
  );
}

/// The encrypted credential vault is persisted by the OS secure storage.
/// Its AES key is derived from the master password and exists only in memory.
class InstanceVault {
  InstanceVault._();

  static const _saltKey = 'admin_instance_vault_salt_v1';
  static const _payloadKey = 'admin_instance_vault_payload_v1';
  static const secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static final _aes = AesGcm.with256bits();
  static final _random = Random.secure();
  static SecretKey? _activeKey;
  static List<AdminInstance> _instances = [];

  static bool get isUnlocked => _activeKey != null;
  static List<AdminInstance> get instances => List.unmodifiable(_instances);

  static Future<bool> get exists async =>
      await secureStorage.read(key: _saltKey) != null;

  static Future<void> create(String masterPassword) async {
    final salt = _randomBytes(16);
    final key = await _deriveKey(masterPassword, salt);
    await secureStorage.write(key: _saltKey, value: base64Encode(salt));
    _activeKey = key;
    _instances = [];
    await save();
  }

  static Future<bool> unlock(String masterPassword) async {
    final encodedSalt = await secureStorage.read(key: _saltKey);
    final payload = await secureStorage.read(key: _payloadKey);
    if (encodedSalt == null || payload == null) return false;
    try {
      final key = await _deriveKey(masterPassword, base64Decode(encodedSalt));
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      final box = SecretBox(
        base64Decode(decoded['ciphertext'] as String),
        nonce: base64Decode(decoded['nonce'] as String),
        mac: Mac(base64Decode(decoded['mac'] as String)),
      );
      final clear = await _aes.decrypt(box, secretKey: key);
      final list = jsonDecode(utf8.decode(clear)) as List<dynamic>;
      _instances = list
          .map(
            (item) =>
                AdminInstance.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
      _activeKey = key;
      return true;
    } catch (_) {
      _activeKey = null;
      _instances = [];
      return false;
    }
  }

  static Future<void> save([List<AdminInstance>? instances]) async {
    if (instances != null) _instances = List.of(instances);
    final key = _activeKey;
    if (key == null) throw StateError('实例库尚未解锁');
    final box = await _aes.encrypt(
      utf8.encode(jsonEncode(_instances.map((item) => item.toJson()).toList())),
      secretKey: key,
    );
    await secureStorage.write(
      key: _payloadKey,
      value: jsonEncode({
        'nonce': base64Encode(box.nonce),
        'ciphertext': base64Encode(box.cipherText),
        'mac': base64Encode(box.mac.bytes),
      }),
    );
  }

  static void lock() {
    _activeKey = null;
    _instances = [];
  }

  static Future<SecretKey> _deriveKey(String password, List<int> salt) =>
      Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: 210000,
        bits: 256,
      ).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);

  static Uint8List _randomBytes(int length) => Uint8List.fromList(
    List<int>.generate(length, (_) => _random.nextInt(256)),
  );
}
