import 'passkey_stub.dart'
    if (dart.library.js_interop) 'passkey_web.dart'
    as platform;
import 'passkey_types.dart';
export 'passkey_types.dart';

PasskeyAuthenticator createPasskeyAuthenticator() =>
    platform.createPasskeyAuthenticator();
