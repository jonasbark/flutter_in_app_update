# in_app_update_example

Demonstrates how to use the in_app_update plugin.

```dart
  RaisedButton(
    child: Text('Check for Update'),
    onPressed: () {
      InAppUpdate.checkForUpdate().then((state) {
            setState(() {
              _updateState = state;
            });
          }).catchError((e) => _showError(e));
    },
  ),
  RaisedButton(
    child: Text('Perform immediate update'),
    onPressed: () {
      InAppUpdate.performImmediateUpdate();
    },
  ),
  RaisedButton(
    child: Text('Start flexible update'),
    onPressed: () {
      InAppUpdate.startFlexibleUpdate().then((_) {
        setState(() {
          _flexibleUpdateAvailable = true;
        });
      }).catchError((e) => _showError(e));
    },
  ),
  RaisedButton(
    child: Text('Complete flexible update'),
    onPressed: !_flexibleUpdateAvailable
        ? null
        : () {
            InAppUpdate.completeFlexibleUpdate().then((_) {
              _scaffoldKey.currentState.showSnackBar(SnackBar(content: Text('Success!')));
            }).catchError((e) => _showError(e));
            ;
          },
  )
```