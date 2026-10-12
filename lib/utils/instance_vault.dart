import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_authentication/flutter_local_authentication.dart';
import 'package:flutter_local_authentication/localization_model.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'linux_system_authentication.dart';
import 'passkey_authentication.dart';
import 'passkey_envelope.dart';

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
/// Its AES key is derived from the master password. System unlock is opt-in.
class InstanceVault {
  InstanceVault._();

  static const _passkeyKey = 'admin_instance_vault_passkey_v1';
  static final _passkey = createPasskeyAuthenticator();
  static bool get passkeyAvailable => _passkey.available;
  static Future<bool> get passkeyEnabled async =>
      await secureStorage.read(key: _passkeyKey) != null;

  static Future<void> enablePasskeyUnlock() async {
    final key = _activeKey;
    if (key == null) throw StateError('请先用主密码解锁实例库。');
    final material = await _passkey.register();
    if (_activeKey != key) throw StateError('实例库已锁定，请重新解锁。');
    final record = await PasskeyEnvelope.wrap(key, material);
    if (_activeKey != key) throw StateError('实例库已锁定，请重新解锁。');
    await secureStorage.write(key: _passkeyKey, value: jsonEncode(record));
  }

  static Future<void> disablePasskeyUnlock() =>
      secureStorage.delete(key: _passkeyKey);

  static Future<bool> unlockWithPasskey() async {
    final generation = _lockGeneration;
    final raw = await secureStorage.read(key: _passkeyKey);
    if (raw == null) return false;
    final record = jsonDecode(raw) as Map<String, dynamic>;
    final secret = await _passkey.evaluate(
      credentialId: record['credentialId'] as String,
      salt: record['salt'] as String,
      rpId: record['rpId'] as String,
      origin: record['origin'] as String,
    );
    final key = await PasskeyEnvelope.unwrap(record, secret);
    final payload = await secureStorage.read(key: _payloadKey);
    return generation == _lockGeneration &&
        payload != null &&
        await _unlockPayload(key, payload);
  }

  static const _systemEnabledKey = 'admin_instance_vault_system_enabled_v1';
  static const _systemKey = 'admin_instance_vault_system_key_v1';
  static final _linuxAuthentication = LinuxSystemAuthentication();
  static final _authentication = FlutterLocalAuthentication();
  static AuthenticationMethod get _method =>
      defaultTargetPlatform == TargetPlatform.linux
      ? AuthenticationMethod.biometricsOnly
      : AuthenticationMethod.biometricsOrDeviceCredential;

  static Future<bool> systemAuthenticationAvailable() async {
    if (kIsWeb) return false;
    try {
      if (defaultTargetPlatform == TargetPlatform.linux) {
        return await _linuxAuthentication.isAvailable();
      }
      return await _authentication.canAuthenticate(method: _method);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> get systemUnlockEnabled async =>
      !kIsWeb && await secureStorage.read(key: _systemEnabledKey) == 'true';

  static Future<bool> _authenticate() async {
    if (defaultTargetPlatform == TargetPlatform.linux) {
      return _linuxAuthentication.authenticate();
    }
    if (!await systemAuthenticationAvailable()) return false;
    await _authentication.setLocalizationModel(
      LocalizationModel(
        promptDialogTitle: '解锁 WindBlog 实例库',
        promptDialogReason: '验证身份以使用保存的实例凭据',
        cancelButtonTitle: '取消',
      ),
    );
    return _authentication.authenticate(method: _method);
  }

  static Future<void> cancelSystemAuthentication() async {
    if (kIsWeb) {
      _passkey.cancel();
      return;
    }
    if (defaultTargetPlatform == TargetPlatform.linux) {
      _linuxAuthentication.cancel();
    } else {
      await _authentication.cancelAuthentication();
    }
  }

  static Future<void> enableSystemUnlock() async {
    final key = _activeKey;
    if (key == null) throw StateError('请先使用主密码解锁实例库');
    if (!await _authenticate()) throw StateError('系统认证未完成');
    if (_activeKey != key) throw StateError('实例库已锁定，请重新解锁');
    await secureStorage.write(
      key: _systemKey,
      value: base64Encode(await key.extractBytes()),
    );
    await secureStorage.write(key: _systemEnabledKey, value: 'true');
  }

  static Future<void> disableSystemUnlock() async {
    await secureStorage.delete(key: _systemEnabledKey);
    await secureStorage.delete(key: _systemKey);
  }

  static Future<bool> unlockWithSystemAuthentication() async {
    if (!await systemUnlockEnabled || !await _authenticate()) return false;
    final encodedKey = await secureStorage.read(key: _systemKey);
    final payload = await secureStorage.read(key: _payloadKey);
    if (encodedKey == null || payload == null) return false;
    return _unlockPayload(SecretKey(base64Decode(encodedKey)), payload);
  }

  static const _saltKey = 'admin_instance_vault_salt_v1';
  static const _payloadKey = 'admin_instance_vault_payload_v1';
  static const secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static final _aes = AesGcm.with256bits();
  static final _random = Random.secure();
  static int _lockGeneration = 0;
  static SecretKey? _activeKey;
  static List<AdminInstance> _instances = [];

  static bool get isUnlocked => _activeKey != null;
  static List<AdminInstance> get instances => List.unmodifiable(_instances);

  static Future<bool> get exists async =>
      await secureStorage.read(key: _saltKey) != null;

  static Future<void> create(String masterPassword) async {
    await disableSystemUnlock();
    await disablePasskeyUnlock();
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
      return await _unlockPayload(key, payload);
    } catch (_) {
      lock();
      return false;
    }
  }

  static Future<bool> _unlockPayload(SecretKey key, String payload) async {
    final generation = _lockGeneration;
    try {
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      final box = SecretBox(
        base64Decode(decoded['ciphertext'] as String),
        nonce: base64Decode(decoded['nonce'] as String),
        mac: Mac(base64Decode(decoded['mac'] as String)),
      );
      final clear = await _aes.decrypt(box, secretKey: key);
      if (generation != _lockGeneration) return false;
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
    _lockGeneration++;
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
