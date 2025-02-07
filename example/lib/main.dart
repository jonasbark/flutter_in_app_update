import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  AppUpdateInfo? _updateInfo;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();

  bool _flexibleUpdateAvailable = false;

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> checkForUpdate() async {
    await InAppUpdate.checkForUpdate().then((info) {
      setState(() {
        _updateInfo = info;
      });
    }).catchError((e) {
      showSnack(e.toString());
    });
  }

  void showSnack(String text) {
    if (_scaffoldKey.currentContext != null) {
      ScaffoldMessenger.of(_scaffoldKey.currentContext!)
          .showSnackBar(SnackBar(content: Text(text)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: const Text('In App Update Example App'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: <Widget>[
              Center(
                child: Text('Update info: $_updateInfo'),
              ),
              ElevatedButton(
                onPressed: () => checkForUpdate(),
                child: const Text('Check for Update'),
              ),
              ElevatedButton(
                onPressed: _updateInfo?.updateAvailability ==
                    UpdateAvailability.updateAvailable
                    ? () {
                  InAppUpdate.performImmediateUpdate().catchError((e) {
                    showSnack(e.toString());
                    return AppUpdateResult.inAppUpdateFailed;
                  });
                }
                    : null,
                child: const Text('Perform immediate update'),
              ),
              ElevatedButton(
                onPressed: _updateInfo?.updateAvailability ==
                    UpdateAvailability.updateAvailable
                    ? () {
                  InAppUpdate.startFlexibleUpdate().then((_) {
                    setState(() {
                      _flexibleUpdateAvailable = true;
                    });
                  }).catchError((e) {
                    showSnack(e.toString());
                  });
                }
                    : null,
                child: const Text('Start flexible update'),
              ),
              ElevatedButton(
                onPressed: !_flexibleUpdateAvailable
                    ? null
                    : () {
                  InAppUpdate.completeFlexibleUpdate().then((_) {
                    showSnack("Success!");
                  }).catchError((e) {
                    showSnack(e.toString());
                  });
                },
                child: const Text('Complete flexible update'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
