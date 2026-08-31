import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/chai_cup_loader.dart';
import 'license_service.dart';
import 'screens/admin_home_screen.dart';
import 'screens/locked_screen.dart';
import 'screens/login_screen.dart';

/// Decides what the app shows based on the subscription state.
class LicenseGate extends StatelessWidget {
  const LicenseGate({super.key, required this.child});

  /// The real app, shown only for an active shop.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final gate = context.select<LicenseService, GateState>((s) => s.gate);

    switch (gate) {
      case GateState.loading:
        return const _Splash();
      case GateState.shopAuth:
        return const LoginScreen();
      case GateState.locked:
        return const LockedScreen();
      case GateState.admin:
        return const AdminHomeScreen();
      case GateState.error:
        return const _ErrorRetry();
      case GateState.ready:
        return child;
    }
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 112,
              height: 112,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(28),
              ),
              child: ChaiCupLoader(
                size: 76,
                cupColor: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'kutyo',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: scheme.onSurface,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              'brewing…',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.outline,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry();

  @override
  Widget build(BuildContext context) {
    final service = context.watch<LicenseService>();
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off,
                  size: 56, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                service.error ?? 'Something went wrong.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: service.busy ? null : service.refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
              TextButton(
                onPressed: service.busy ? null : service.signOut,
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
