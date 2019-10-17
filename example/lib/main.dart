import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:in_app_update/in_app_update.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  InAppUpdateState _updateState;

  GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey();

  bool _flexibleUpdateAvailable = false;

  @override
  void initState() {
    super.initState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> checkForUpdate() async {
    InAppUpdate.checkForUpdate().then((state) {
      setState(() {
        _updateState = state;
      });
    }).catchError((e) => _showError(e));
  }

  void _showError(dynamic exception) {
    _scaffoldKey.currentState.showSnackBar(SnackBar(content: Text(exception.toString())));
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
                child: Text('Update state: $_updateState'),
              ),
              RaisedButton(
                child: Text('Check for Update'),
                onPressed: () => checkForUpdate(),
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
            ],
          ),
        ),
      ),
    );
  }
}
