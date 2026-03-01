import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../../../products/presentation/screens/home_screen.dart';
import '../../../vendor/presentation/screens/vendor_dashboard_screen.dart';
import '../../../../core/services/notification_service.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Future<void> _restoreFuture;
  bool _pushInitDone = false;

  @override
  void initState() {
    super.initState();
    final completer = Completer<void>();
    _restoreFuture = completer.future;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted) {
          completer.complete();
          return;
        }
        await context.read<AuthProvider>().restoreSession();
        if (mounted && context.read<AuthProvider>().isLoggedIn) {
          await NotificationService.ensurePushInitialized(context);
          _pushInitDone = true;
        }
        completer.complete();
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _restoreFuture,
      builder: (context, snapshot) {
        final auth = context.watch<AuthProvider>();

        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) return const LoginScreen();
        if (!auth.isLoggedIn) return const LoginScreen();
        if (!_pushInitDone) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            await NotificationService.ensurePushInitialized(context);
            _pushInitDone = true;
          });
        }
        if (auth.user?.isVendor == true) return const VendorDashboardScreen();
        return const HomeScreen();
      },
    );
  }
}
