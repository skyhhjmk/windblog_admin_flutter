import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windblog_admin_flutter/utils/instance_vault.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_local_authentication');
  bool available = true;
  bool authenticated = true;
  final methods = <String>[];

  setUp(() {
    InstanceVault.lock();
    FlutterSecureStorage.setMockInitialValues({});
    available = true;
    authenticated = true;
    methods.clear();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'canAuthenticate' ||
              call.method == 'authenticate') {
            methods.add((call.arguments as Map)['method'] as String);
          }
          if (call.method == 'canAuthenticate') return available;
          if (call.method == 'authenticate') return authenticated;
          return null;
        });
  });

  tearDown(() {
    InstanceVault.lock();
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> createVault() async {
    await InstanceVault.create('master-password');
    await InstanceVault.save([
      const AdminInstance(
        id: '1',
        name: 'Blog',
        baseUrl: 'https://example.com',
        account: 'admin',
        password: 'secret',
      ),
    ]);
  }

  test(
    'system unlock is opt-in and restores encrypted credentials after lock',
    () async {
      await createVault();
      expect(await InstanceVault.systemUnlockEnabled, isFalse);
      await InstanceVault.enableSystemUnlock();
      InstanceVault.lock();
      expect(await InstanceVault.unlockWithSystemAuthentication(), isTrue);
      expect(InstanceVault.instances.single.password, 'secret');
      expect(methods, everyElement('biometricsOrDeviceCredential'));
    },
  );

  test(
    'failed authentication never unlocks and master password remains usable',
    () async {
      await createVault();
      await InstanceVault.enableSystemUnlock();
      InstanceVault.lock();
      authenticated = false;
      await expectLater(
        InstanceVault.unlockWithSystemAuthentication(),
        throwsException,
      );
      expect(InstanceVault.isUnlocked, isFalse);
      expect(InstanceVault.instances, isEmpty);
      expect(await InstanceVault.unlock('wrong'), isFalse);
      expect(await InstanceVault.unlock('master-password'), isTrue);
    },
  );

  test(
    'unavailable authenticator and disabled system unlock fail closed',
    () async {
      await createVault();
      await InstanceVault.enableSystemUnlock();
      InstanceVault.lock();
      available = false;
      expect(await InstanceVault.unlockWithSystemAuthentication(), isFalse);
      expect(InstanceVault.isUnlocked, isFalse);
      await InstanceVault.disableSystemUnlock();
      available = true;
      expect(await InstanceVault.unlockWithSystemAuthentication(), isFalse);
    },
  );

  test(
    'desktop platforms permit device credentials and new vault removes old key',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await createVault();
      await InstanceVault.enableSystemUnlock();
      expect(methods, everyElement('biometricsOrDeviceCredential'));
      await InstanceVault.create('new-master-password');
      expect(await InstanceVault.systemUnlockEnabled, isFalse);
    },
  );
}
