import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'passkey_types.dart';

@JS('windblogPasskeyAvailable')
external JSBoolean _available();
@JS('windblogPasskeyRegister')
external JSPromise<JSString> _register();
@JS('windblogPasskeyEvaluate')
external JSPromise<JSString> _evaluate(JSString record);
@JS('windblogPasskeyCancel')
external void _cancel();

PasskeyAuthenticator createPasskeyAuthenticator() => _BrowserPasskey();

class _BrowserPasskey implements PasskeyAuthenticator {
  @override
  bool get available {
    try {
      return _available().toDart;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> _result(JSPromise<JSString> pending) async {
    final result =
        jsonDecode((await pending.toDart).toDart) as Map<String, dynamic>;
    if (result['error'] != null) {
      throw PasskeyException(result['error'] as String);
    }
    return result;
  }

  @override
  Future<PasskeyMaterial> register() async {
    final result = await _result(_register());
    return PasskeyMaterial(
      credentialId: result['credentialId'] as String,
      salt: result['salt'] as String,
      rpId: result['rpId'] as String,
      origin: result['origin'] as String,
      secret: base64Decode(result['secret'] as String),
    );
  }

  @override
  Future<Uint8List> evaluate({
    required String credentialId,
    required String salt,
    required String rpId,
    required String origin,
  }) async {
    final result = await _result(
      _evaluate(
        jsonEncode({
          'credentialId': credentialId,
          'salt': salt,
          'rpId': rpId,
          'origin': origin,
        }).toJS,
      ),
    );
    return base64Decode(result['secret'] as String);
  }

  @override
  void cancel() => _cancel();
}
