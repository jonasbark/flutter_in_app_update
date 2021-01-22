import 'dart:async';

import 'package:flutter/services.dart';

enum AppUpdateResult {
  /// The user has accepted the update. For immediate updates, you might not receive this callback because the update should already be completed by Google Play by the time the control is given back to your app.
  success,

  /// The user has denied or cancelled the update.
  userDeniedUpdate,

  /// Some other error prevented either the user from providing consent or the update to proceed.
  inAppUpdateFailed,
}

class InAppUpdate {
  static const MethodChannel _channel = const MethodChannel('in_app_update');

  /// Has to be called before being able to start any update.
  ///
  /// Returns [AppUpdateInfo], which can be used to decide if
  /// [startFlexibleUpdate] or [performImmediateUpdate] should be called.
  static Future<AppUpdateInfo> checkForUpdate() async {
    final result = await _channel.invokeMethod('checkForUpdate');
    return AppUpdateInfo(result['updateAvailable'], result['immediateAllowed'], result['flexibleAllowed'],
        result['availableVersionCode']);
  }

  /// Performs an immediate update that is entirely handled by the Play API.
  ///
  /// [checkForUpdate] has to be called first to be able to run this.
  static Future<AppUpdateResult> performImmediateUpdate() async {
    try {
      await _channel.invokeMethod('performImmediateUpdate');
      return AppUpdateResult.success;
    } on PlatformException catch (e) {
      if (e.code == 'USER_DENIED_UPDATE') {
        return AppUpdateResult.userDeniedUpdate;
      } else if (e.code == 'IN_APP_UPDATE_FAILED') {
        return AppUpdateResult.inAppUpdateFailed;
      }

      throw e;
    }
  }

  /// Starts the download of the app update.
  ///
  /// Throws a [PlatformException] if the download fails.
  /// When the returned [Future] is completed without any errors,
  /// [completeFlexibleUpdate] can be called to install the update.
  ///
  /// [checkForUpdate] has to be called first to be able to run this.
  static Future<AppUpdateResult> startFlexibleUpdate() async {
    try {
      await _channel.invokeMethod('startFlexibleUpdate');
      return AppUpdateResult.success;
    } on PlatformException catch (e) {
      if (e.code == 'USER_DENIED_UPDATE') {
        return AppUpdateResult.userDeniedUpdate;
      } else if (e.code == 'IN_APP_UPDATE_FAILED') {
        return AppUpdateResult.inAppUpdateFailed;
      }

      throw e;
    }
  }

  /// Installs the update downloaded via [startFlexibleUpdate].
  /// [startFlexibleUpdate] has to be completed successfully.
  static Future<void> completeFlexibleUpdate() async {
    return await _channel.invokeMethod('completeFlexibleUpdate');
  }
}

class AppUpdateInfo {
  final bool updateAvailable, immediateUpdateAllowed, flexibleUpdateAllowed;
  final int availableVersionCode;

  AppUpdateInfo(
      this.updateAvailable, this.immediateUpdateAllowed, this.flexibleUpdateAllowed, this.availableVersionCode);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUpdateInfo &&
          runtimeType == other.runtimeType &&
          updateAvailable == other.updateAvailable &&
          immediateUpdateAllowed == other.immediateUpdateAllowed &&
          flexibleUpdateAllowed == other.flexibleUpdateAllowed &&
          availableVersionCode == other.availableVersionCode;

  @override
  int get hashCode =>
      updateAvailable.hashCode ^
      immediateUpdateAllowed.hashCode ^
      flexibleUpdateAllowed.hashCode ^
      availableVersionCode.hashCode;

  @override
  String toString() => 'InAppUpdateState{updateAvailable: $updateAvailable, '
      'immediateUpdateAllowed: $immediateUpdateAllowed, '
      'flexibleUpdateAllowed: $flexibleUpdateAllowed, '
      'availableVersionCode: $availableVersionCode}';
}
