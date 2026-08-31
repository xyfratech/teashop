import 'package:flutter/material.dart';

import 'chai_cup_loader.dart';

/// Full-screen "the app is getting ready" state: the chai cup filling under
/// the wordmark. Shown for the initial licence check and while signing in, so
/// the wait looks the same everywhere (and matches the web boot screen).
class BrewingSplash extends StatelessWidget {
  const BrewingSplash({super.key, this.message = 'brewing…'});

  final String message;

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
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
