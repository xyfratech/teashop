import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../license_service.dart';
import '../shop.dart';
import '../supabase_config.dart';
import 'shop_status_chip.dart';

class AdminShopDetailScreen extends StatefulWidget {
  const AdminShopDetailScreen({super.key, required this.shop});

  final Shop shop;

  @override
  State<AdminShopDetailScreen> createState() => _AdminShopDetailScreenState();
}

class _AdminShopDetailScreenState extends State<AdminShopDetailScreen> {
  late Shop _shop = widget.shop;
  bool _busy = false;

  LicenseService get _service => context.read<LicenseService>();

  Future<void> _do(Future<Shop> Function() action, String ok) async {
    setState(() => _busy = true);
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() => _shop = updated);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(ok)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _extend(int months) => _do(
        () => _service.adminExtend(_shop.id, months),
        'Extended by $months month${months == 1 ? '' : 's'}',
      );

  Future<void> _pickExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _shop.expiresAt.isAfter(DateTime.now())
          ? _shop.expiresAt
          : DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked == null) return;
    final when = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
    await _do(
      () => _service.adminSetExpiry(_shop.id, when),
      'Expiry set to ${prettyDate(when)}',
    );
  }

  Future<void> _toggleBlocked() => _do(
        () => _service.adminSetBlocked(_shop.id, !_shop.isBlocked),
        _shop.isBlocked ? 'Shop reactivated' : 'Shop paused',
      );

  Future<void> _editNote() async {
    final controller = TextEditingController(text: _shop.adminNote ?? '');
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Admin note'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Payment ref, remarks…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (text == null) return;
    await _do(
      () => _service.adminSetNote(_shop.id, text),
      'Note saved',
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final price = SupabaseConfig.pricePerMonth;
    final sym = SupabaseConfig.currencySymbol;

    return Scaffold(
      appBar: AppBar(title: Text(_shop.name)),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _shop.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                ShopStatusChip(_shop.status),
              ],
            ),
            const SizedBox(height: 12),
            _InfoCard(rows: [
              ('Login ID', _shop.username ?? '—'),
              ('Activated', _shop.activated ? 'Yes' : 'Not yet'),
              ('Owner', _shop.ownerName ?? '—'),
              ('Plan', '$sym$price / month'),
              ('Registered', prettyDate(_shop.createdAt)),
              ('Trial ended', prettyDate(_shop.trialEndsAt)),
              ('Expires', prettyDate(_shop.expiresAt)),
              (
                'Days left',
                _shop.daysLeft < 0 ? '${-_shop.daysLeft} overdue' : '${_shop.daysLeft}'
              ),
              (
                'Last seen',
                _shop.lastSeenAt == null ? '—' : prettyDate(_shop.lastSeenAt!)
              ),
              ('App version', _shop.appVersion ?? '—'),
            ]),
            const SizedBox(height: 16),
            Text('Renew subscription',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: () => _extend(1),
                  child: Text('+1 month  ($sym$price)'),
                ),
                OutlinedButton(
                  onPressed: () => _extend(3),
                  child: Text('+3 months'),
                ),
                OutlinedButton(
                  onPressed: () => _extend(6),
                  child: const Text('+6 months'),
                ),
                OutlinedButton(
                  onPressed: () => _extend(12),
                  child: const Text('+12 months'),
                ),
                OutlinedButton.icon(
                  onPressed: _pickExpiry,
                  icon: const Icon(Icons.event),
                  label: const Text('Set date'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      _shop.isBlocked ? Icons.play_circle : Icons.pause_circle,
                      color: _shop.isBlocked ? scheme.primary : scheme.error,
                    ),
                    title: Text(_shop.isBlocked
                        ? 'Reactivate shop'
                        : 'Pause shop now'),
                    subtitle: Text(_shop.isBlocked
                        ? 'Restores access immediately'
                        : 'Locks the app regardless of expiry date'),
                    onTap: _toggleBlocked,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.sticky_note_2_outlined),
                    title: const Text('Admin note'),
                    subtitle: Text(
                      (_shop.adminNote ?? '').isEmpty
                          ? 'Add a note'
                          : _shop.adminNote!,
                    ),
                    onTap: _editNote,
                  ),
                ],
              ),
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            for (final (k, v) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Text(k,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.outline)),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        v,
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
