## 4.1.1
* fix data type for `immediateAllowedPreconditions` and `flexibleAllowedPreconditions` (fixes #99)

## 4.1.0
* update Play In-App Update library to 2.10.1, which includes support for Android 14
* introduce `immediateAllowedPreconditions` and `flexibleAllowedPreconditions` fields to `AppUpdateInfo` to check why an update may not be possible

## 4.0.1
* improve documentation (thanks to @enzo-santos)

## 4.0.0
* Update dependencies
* InstallStatus and UpdateAvailability are now enums
* update Dart to min 2.17
* catch SendIntentException caused by the play store update library (fixes #46)

## 3.0.0
* Update dependencies
* Introduce `AppUpdateResult` to know if update is success, user denied or failed. 
* Change to return PlatformException with proper error code instead of message only.

## 2.0.0

* Migrated to null safety (#60)
* __Breaking__: Replaced `updateAvailable` with `updateAvailability`.
* Expose more fields to access, added `updateAvailability`, `installStatus`, `clientVersionStalenessDays` and `updatePriority`. (#40)
* Introduce `UpdateAvailability`  and `InstallStatus` for constants.

## 1.1.15
* fix android Gradle version (6.5.+) build error (#55). thanks for https://github.com/mig35

## 1.1.14
* fix compilation error on iOS (#50)

## 1.1.13
* fix MissingPluginException (#49)

## 1.1.12
* fix #42
* fix #28 (thanks @amaurycannesson)

## 1.1.11
* Update Dependencies (possible fix for #31)
* implement to new Flutter plugin format (#29, #27)

## 1.1.7
* Fix Crashes (#12, #15, #19)

## 1.1.6
* Handle cases where no foreground activity is available (#10)

## 1.1.5
* Fix Result already submitted exception (#8)

## 1.1.4

* Expose Available Version Code: https://developer.android.com/reference/com/google/android/play/core/appupdate/AppUpdateInfo.html#availableVersionCode()
(fixes #7)

## 1.1.3

* Fix Android build.

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
