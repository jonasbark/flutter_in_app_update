import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update_plus/in_app_update_plus.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const _appStoreId = '12345678';
  static const _countryCode = 'US';

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  AppUpdateDialogResult? _lastResult;
  bool _forceUpdate = false;
  bool _preferFlexibleUpdate = false;
  bool _isChecking = false;

  bool get _isIos => defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> _checkAndShowUpdateDialog() async {
    final navigatorContext = _navigatorKey.currentContext;
    if (navigatorContext == null) {
      return;
    }

    setState(() {
      _isChecking = true;
    });

    try {
      final result = await InAppUpdate.checkAndShowUpdateDialog(
        navigatorContext,
        appStoreId: _appStoreId,
        countryCode: _countryCode,
        forceUpdate: _forceUpdate,
        preferFlexibleUpdate: _preferFlexibleUpdate,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _lastResult = result;
      });
      _showMessage(_messageForResult(result));
    } catch (e) {
      _showMessage(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    if (_isIos) {
      final navigatorContext = _navigatorKey.currentContext;
      if (navigatorContext == null) {
        return;
      }

      showCupertinoDialog<void>(
        context: navigatorContext,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Result'),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    _messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _messageForResult(AppUpdateDialogResult result) {
    switch (result) {
      case AppUpdateDialogResult.noUpdateAvailable:
        return 'No update available.';
      case AppUpdateDialogResult.updateNotAllowed:
        return 'Update is available but not allowed on this device.';
      case AppUpdateDialogResult.userDismissed:
        return 'Update dismissed.';
      case AppUpdateDialogResult.updateStarted:
        return 'Update flow started.';
      case AppUpdateDialogResult.updateFailed:
        return 'Update failed.';
    }
  }

  String get _statusText {
    final result = _lastResult;
    if (result == null) {
      return 'Ready';
    }
    return _messageForResult(result);
  }

  @override
  Widget build(BuildContext context) {
    if (_isIos) {
      return CupertinoApp(
        navigatorKey: _navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: const CupertinoThemeData(
          primaryColor: CupertinoColors.systemIndigo,
          scaffoldBackgroundColor: CupertinoColors.systemGroupedBackground,
        ),
        home: CupertinoPageScaffold(
          navigationBar: const CupertinoNavigationBar(
            middle: Text('In App Update'),
          ),
          child: SafeArea(
            child: _ExampleContent(
              isIos: true,
              isChecking: _isChecking,
              statusText: _statusText,
              forceUpdate: _forceUpdate,
              preferFlexibleUpdate: _preferFlexibleUpdate,
              onForceUpdateChanged: (value) {
                setState(() {
                  _forceUpdate = value;
                });
              },
              onPreferFlexibleChanged: (value) {
                setState(() {
                  _preferFlexibleUpdate = value;
                });
              },
              onCheckPressed: _checkAndShowUpdateDialog,
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('In App Update'),
        ),
        body: SafeArea(
          child: _ExampleContent(
            isIos: false,
            isChecking: _isChecking,
            statusText: _statusText,
            forceUpdate: _forceUpdate,
            preferFlexibleUpdate: _preferFlexibleUpdate,
            onForceUpdateChanged: (value) {
              setState(() {
                _forceUpdate = value;
              });
            },
            onPreferFlexibleChanged: (value) {
              setState(() {
                _preferFlexibleUpdate = value;
              });
            },
            onCheckPressed: _checkAndShowUpdateDialog,
          ),
        ),
      ),
    );
  }
}

class _ExampleContent extends StatelessWidget {
  const _ExampleContent({
    required this.isIos,
    required this.isChecking,
    required this.statusText,
    required this.forceUpdate,
    required this.preferFlexibleUpdate,
    required this.onForceUpdateChanged,
    required this.onPreferFlexibleChanged,
    required this.onCheckPressed,
  });

  final bool isIos;
  final bool isChecking;
  final String statusText;
  final bool forceUpdate;
  final bool preferFlexibleUpdate;
  final ValueChanged<bool> onForceUpdateChanged;
  final ValueChanged<bool> onPreferFlexibleChanged;
  final VoidCallback onCheckPressed;

  @override
  Widget build(BuildContext context) {
    if (isIos) {
      return Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              children: [
                _CupertinoStatusCard(
                  isChecking: isChecking,
                  statusText: statusText,
                ),
                const SizedBox(height: 16),
                _CupertinoOptionCard(
                  forceUpdate: forceUpdate,
                  onForceUpdateChanged: onForceUpdateChanged,
                ),
              ],
            ),
          ),
          _CupertinoBottomAction(
            isChecking: isChecking,
            onPressed: onCheckPressed,
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Package update helper',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text('Status: $statusText'),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Prefer flexible update'),
                  value: preferFlexibleUpdate,
                  onChanged: onPreferFlexibleChanged,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: isChecking ? null : onCheckPressed,
          child: Text(isChecking ? 'Checking...' : 'Check and Show Update'),
        ),
      ],
    );
  }
}

class _CupertinoStatusCard extends StatelessWidget {
  const _CupertinoStatusCard({
    required this.isChecking,
    required this.statusText,
  });

  final bool isChecking;
  final String statusText;

  @override
  Widget build(BuildContext context) {
    return _CupertinoCard(
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: CupertinoColors.systemIndigo.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: isChecking
                ? const CupertinoActivityIndicator()
                : const Icon(
                    CupertinoIcons.arrow_down_circle_fill,
                    color: CupertinoColors.systemIndigo,
                    size: 30,
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Package update helper',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  statusText,
                  style: TextStyle(
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    fontSize: 15,
                    height: 1.3,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CupertinoOptionCard extends StatelessWidget {
  const _CupertinoOptionCard({
    required this.forceUpdate,
    required this.onForceUpdateChanged,
  });

  final bool forceUpdate;
  final ValueChanged<bool> onForceUpdateChanged;

  @override
  Widget build(BuildContext context) {
    return _CupertinoCard(
      padding: EdgeInsets.zero,
      child: _CupertinoSwitchRow(
        title: 'Force update',
        value: forceUpdate,
        onChanged: onForceUpdateChanged,
      ),
    );
  }
}

class _CupertinoSwitchRow extends StatelessWidget {
  const _CupertinoSwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: CupertinoColors.label.resolveFrom(context),
                fontSize: 16,
                letterSpacing: 0,
              ),
            ),
          ),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _CupertinoBottomAction extends StatelessWidget {
  const _CupertinoBottomAction({
    required this.isChecking,
    required this.onPressed,
  });

  final bool isChecking;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final primaryColor = CupertinoTheme.of(context).primaryColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
        border: Border(
          top: BorderSide(
            color: CupertinoColors.separator.resolveFrom(context),
            width: 0.4,
          ),
        ),
      ),
      child: CupertinoButton(
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        color: primaryColor,
        disabledColor: CupertinoColors.tertiarySystemFill.resolveFrom(context),
        borderRadius: BorderRadius.circular(16),
        onPressed: isChecking ? null : onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isChecking)
              const CupertinoActivityIndicator(color: CupertinoColors.white)
            else
              const Icon(
                CupertinoIcons.arrow_down_circle,
                color: CupertinoColors.white,
                size: 20,
              ),
            const SizedBox(width: 8),
            Text(
              isChecking ? 'Checking' : 'Check and Show Update',
              style: const TextStyle(
                color: CupertinoColors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CupertinoCard extends StatelessWidget {
  const _CupertinoCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
          context,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }
}
