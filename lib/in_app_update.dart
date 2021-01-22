import 'dart:async';

import 'package:flutter/services.dart';

class InstallStatus {
  InstallStatus._();

  static int get unknown => 0;
  static int get pending => 1;
  static int get downloading => 2;
  static int get installing => 3;
  static int get installed => 4;
  static int get failed => 5;
  static int get canceled => 6;
  static int get downloaded => 11;
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
      result['updateAvailable'],
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
  static Future<void> performImmediateUpdate() async {
    return await _channel.invokeMethod('performImmediateUpdate');
  }

  /// Starts the download of the app update.
  ///
  /// Throws a [PlatformException] if the download fails.
  /// When the returned [Future] is completed without any errors,
  /// [completeFlexibleUpdate] can be called to install the update.
  ///
  /// [checkForUpdate] has to be called first to be able to run this.
  static Future<void> startFlexibleUpdate() async {
    return await _channel.invokeMethod('startFlexibleUpdate');
  }

  /// Installs the update downloaded via [startFlexibleUpdate].
  /// [startFlexibleUpdate] has to be completed successfully.
  static Future<void> completeFlexibleUpdate() async {
    return await _channel.invokeMethod('completeFlexibleUpdate');
  }
}

class AppUpdateInfo {
  final bool updateAvailable, immediateUpdateAllowed, flexibleUpdateAllowed;
  final int availableVersionCode,
      installStatus,
      clientVersionStalenessDays,
      updatePriority;
  final String packageName;

  AppUpdateInfo(
    this.updateAvailable,
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
          updateAvailable == other.updateAvailable &&
          immediateUpdateAllowed == other.immediateUpdateAllowed &&
          flexibleUpdateAllowed == other.flexibleUpdateAllowed &&
          availableVersionCode == other.availableVersionCode &&
          installStatus == other.installStatus &&
          packageName == other.packageName &&
          clientVersionStalenessDays == other.clientVersionStalenessDays &&
          updatePriority == other.updatePriority;

  @override
  int get hashCode =>
      updateAvailable.hashCode ^
      immediateUpdateAllowed.hashCode ^
      flexibleUpdateAllowed.hashCode ^
      availableVersionCode.hashCode ^
      installStatus.hashCode ^
      packageName.hashCode ^
      clientVersionStalenessDays.hashCode ^
      updatePriority.hashCode;

  @override
  String toString() => 'InAppUpdateState{updateAvailable: $updateAvailable, '
      'immediateUpdateAllowed: $immediateUpdateAllowed, '
      'flexibleUpdateAllowed: $flexibleUpdateAllowed, '
      'availableVersionCode: $availableVersionCode, '
      'installStatus: $installStatus, '
      'packageName: $packageName, '
      'clientVersionStalenessDays: $clientVersionStalenessDays, '
      'updatePriority: $updatePriority}';
}
