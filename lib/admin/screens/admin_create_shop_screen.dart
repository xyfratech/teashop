import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../license_service.dart';
import '../shop.dart';
import '../supabase_config.dart';

/// Admin form: pick a login ID for a shop. No account is created now — the
/// shop links to whoever first signs in with that id.
class AdminCreateShopScreen extends StatefulWidget {
  const AdminCreateShopScreen({super.key});

  @override
  State<AdminCreateShopScreen> createState() => _AdminCreateShopScreenState();
}

class _AdminCreateShopScreenState extends State<AdminCreateShopScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loginId = TextEditingController();
  final _shopName = TextEditingController();
  final _ownerName = TextEditingController();
  final _trialDays =
      TextEditingController(text: '${SupabaseConfig.trialDays}');

  bool _busy = false;

  @override
  void dispose() {
    _loginId.dispose();
    _shopName.dispose();
    _ownerName.dispose();
    _trialDays.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final shop = await context.read<LicenseService>().adminRegisterShop(
            loginId: _loginId.text,
            shopName: _shopName.text,
            ownerName: _ownerName.text,
            trialDays: int.tryParse(_trialDays.text.trim()) ??
                SupabaseConfig.trialDays,
          );
      if (!mounted) return;
      await _showResult(shop);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showResult(Shop shop) {
    final id = shop.username ?? _loginId.text.trim();
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Login created'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Give this login ID to ${shop.ownerName ?? 'the shop'}. '
                'They open the app, type it in and they are in.'),
            const SizedBox(height: 14),
            _CopyField(label: 'Login ID', value: id),
            const SizedBox(height: 6),
            _CopyField(label: 'Shop', value: shop.name),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(
                  text: 'Tea Shop Manager\nShop: ${shop.name}\nLogin ID: $id'));
              ScaffoldMessenger.of(ctx)
                  .showSnackBar(const SnackBar(content: Text('Copied')));
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New shop login')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              TextFormField(
                controller: _loginId,
                autofocus: true,
                autocorrect: false,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9._-]')),
                  LengthLimitingTextInputFormatter(24),
                ],
                decoration: const InputDecoration(
                  labelText: 'Login ID',
                  helperText: 'e.g. SHOP001 — the shop types this to sign in',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.length < 3) return 'At least 3 characters';
                  if (s.toUpperCase() ==
                      SupabaseConfig.adminLoginId.toUpperCase()) {
                    return 'That id is reserved for the admin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _shopName,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Shop name',
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _ownerName,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Owner name (optional)',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _trialDays,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Free days before expiry',
                  prefixIcon: Icon(Icons.event_outlined),
                ),
                validator: (v) => int.tryParse((v ?? '').trim()) == null
                    ? 'Enter a number'
                    : null,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: _busy
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Text('Create login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CopyField extends StatelessWidget {
  const _CopyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: value));
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Copied $label')));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Text('$label  ', style: TextStyle(color: scheme.outline)),
            Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            Icon(Icons.copy, size: 16, color: scheme.outline),
          ],
        ),
      ),
    );
  }
}
