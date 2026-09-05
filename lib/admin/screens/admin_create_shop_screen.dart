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

  /// true = shop starts on a free trial (default); false = admin activates it
  /// as paid right away, skipping the trial entirely.
  bool _onTrial = true;
  int _activateMonths = 1;

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
    final service = context.read<LicenseService>();
    try {
      var shop = await service.adminRegisterShop(
        loginId: _loginId.text,
        shopName: _shopName.text,
        ownerName: _ownerName.text,
        // Skipping the trial means zero free days — the follow-up extend
        // below is what actually gives the shop paid time.
        trialDays: _onTrial
            ? (int.tryParse(_trialDays.text.trim()) ?? SupabaseConfig.trialDays)
            : 0,
      );
      String? activateError;
      if (!_onTrial) {
        try {
          shop = await service.adminExtend(shop.id, _activateMonths);
        } catch (e) {
          // The login still exists — just tell the admin to activate it
          // manually from the shop's page instead of losing the login id.
          activateError = '$e'.replaceFirst('Exception: ', '');
        }
      }
      if (!mounted) return;
      await _showResult(shop, activateError: activateError);
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

  Future<void> _showResult(Shop shop, {String? activateError}) {
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
            if (activateError != null) ...[
              const SizedBox(height: 14),
              Text(
                'Created, but activation failed: $activateError\n'
                'Open the shop and use "Renew subscription" to activate it.',
                style: TextStyle(color: Theme.of(ctx).colorScheme.error),
              ),
            ],
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
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    SwitchListTile(
                      value: _onTrial,
                      onChanged: (v) => setState(() => _onTrial = v),
                      secondary: Icon(
                        _onTrial ? Icons.hourglass_top : Icons.verified_outlined,
                      ),
                      title: const Text('Start on a free trial'),
                      subtitle: Text(
                        _onTrial
                            ? 'Free access for a set number of days, then locks until paid'
                            : 'Skip the trial — activate as paid right away',
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: _onTrial
                          ? TextFormField(
                              controller: _trialDays,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Trial length (days)',
                                helperText: 'Defaults to 1 week',
                                prefixIcon: Icon(Icons.event_outlined),
                              ),
                              validator: (v) =>
                                  int.tryParse((v ?? '').trim()) == null
                                      ? 'Enter a number'
                                      : null,
                            )
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [1, 3, 6, 12].map((m) {
                                return ChoiceChip(
                                  label: Text('$m month${m == 1 ? '' : 's'}'),
                                  selected: _activateMonths == m,
                                  onSelected: (_) =>
                                      setState(() => _activateMonths = m),
                                );
                              }).toList(),
                            ),
                    ),
                  ],
                ),
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
