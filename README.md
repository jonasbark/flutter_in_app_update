[![pub package](https://img.shields.io/pub/v/in_app_update.svg)](https://pub.dev/packages/in_app_update)

Presented by

<img src="https://ffuf.de/wp-content/themes/ffuf_theme/images/ffuf-logo.png" width="150">

https://ffuf.de

# in_app_update

Enables In App Updates on Android using the official Android APIs.
https://developer.android.com/guide/app-bundle/in-app-updates#kotlin

## Documentation

The following methods are exposed:
- `Future<InAppUpdateState> checkForUpdate()`: Checks if there's an update available
- `Future<void> performImmediateUpdate()`: Performs an immediate update (full-screen)
- `Future<void> startFlexibleUpdate()`: Starts a flexible update (background download)
- `Future<void> completeFlexibleUpdate()`: Actually installs an available flexible update

Please have a look in the example app on how to use it!

### Android

This plugin integrates the official Android APIs to perform in app updated that were released in 2019:
https://developer.android.com/guide/app-bundle/in-app-updates#kotlin

### iOS
iOS does not offer such a functionality. You might want to look into e.g. https://pub.dev/packages/upgrader. 
