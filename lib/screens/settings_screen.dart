import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../admin/ledger_sync.dart';
import '../admin/license_service.dart';
import '../admin/screens/shop_status_chip.dart';
import '../state/app_state.dart';
import '../utils/context_ext.dart';
import 'categories_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final license = context.watch<LicenseService>();
    final money = context.money;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _Heading('Subscription'),
          _SubscriptionTile(license: license),
          const Divider(height: 24),
          const _Heading('Cloud backup'),
          _LedgerBackupTile(sync: context.watch<LedgerSync>()),
          const Divider(height: 24),
          const _Heading('Shop'),
          ListTile(
            leading: const Icon(Icons.storefront_outlined),
            title: const Text('Shop name'),
            subtitle: Text(state.shopName),
            onTap: () => _editText(
              context,
              title: 'Shop name',
              initial: state.shopName,
              onSave: (v) async {
                await state.setShopName(v);
                await license.updateShopName(v);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.payments_outlined),
            title: const Text('Currency symbol'),
            subtitle: Text(state.currency),
            onTap: () => _pickCurrency(context, state),
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text('Opening balance'),
            subtitle: Text(money.format(state.openingBalance)),
            onTap: () => _editNumber(
              context,
              title: 'Opening balance',
              initial: state.openingBalance,
              onSave: state.setOpeningBalance,
            ),
          ),
          const Divider(height: 24),
          const _Heading('Organise'),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('Categories'),
            subtitle: Text('${state.categories.length} total'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CategoriesScreen()),
            ),
          ),
          const Divider(height: 24),
          const _Heading('Appearance'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('System'),
                  icon: Icon(Icons.brightness_auto),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode),
                ),
              ],
              selected: {state.themeMode},
              onSelectionChanged: (s) => state.setThemeMode(s.first),
            ),
          ),
          const Divider(height: 24),
          const _Heading('At a glance'),
          _StatRow(
            label: 'All-time income',
            value: money.format(state.totalIncome),
          ),
          _StatRow(
            label: 'All-time expense',
            value: money.format(state.totalExpense),
          ),
          _StatRow(
            label: 'All-time profit',
            value: money.format(state.totalProfit),
          ),
          _StatRow(
            label: 'Current balance',
            value: money.format(state.balance),
          ),
          _StatRow(label: 'Entries recorded', value: '${state.txns.length}'),
          const Divider(height: 24),
          const _Heading('Danger zone'),
          ListTile(
            leading: Icon(
              Icons.delete_forever_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Reset all data',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            subtitle: const Text('Deletes every entry and restores samples'),
            onTap: () => _confirmReset(context, state),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Tea Shop Manager · offline · data stays on this device',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _editText(
    BuildContext context, {
    required String title,
    required String initial,
    required Future<void> Function(String) onSave,
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
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
    if (result != null && result.isNotEmpty) {
      await onSave(result);
    }
  }

  Future<void> _editNumber(
    BuildContext context, {
    required String title,
    required double initial,
    required Future<void> Function(double) onSave,
  }) async {
    final controller = TextEditingController(
      text: initial == 0 ? '' : initial.toString(),
    );
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
          ],
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
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
    if (result == null) return;
    final value = double.tryParse(result);
    if (value != null) {
      await onSave(value);
    }
  }

  Future<void> _pickCurrency(BuildContext context, AppState state) async {
    const options = ['₹', r'$', '€', '£', '¥', '৳', 'RM', 'Rs'];
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            for (final o in options)
              ListTile(
                title: Text(o),
                trailing:
                    state.currency == o ? const Icon(Icons.check) : null,
                onTap: () {
                  state.setCurrency(o);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, AppState state) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset all data?'),
        content: const Text(
          'Every transaction, product and category will be deleted and the '
          'sample data restored. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await state.clearAll();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All data reset')),
    );
  }
}

class _SubscriptionTile extends StatelessWidget {
  const _SubscriptionTile({required this.license});

  final LicenseService license;

  @override
  Widget build(BuildContext context) {
    final shop = license.shop;
    final scheme = Theme.of(context).colorScheme;

    if (shop == null) {
      return const ListTile(
        leading: Icon(Icons.workspace_premium_outlined),
        title: Text('Not linked to a subscription'),
      );
    }

    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.workspace_premium_outlined),
          title: Row(
            children: [
              Text('${license.currency}${license.pricePerMonth} / month'),
              const SizedBox(width: 8),
              ShopStatusChip(shop.status),
            ],
          ),
          subtitle: Text(
            shop.daysLeft < 0
                ? 'Expired on ${prettyDate(shop.expiresAt)}'
                : 'Renews / expires ${prettyDate(shop.expiresAt)}'
                    '  ·  ${shop.daysLeft} days left',
          ),
        ),
        if (license.offline)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Offline — last synced status',
                style: TextStyle(color: scheme.outline, fontSize: 12),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: license.busy ? null : license.refresh,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: license.busy
                    ? null
                    : () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Sign out of this shop?'),
                            content: const Text(
                              'Your ledger stays on this device. You will '
                              'need your login ID to sign back in.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Sign out'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) await license.signOut();
                      },
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LedgerBackupTile extends StatelessWidget {
  const _LedgerBackupTile({required this.sync});

  final LedgerSync sync;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (!sync.enabled) {
      return const ListTile(
        leading: Icon(Icons.cloud_off_outlined),
        title: Text('Cloud backup is off'),
        subtitle: Text('Every entry is kept on this device only.'),
      );
    }

    final pending = sync.pending;
    final String status;
    if (sync.syncing) {
      status = 'Backing up…';
    } else if (pending > 0) {
      status = '$pending change${pending == 1 ? '' : 's'} waiting to upload';
    } else if (sync.lastSyncAt != null) {
      status = 'All entries backed up · ${prettyDate(sync.lastSyncAt!)}';
    } else {
      status = 'Every entry is copied to the cloud automatically.';
    }

    return Column(
      children: [
        ListTile(
          leading: Icon(
            pending > 0 ? Icons.cloud_sync_outlined : Icons.cloud_done_outlined,
          ),
          title: const Text('Automatic backup'),
          subtitle: Text(status),
        ),
        if (sync.lastError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Last attempt failed — will retry. ${sync.lastError}',
                style: TextStyle(color: scheme.error, fontSize: 12),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: sync.syncing ? null : sync.syncNow,
              icon: const Icon(Icons.sync, size: 18),
              label: const Text('Back up now'),
            ),
          ),
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
