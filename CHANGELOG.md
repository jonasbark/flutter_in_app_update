## 1.1.1

* **Breaking change**: Renamed `InAppUpdateState` to `AppUpdateInfo` to mirror the Android SDK and
  the `updateType` property has been replaced by `immediateUpdateAllowed` & `flexibleUpdateAllowed`.
  The `updateType` property was previously broken. Consequently, refactoring is sensible.
  This also means that `UpdateType` has been removed.
* Added support for resuming immediate updates that were cancelled.
  This is handled automatically and does not require any Flutter-side code.
* Added documentation to the library.

## 1.0.2

* Readme and example updates

## 1.0.0

* First version released.
