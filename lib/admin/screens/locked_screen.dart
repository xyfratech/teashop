import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../license_service.dart';
import '../supabase_config.dart';

/// Shown when a shop's subscription has lapsed or an admin has blocked it.
/// The ledger is untouched and returns the moment the subscription is renewed.
class LockedScreen extends StatelessWidget {
  const LockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LicenseService>();
    final shop = s.shop;
    final scheme = Theme.of(context).colorScheme;
    final blocked = shop?.isBlocked ?? false;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    blocked ? Icons.lock : Icons.hourglass_disabled,
                    size: 64,
                    color: scheme.error,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    blocked
                        ? 'This shop has been paused'
                        : 'Subscription expired',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    blocked
                        ? 'Please contact support to reactivate.'
                        : 'Renew to keep using Tea Shop Manager. Your data is '
                            'safe and comes right back.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.outline),
                  ),
                  const SizedBox(height: 20),
                  if (shop != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          _row('Shop', shop.name),
                          _row('Login ID', shop.username ?? shop.phone ?? '—'),
                          _row(
                            'Expired on',
                            _fmtDate(shop.expiresAt),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: scheme.outlineVariant),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${s.currency}${s.pricePerMonth} / month',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 10),
                        _CopyRow(
                          label: 'Pay by UPI',
                          value: SupabaseConfig.supportUpiId,
                        ),
                        const SizedBox(height: 6),
                        _CopyRow(
                          label: 'Help',
                          value: SupabaseConfig.supportContact,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => _contact(context),
                          icon: const Icon(Icons.chat_outlined),
                          label: const Text('Message support'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: s.busy ? null : s.refresh,
                    icon: s.busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child:
                                CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Icon(Icons.refresh),
                    label: const Text("I've paid — refresh"),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                  TextButton(
                    onPressed: s.busy ? null : s.signOut,
                    child: const Text('Sign out'),
                  ),
                  if (s.offline)
                    Text(
                      'Offline — showing last known status.',
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

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Text(k),
            const Spacer(),
            Flexible(
              child: Text(
                v,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _contact(BuildContext context) async {
    final raw = SupabaseConfig.supportContact.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$raw');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(SupabaseConfig.supportContact)),
        );
      }
    }
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.copy, size: 18),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Copied $value')),
            );
          },
        ),
      ],
    );
  }
}
