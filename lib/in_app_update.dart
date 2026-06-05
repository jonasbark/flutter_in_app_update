import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Status of a download/install.
///
/// For more information, see its corresponding page on
/// [Android Developers](https://developer.android.com/reference/com/google/android/play/core/install/model/InstallStatus.html).
enum InstallStatus {
  unknown(0),
  pending(1),
  downloading(2),
  installing(3),
  installed(4),
  failed(5),
  canceled(6),
  downloaded(11);

  const InstallStatus(this.value);
  final int value;
}

/// Availability of an update for the requested package.
///
/// For more information, see its corresponding page on
/// [Android Developers](https://developer.android.com/reference/com/google/android/play/core/install/model/UpdateAvailability.html).
enum UpdateAvailability {
  unknown(0),
  updateNotAvailable(1),
  updateAvailable(2),
  developerTriggeredUpdateInProgress(3);

  const UpdateAvailability(this.value);
  final int value;
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

enum AppUpdateDialogResult {
  /// No update is currently available.
  noUpdateAvailable,

  /// An update is available but neither immediate nor flexible update is
  /// allowed on this device.
  updateNotAllowed,

  /// The user dismissed the package-provided iOS update dialog.
  userDismissed,

  /// The update flow was started.
  updateStarted,

  /// The update flow could not be started.
  updateFailed,
}

class InAppUpdate {
  static const MethodChannel _channel =
      MethodChannel('de.ffuf.in_app_update_plus/methods');
  static const EventChannel _installListener =
      EventChannel('de.ffuf.in_app_update_plus/stateEvents');

  /// Has to be called before being able to start any update.
  ///
  /// Returns [AppUpdateInfo], which can be used to decide if
  /// [startFlexibleUpdate] or [performImmediateUpdate] should be called.
  ///
  /// On iOS, [countryCode] can be used to choose the App Store country for the
  /// lookup. [appStoreId] can be supplied when the App Store listing should be
  /// resolved by Apple ID instead of the app bundle identifier.
  static Future<AppUpdateInfo> checkForUpdate({
    String? countryCode,
    String? appStoreId,
  }) async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'checkForUpdate',
      <String, dynamic>{
        if (countryCode != null) 'countryCode': countryCode,
        if (appStoreId != null) 'appStoreId': appStoreId,
      },
    );

    if (result == null) {
      throw PlatformException(
        code: 'NULL_UPDATE_INFO',
        message: 'The platform returned no update information.',
      );
    }

    return AppUpdateInfo(
      updateAvailability:
          _updateAvailabilityFromValue(result['updateAvailability']),
      immediateUpdateAllowed: result['immediateAllowed'] == true,
      immediateAllowedPreconditions:
          _intListFromValue(result['immediateAllowedPreconditions']),
      flexibleUpdateAllowed: result['flexibleAllowed'] == true,
      flexibleAllowedPreconditions:
          _intListFromValue(result['flexibleAllowedPreconditions']),
      availableVersionCode: _intFromValue(result['availableVersionCode']),
      installStatus: _installStatusFromValue(result['installStatus']),
      packageName: _stringFromValue(result['packageName']) ?? '',
      clientVersionStalenessDays:
          _intFromValue(result['clientVersionStalenessDays']),
      updatePriority: _intFromValue(result['updatePriority']) ?? 0,
      availableVersionName: _stringFromValue(result['availableVersionName']),
      installedVersionName: _stringFromValue(result['installedVersionName']),
      storeUrl: _stringFromValue(result['storeUrl']),
      appStoreId: _intFromValue(result['appStoreId']),
      releaseNotes: _stringFromValue(result['releaseNotes']),
    );
  }

  /// Checks for an update and starts the platform update flow when possible.
  ///
  /// On Android this starts Google Play's native immediate update UI when
  /// allowed. If [preferFlexibleUpdate] is true and flexible updates are
  /// allowed, the flexible update flow is started instead.
  ///
  /// On iOS this shows a package-provided Cupertino update dialog. If the user
  /// taps the update action, the App Store page is opened.
  ///
  /// Set [forceUpdate] to true on iOS to hide the cancel action and prevent
  /// barrier dismissal. The app still cannot install an iOS update directly;
  /// Apple requires installation to happen through the App Store.
  static Future<AppUpdateDialogResult> checkAndShowUpdateDialog(
    BuildContext context, {
    String? countryCode,
    String? appStoreId,
    bool forceUpdate = false,
    bool preferFlexibleUpdate = false,
    String? title,
    String? message,
    String? updateButtonText,
    String? laterButtonText,
  }) async {
    final info = await checkForUpdate(
      countryCode: countryCode,
      appStoreId: appStoreId,
    );

    if (info.updateAvailability != UpdateAvailability.updateAvailable) {
      return AppUpdateDialogResult.noUpdateAvailable;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final shouldUpdate = await _showCupertinoUpdateDialog(
        context,
        info: info,
        forceUpdate: forceUpdate,
        title: title,
        message: message,
        updateButtonText: updateButtonText,
        laterButtonText: laterButtonText,
      );

      if (shouldUpdate != true) {
        return AppUpdateDialogResult.userDismissed;
      }

      final result = await performImmediateUpdate();
      return result == AppUpdateResult.success
          ? AppUpdateDialogResult.updateStarted
          : AppUpdateDialogResult.updateFailed;
    }

    final result = await _startBestAndroidUpdateFlow(
      info,
      preferFlexibleUpdate: preferFlexibleUpdate,
    );
    if (result == null) {
      return AppUpdateDialogResult.updateNotAllowed;
    }
    if (result == AppUpdateResult.userDeniedUpdate) {
      return AppUpdateDialogResult.userDismissed;
    }
    return result == AppUpdateResult.success
        ? AppUpdateDialogResult.updateStarted
        : AppUpdateDialogResult.updateFailed;
  }

  static Stream<InstallStatus> get installUpdateListener {
    return _installListener
        .receiveBroadcastStream()
        .cast<int>()
        .map((int value) {
      switch (value) {
        case 0:
          return InstallStatus.unknown;
        case 1:
          return InstallStatus.pending;
        case 2:
          return InstallStatus.downloading;
        case 3:
          return InstallStatus.installing;
        case 4:
          return InstallStatus.installed;
        case 5:
          return InstallStatus.failed;
        case 6:
          return InstallStatus.canceled;
        case 11:
          return InstallStatus.downloaded;
        default:
          return InstallStatus.unknown;
      }
    });
  }

  /// Performs an immediate update that is entirely handled by the Play API.
  /// On iOS, this opens the app's App Store page.
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
  /// Android supports flexible background downloads. iOS does not; on iOS this
  /// opens the app's App Store page, matching [performImmediateUpdate].
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
  /// On iOS, this completes immediately because installation is handled by the
  /// App Store.
  ///
  /// [startFlexibleUpdate] has to be completed successfully.
  static Future<void> completeFlexibleUpdate() async {
    return await _channel.invokeMethod('completeFlexibleUpdate');
  }

  static Future<AppUpdateResult?> _startBestAndroidUpdateFlow(
    AppUpdateInfo info, {
    required bool preferFlexibleUpdate,
  }) {
    if (preferFlexibleUpdate && info.flexibleUpdateAllowed) {
      return startFlexibleUpdate();
    }
    if (info.immediateUpdateAllowed) {
      return performImmediateUpdate();
    }
    if (info.flexibleUpdateAllowed) {
      return startFlexibleUpdate();
    }
    return Future<AppUpdateResult?>.value();
  }

  static Future<bool?> _showCupertinoUpdateDialog(
    BuildContext context, {
    required AppUpdateInfo info,
    required bool forceUpdate,
    String? title,
    String? message,
    String? updateButtonText,
    String? laterButtonText,
  }) {
    final version = info.availableVersionName ??
        (info.availableVersionCode == null
            ? null
            : info.availableVersionCode.toString());
    final defaultMessage = version == null
        ? 'A new version is available on the App Store.'
        : 'Version $version is available on the App Store.';

    return showCupertinoDialog<bool>(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (context) {
        return CupertinoAlertDialog(
          title: Text(title ?? 'Update Available'),
          content: Text(message ?? defaultMessage),
          actions: [
            if (!forceUpdate)
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(laterButtonText ?? 'Later'),
              ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(updateButtonText ?? 'Update'),
            ),
          ],
        );
      },
    );
  }

  static UpdateAvailability _updateAvailabilityFromValue(Object? value) {
    final intValue = _intFromValue(value);
    return UpdateAvailability.values.firstWhere(
      (element) => element.value == intValue,
      orElse: () => UpdateAvailability.unknown,
    );
  }

  static InstallStatus _installStatusFromValue(Object? value) {
    final intValue = _intFromValue(value);
    return InstallStatus.values.firstWhere(
      (element) => element.value == intValue,
      orElse: () => InstallStatus.unknown,
    );
  }

  static int? _intFromValue(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }

  static String? _stringFromValue(Object? value) {
    return value is String && value.isNotEmpty ? value : null;
  }

  static List<int>? _intListFromValue(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is Iterable) {
      return value.map(_intFromValue).whereType<int>().toList(growable: false);
    }
    return null;
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
  final UpdateAvailability updateAvailability;

  /// Whether an immediate update is allowed.
  final bool immediateUpdateAllowed;

  /// determine the reason why an update cannot be started
  final List<int>? immediateAllowedPreconditions;

  /// Whether a flexible update is allowed.
  final bool flexibleUpdateAllowed;

  /// determine the reason why an update cannot be started
  final List<int>? flexibleAllowedPreconditions;

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
  final InstallStatus installStatus;

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

  /// The latest App Store version string on iOS.
  ///
  /// This is null on Android.
  final String? availableVersionName;

  /// The installed version string on iOS.
  ///
  /// This is null on Android.
  final String? installedVersionName;

  /// The App Store URL resolved during iOS update checks.
  ///
  /// This is null on Android.
  final String? storeUrl;

  /// The App Store numeric app identifier resolved during iOS update checks.
  ///
  /// This is null on Android.
  final int? appStoreId;

  /// The App Store release notes for the available iOS version.
  ///
  /// This is null on Android or when App Store metadata omits release notes.
  final String? releaseNotes;

  AppUpdateInfo({
    required this.updateAvailability,
    required this.immediateUpdateAllowed,
    required List<int>? immediateAllowedPreconditions,
    required this.flexibleUpdateAllowed,
    required List<int>? flexibleAllowedPreconditions,
    required this.availableVersionCode,
    required this.installStatus,
    required this.packageName,
    required this.clientVersionStalenessDays,
    required this.updatePriority,
    this.availableVersionName,
    this.installedVersionName,
    this.storeUrl,
    this.appStoreId,
    this.releaseNotes,
  })  : immediateAllowedPreconditions = immediateAllowedPreconditions == null
            ? null
            : List.unmodifiable(immediateAllowedPreconditions),
        flexibleAllowedPreconditions = flexibleAllowedPreconditions == null
            ? null
            : List.unmodifiable(flexibleAllowedPreconditions);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUpdateInfo &&
          runtimeType == other.runtimeType &&
          updateAvailability == other.updateAvailability &&
          immediateUpdateAllowed == other.immediateUpdateAllowed &&
          listEquals(immediateAllowedPreconditions,
              other.immediateAllowedPreconditions) &&
          flexibleUpdateAllowed == other.flexibleUpdateAllowed &&
          listEquals(flexibleAllowedPreconditions,
              other.flexibleAllowedPreconditions) &&
          availableVersionCode == other.availableVersionCode &&
          installStatus == other.installStatus &&
          packageName == other.packageName &&
          clientVersionStalenessDays == other.clientVersionStalenessDays &&
          updatePriority == other.updatePriority &&
          availableVersionName == other.availableVersionName &&
          installedVersionName == other.installedVersionName &&
          storeUrl == other.storeUrl &&
          appStoreId == other.appStoreId &&
          releaseNotes == other.releaseNotes;

  @override
  int get hashCode => Object.hash(
        updateAvailability,
        immediateUpdateAllowed,
        Object.hashAll(immediateAllowedPreconditions ?? const [null]),
        flexibleUpdateAllowed,
        Object.hashAll(flexibleAllowedPreconditions ?? const [null]),
        availableVersionCode,
        installStatus,
        packageName,
        clientVersionStalenessDays,
        updatePriority,
        availableVersionName,
        installedVersionName,
        storeUrl,
        appStoreId,
        releaseNotes,
      );

  @override
  String toString() => 'AppUpdateInfo{updateAvailability: $updateAvailability, '
      'immediateUpdateAllowed: $immediateUpdateAllowed, '
      'immediateAllowedPreconditions: $immediateAllowedPreconditions, '
      'flexibleUpdateAllowed: $flexibleUpdateAllowed, '
      'flexibleAllowedPreconditions: $flexibleAllowedPreconditions, '
      'availableVersionCode: $availableVersionCode, '
      'installStatus: $installStatus, '
      'packageName: $packageName, '
      'clientVersionStalenessDays: $clientVersionStalenessDays, '
      'updatePriority: $updatePriority, '
      'availableVersionName: $availableVersionName, '
      'installedVersionName: $installedVersionName, '
      'storeUrl: $storeUrl, '
      'appStoreId: $appStoreId, '
      'releaseNotes: $releaseNotes}';
}
