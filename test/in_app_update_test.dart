import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_update_plus/in_app_update_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('de.ffuf.in_app_update_plus/methods');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('checkForUpdate parses Android and iOS update metadata', () async {
    MethodCall? capturedCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      capturedCall = call;
      return <String, dynamic>{
        'updateAvailability': 2,
        'immediateAllowed': true,
        'immediateAllowedPreconditions': <int>[],
        'flexibleAllowed': false,
        'flexibleAllowedPreconditions': <int>[1, 2],
        'availableVersionCode': 42,
        'installStatus': 0,
        'packageName': 'com.example.app',
        'clientVersionStalenessDays': null,
        'updatePriority': 3,
        'availableVersionName': '2.0.0',
        'installedVersionName': '1.0.0',
        'storeUrl': 'https://apps.apple.com/app/id123',
        'appStoreId': 123,
        'releaseNotes': 'Bug fixes',
      };
    });

    final info = await InAppUpdate.checkForUpdate(
      countryCode: 'US',
      appStoreId: '123',
    );

    expect(capturedCall?.method, 'checkForUpdate');
    expect(capturedCall?.arguments, <String, dynamic>{
      'countryCode': 'US',
      'appStoreId': '123',
    });
    expect(info.updateAvailability, UpdateAvailability.updateAvailable);
    expect(info.installStatus, InstallStatus.unknown);
    expect(info.flexibleAllowedPreconditions, <int>[1, 2]);
    expect(info.availableVersionName, '2.0.0');
    expect(info.installedVersionName, '1.0.0');
    expect(info.storeUrl, 'https://apps.apple.com/app/id123');
    expect(info.appStoreId, 123);
    expect(info.releaseNotes, 'Bug fixes');
  });

  test('checkForUpdate falls back for unknown enum values', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      return <String, dynamic>{
        'updateAvailability': 999,
        'immediateAllowed': false,
        'immediateAllowedPreconditions': null,
        'flexibleAllowed': false,
        'flexibleAllowedPreconditions': null,
        'availableVersionCode': null,
        'installStatus': 999,
        'packageName': 'com.example.app',
        'clientVersionStalenessDays': null,
        'updatePriority': null,
      };
    });

    final info = await InAppUpdate.checkForUpdate();

    expect(info.updateAvailability, UpdateAvailability.unknown);
    expect(info.installStatus, InstallStatus.unknown);
    expect(info.updatePriority, 0);
  });

  testWidgets('checkAndShowUpdateDialog returns noUpdateAvailable',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      return <String, dynamic>{
        'updateAvailability': 1,
        'immediateAllowed': false,
        'immediateAllowedPreconditions': <int>[],
        'flexibleAllowed': false,
        'flexibleAllowedPreconditions': <int>[],
        'availableVersionCode': null,
        'installStatus': 0,
        'packageName': 'com.example.app',
        'clientVersionStalenessDays': null,
        'updatePriority': 0,
      };
    });

    late BuildContext capturedContext;
    await tester.pumpWidget(
      CupertinoApp(
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox();
          },
        ),
      ),
    );

    final result = await InAppUpdate.checkAndShowUpdateDialog(capturedContext);

    expect(result, AppUpdateDialogResult.noUpdateAvailable);
  });

  test('AppUpdateInfo compares list contents', () {
    final first = AppUpdateInfo(
      updateAvailability: UpdateAvailability.updateAvailable,
      immediateUpdateAllowed: true,
      immediateAllowedPreconditions: <int>[1],
      flexibleUpdateAllowed: false,
      flexibleAllowedPreconditions: <int>[2],
      availableVersionCode: 10,
      installStatus: InstallStatus.pending,
      packageName: 'com.example.app',
      clientVersionStalenessDays: 1,
      updatePriority: 5,
      availableVersionName: '2.0.0',
      installedVersionName: '1.0.0',
      storeUrl: 'https://apps.apple.com/app/id123',
      appStoreId: 123,
      releaseNotes: 'Bug fixes',
    );
    final second = AppUpdateInfo(
      updateAvailability: UpdateAvailability.updateAvailable,
      immediateUpdateAllowed: true,
      immediateAllowedPreconditions: <int>[1],
      flexibleUpdateAllowed: false,
      flexibleAllowedPreconditions: <int>[2],
      availableVersionCode: 10,
      installStatus: InstallStatus.pending,
      packageName: 'com.example.app',
      clientVersionStalenessDays: 1,
      updatePriority: 5,
      availableVersionName: '2.0.0',
      installedVersionName: '1.0.0',
      storeUrl: 'https://apps.apple.com/app/id123',
      appStoreId: 123,
      releaseNotes: 'Bug fixes',
    );

    expect(first, second);
    expect(first.hashCode, second.hashCode);
  });
}
