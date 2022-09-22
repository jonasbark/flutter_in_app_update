import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_in_app_update/in_app_update.dart';

/// Return value of checkForUpdate method channel with mock results.
final checkUpdateChannelResult = {
  'updateAvailability': 1,
  'immediateAllowed': true,
  'flexibleAllowed': false,
  'availableVersionCode': 2,
  'installStatus': 3,
  'packageName': 'foo',
  'clientVersionStalenessDays': 4,
  'updatePriority': 5,
};

/// Mock return value of [InAppUpdate.checkForUpdate].
///
/// Assumes that method channel returns [checkUpdateChannelResult].
final AppUpdateInfo checkUpdateResult =
    AppUpdateInfo(1, true, false, 2, 3, 'foo', 4, 5);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('in_app_update');
  final log = <MethodCall>[];

  channel.setMockMethodCallHandler((MethodCall methodCall) async {
    log.add(methodCall);
    switch (methodCall.method) {
      case 'checkForUpdate':
        return checkUpdateChannelResult;
      case 'performImmediateUpdate':
        return null;
      case 'startFlexibleUpdate':
        return null;
      default:
        assert(false);
        return null;
    }
  });

  tearDown(() {
    log.clear();
  });

  group('InAppUpdate.checkForUpdate', () {
    test('invokes appropriate method channel.', () async {
      await InAppUpdate.checkForUpdate();
      expect(log, <Matcher>[isMethodCall('checkForUpdate', arguments: null)]);
    });

    test('returns correct result.', () async {
      final result = await InAppUpdate.checkForUpdate();
      expect(result, checkUpdateResult);
    });
  });

  group('InAppUpdate.performImmediateUpdate', () {
    test('invokes appropriate method channel.', () async {
      await InAppUpdate.performImmediateUpdate();
      expect(log,
          <Matcher>[isMethodCall('performImmediateUpdate', arguments: null)]);
    });

    test('reports success.', () async {
      final result = await InAppUpdate.performImmediateUpdate();
      expect(result, AppUpdateResult.success);
    });
  });

  group('InAppUpdate.startFlexibleUpdate', () {
    test('invokes appropriate method channel.', () async {
      await InAppUpdate.startFlexibleUpdate();
      expect(
          log, <Matcher>[isMethodCall('startFlexibleUpdate', arguments: null)]);
    });

    test('reports success.', () async {
      final result = await InAppUpdate.startFlexibleUpdate();
      expect(result, AppUpdateResult.success);
    });
  });
}
