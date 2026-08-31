import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../widgets/brewing_splash.dart';
import '../license_service.dart';

/// The only sign-in screen: one login ID. The admin's id opens the admin
/// panel; an id the admin registered opens that shop.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _id = TextEditingController();

  @override
  void dispose() {
    _id.dispose();
    super.dispose();
  }

  Future<void> _submit(LicenseService s) async {
    final id = _id.text.trim();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your login ID')),
      );
      return;
    }
    await s.signIn(id);
    if (!mounted) return;
    if (s.error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.error!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LicenseService>();
    final scheme = Theme.of(context).colorScheme;

    // Signing in bridges straight into the app's own brewing splash so the
    // wait looks identical to first load.
    if (s.busy) return const BrewingSplash(message: 'signing you in…');

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(Icons.emoji_food_beverage,
                        size: 48, color: scheme.onPrimaryContainer),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'kutyo',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(
                            fontWeight: FontWeight.w800, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Enter your login ID',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.outline),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _id,
                    autofocus: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => s.busy ? null : _submit(s),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9._-]')),
                      LengthLimitingTextInputFormatter(24),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Login ID',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: s.busy ? null : () => _submit(s),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: s.busy
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Text('Sign in'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No ID? Ask your provider to create one for you.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.outline),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
