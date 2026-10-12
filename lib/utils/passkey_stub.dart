import 'dart:typed_data';
import 'passkey_types.dart';

PasskeyAuthenticator createPasskeyAuthenticator() => _UnsupportedPasskey();

class _UnsupportedPasskey implements PasskeyAuthenticator {
  @override
  bool get available => false;
  @override
  Future<PasskeyMaterial> register() =>
      throw const PasskeyException('请在 HTTPS 或 localhost 的浏览器中使用通行密钥。');
  @override
  Future<Uint8List> evaluate({
    required String credentialId,
    required String salt,
    required String rpId,
    required String origin,
  }) => throw const PasskeyException('当前平台不支持浏览器通行密钥。');
  @override
  void cancel() {}
}
