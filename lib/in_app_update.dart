import 'dart:async';

import 'package:flutter/services.dart';

/// Status of a download/install.
///
/// For more information, see its corresponding page on
/// [Android Developers](https://developer.android.com/reference/com/google/android/play/core/install/model/InstallStatus.html).
class InstallStatus {
  const InstallStatus._();

  static int get unknown => 0;
  static int get pending => 1;
  static int get downloading => 2;
  static int get installing => 3;
  static int get installed => 4;
  static int get failed => 5;
  static int get canceled => 6;
  static int get downloaded => 11;
}

/// Availability of an update for the requested package.
///
/// For more information, see its corresponding page on
/// [Android Developers](https://developer.android.com/reference/com/google/android/play/core/install/model/UpdateAvailability.html).
class UpdateAvailability {
  const UpdateAvailability._();

  static int get unknown => 0;
  static int get updateNotAvailable => 1;
  static int get updateAvailable => 2;

  /// An update has been triggered by the developer and is in progress.
  static int get developerTriggeredUpdateInProgress => 3;
}

enum AppUpdateResult {
  /// The user has accepted the update. For immediate updates, you might not 
  /// receive this callback because the update should already be completed by 
  /// Google Play by the time the control is given back to your app.
  success,

  /// The user has denied or cancelled the update.
  userDeniedUpdate,

  /// Some other error prevented either the user from providing consent or the 
  /// update to proceed.
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

    return AppUpdateInfo(
      result['updateAvailability'],
      result['immediateAllowed'],
      result['flexibleAllowed'],
      result['availableVersionCode'],
      result['installStatus'],
      result['packageName'],
      result['clientVersionStalenessDays'],
      result['updatePriority'],
    );
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
  ///
  /// [startFlexibleUpdate] has to be completed successfully.
  static Future<void> completeFlexibleUpdate() async {
    return await _channel.invokeMethod('completeFlexibleUpdate');
  }
}

/// Contains information about the availability and progress of an app 
/// update.
///
/// For more information, see its corresponding page on
/// [Android Developers](https://developer.android.com/reference/com/google/android/play/core/appupdate/AppUpdateInfo).
class AppUpdateInfo {
  /// Whether an update is available for the app.
  ///
  /// This is a value from [UpdateAvailability].
  final int updateAvailability;

  /// Whether an immediate update is allowed.
  final bool immediateUpdateAllowed;

  /// Whether a flexible update is allowed.
  final bool flexibleUpdateAllowed;

  /// The version code of the update.
  ///
  /// If no updates are available, this is an arbitrary value.
  final int? availableVersionCode;

  /// The progress status of the update.
  ///
  /// This value is defined only if [updateAvailability] is 
  /// [UpdateAvailability.developerTriggeredUpdateInProgress].
  ///
  /// This is a value from [InstallStatus].
  final int installStatus;
  
  /// The package name for the app to be updated.
  final String packageName;
  
  /// The in-app update priority for this update, as defined by the developer 
  /// in the Google Play Developer API.
  ///
  /// This value is defined only if [updateAvailability] is 
  /// [UpdateAvailability.updateAvailable].
  final int updatePriority;

  /// The number of days since the Google Play Store app on the user's device
  /// has learnt about an available update.
  ///
  /// If update is not available, or if staleness information is unavailable,
  /// this is null.
  final int? clientVersionStalenessDays;

  const AppUpdateInfo(
    this.updateAvailability,
    this.immediateUpdateAllowed,
    this.flexibleUpdateAllowed,
    this.availableVersionCode,
    this.installStatus,
    this.packageName,
    this.clientVersionStalenessDays,
    this.updatePriority,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUpdateInfo &&
          runtimeType == other.runtimeType &&
          updateAvailability == other.updateAvailability &&
          immediateUpdateAllowed == other.immediateUpdateAllowed &&
          flexibleUpdateAllowed == other.flexibleUpdateAllowed &&
          availableVersionCode == other.availableVersionCode &&
          installStatus == other.installStatus &&
          packageName == other.packageName &&
          clientVersionStalenessDays == other.clientVersionStalenessDays &&
          updatePriority == other.updatePriority;

  @override
  int get hashCode =>
      updateAvailability.hashCode ^
      immediateUpdateAllowed.hashCode ^
      flexibleUpdateAllowed.hashCode ^
      availableVersionCode.hashCode ^
      installStatus.hashCode ^
      packageName.hashCode ^
      clientVersionStalenessDays.hashCode ^
      updatePriority.hashCode;

  @override
  String toString() => 'InAppUpdateState{updateAvailability: $updateAvailability, '
      'immediateUpdateAllowed: $immediateUpdateAllowed, '
      'flexibleUpdateAllowed: $flexibleUpdateAllowed, '
      'availableVersionCode: $availableVersionCode, '
      'installStatus: $installStatus, '
      'packageName: $packageName, '
      'clientVersionStalenessDays: $clientVersionStalenessDays, '
      'updatePriority: $updatePriority}';
}
