import 'dart:async';

import 'package:flutter/services.dart';

class InAppUpdate {
  static const MethodChannel _channel = const MethodChannel('in_app_update');

  static Future<InAppUpdateState> checkForUpdate() async {
    final result = await _channel.invokeMethod('checkForUpdate');
    return InAppUpdateState(result['updateAvailable'], result['updateType']);
  }

  static Future<void> performImmediateUpdate() async {
    return await _channel.invokeMethod('performImmediateUpdate');
  }

  static Future<void> startFlexibleUpdate() async {
    return await _channel.invokeMethod('startFlexibleUpdate');
  }

  static Future<void> completeFlexibleUpdate() async {
    return await _channel.invokeMethod('completeFlexibleUpdate');
  }
}

enum UpdateType { FLEXIBLE, IMMEDIATE }

class InAppUpdateState {
  bool updateAvailable;
  UpdateType updateType;

  InAppUpdateState(bool updateAvailable, int updateType) {
    this.updateAvailable = updateAvailable;
    this.updateType = updateType != null ? UpdateType.values[updateType] : null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InAppUpdateState &&
          runtimeType == other.runtimeType &&
          updateAvailable == other.updateAvailable &&
          updateType == other.updateType;

  @override
  int get hashCode => updateAvailable.hashCode ^ updateType.hashCode;

  @override
  String toString() {
    return 'InAppUpdateState{updateAvailable: $updateAvailable}';
  }
}
