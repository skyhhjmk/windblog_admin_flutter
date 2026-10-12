import 'dart:typed_data';

class PasskeyException implements Exception {
  const PasskeyException(this.message);
  final String message;
  @override
  String toString() => message;
}

class PasskeyMaterial {
  const PasskeyMaterial({
    required this.credentialId,
    required this.salt,
    required this.rpId,
    required this.origin,
    required this.secret,
  });
  final String credentialId;
  final String salt;
  final String rpId;
  final String origin;
  final Uint8List secret;
}

abstract class PasskeyAuthenticator {
  bool get available;
  Future<PasskeyMaterial> register();
  Future<Uint8List> evaluate({
    required String credentialId,
    required String salt,
    required String rpId,
    required String origin,
  });
  void cancel();
}
