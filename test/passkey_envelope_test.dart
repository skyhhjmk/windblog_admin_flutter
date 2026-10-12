import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windblog_admin_flutter/utils/passkey_envelope.dart';
import 'package:windblog_admin_flutter/utils/passkey_types.dart';

void main() {
  final vaultKey = SecretKey(List.generate(32, (i) => i));
  final secret = Uint8List.fromList(List.generate(32, (i) => i + 32));
  late Map<String, dynamic> record;
  setUp(() async {
    record = await PasskeyEnvelope.wrap(
      vaultKey,
      PasskeyMaterial(
        credentialId: 'credential',
        salt: base64Encode(List.filled(32, 1)),
        rpId: 'localhost',
        origin: 'http://localhost:8090',
        secret: secret,
      ),
    );
  });

  test(
    'persisted configuration unwraps original vault key using PRF',
    () async {
      final persisted = jsonDecode(jsonEncode(record)) as Map<String, dynamic>;
      final key = await PasskeyEnvelope.unwrap(persisted, secret);
      expect(await key.extractBytes(), await vaultKey.extractBytes());
      expect(record.containsKey('secret'), isFalse);
      expect(
        record['ciphertext'],
        isNot(base64Encode(await vaultKey.extractBytes())),
      );
    },
  );
  test('wrong PRF cannot unwrap the vault', () async {
    await expectLater(
      PasskeyEnvelope.unwrap(record, Uint8List(32)),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });
  for (final field in ['origin', 'rpId', 'credentialId', 'salt']) {
    test('tampered $field cannot unwrap the vault', () async {
      record[field] = 'tampered';
      await expectLater(
        PasskeyEnvelope.unwrap(record, secret),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });
  }
  test('tampered ciphertext fails authentication', () async {
    final bytes = base64Decode(record['ciphertext'] as String);
    bytes[0] ^= 1;
    record['ciphertext'] = base64Encode(bytes);
    await expectLater(
      PasskeyEnvelope.unwrap(record, secret),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });
  test('missing PRF output is rejected', () async {
    await expectLater(
      PasskeyEnvelope.unwrap(record, Uint8List(0)),
      throwsA(isA<PasskeyException>()),
    );
  });
}
