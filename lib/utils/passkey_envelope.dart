import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'passkey_types.dart';

/// Stores only an authenticated encrypted vault key, never the PRF output.
class PasskeyEnvelope {
  static final _aes = AesGcm.with256bits();

  static List<int> _binding(Map<String, dynamic> record) => utf8.encode(
    jsonEncode([
      'windblog-passkey-v1',
      record['credentialId'],
      record['salt'],
      record['rpId'],
      record['origin'],
    ]),
  );

  static Future<SecretKey> _wrappingKey(List<int> secret) async {
    if (secret.length != 32) {
      throw const PasskeyException('通行密钥未返回有效的 PRF 解密密钥。');
    }
    return Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
      secretKey: SecretKey(secret),
      info: utf8.encode('WindBlog instance vault passkey wrapping v1'),
      nonce: const [],
    );
  }

  static Future<Map<String, dynamic>> wrap(
    SecretKey key,
    PasskeyMaterial material,
  ) async {
    final record = <String, dynamic>{
      'version': 1,
      'credentialId': material.credentialId,
      'salt': material.salt,
      'rpId': material.rpId,
      'origin': material.origin,
    };
    final box = await _aes.encrypt(
      await key.extractBytes(),
      secretKey: await _wrappingKey(material.secret),
      aad: _binding(record),
    );
    record.addAll({
      'nonce': base64Encode(box.nonce),
      'ciphertext': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    });
    return record;
  }

  static Future<SecretKey> unwrap(
    Map<String, dynamic> record,
    Uint8List secret,
  ) async {
    if (record['version'] != 1) {
      throw const PasskeyException('通行密钥配置版本不支持，请使用主密码。');
    }
    final clear = await _aes.decrypt(
      SecretBox(
        base64Decode(record['ciphertext'] as String),
        nonce: base64Decode(record['nonce'] as String),
        mac: Mac(base64Decode(record['mac'] as String)),
      ),
      secretKey: await _wrappingKey(secret),
      aad: _binding(record),
    );
    if (clear.length != 32) throw const PasskeyException('通行密钥解锁配置已损坏，请使用主密码。');
    return SecretKey(clear);
  }
}
