import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../license_service.dart';
import '../shop.dart';
import 'admin_create_shop_screen.dart';
import 'admin_shop_detail_screen.dart';
import 'shop_status_chip.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

enum _Filter { all, active, trial, expiring, expired, blocked }

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  late Future<List<Shop>> _future;
  String _query = '';
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    _future = context.read<LicenseService>().adminListShops();
  }

  Future<void> _reload() async {
    setState(() {
      _future = context.read<LicenseService>().adminListShops();
    });
    await _future;
  }

  Future<void> _createShop() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AdminCreateShopScreen()),
    );
    if (created == true) await _reload();
  }

  bool _matchesFilter(Shop s) {
    switch (_filter) {
      case _Filter.all:
        return true;
      case _Filter.active:
        return s.status == ShopStatus.active;
      case _Filter.trial:
        return s.status == ShopStatus.trial;
      case _Filter.expiring:
        return s.status == ShopStatus.expiringSoon;
      case _Filter.expired:
        return s.status == ShopStatus.expired;
      case _Filter.blocked:
        return s.status == ShopStatus.blocked;
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<LicenseService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shops'),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: service.busy ? null : service.adminSignOut,
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createShop,
        icon: const Icon(Icons.add),
        label: const Text('Register shop'),
      ),
      body: FutureBuilder<List<Shop>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorView(
              message: '${snap.error}',
              onRetry: _reload,
            );
          }
          final all = snap.data ?? const <Shop>[];
          final q = _query.trim().toLowerCase();
          final shops = all
              .where(_matchesFilter)
              .where((s) =>
                  q.isEmpty ||
                  s.name.toLowerCase().contains(q) ||
                  (s.username ?? '').toLowerCase().contains(q) ||
                  (s.phone ?? '').toLowerCase().contains(q) ||
                  (s.ownerName ?? '').toLowerCase().contains(q))
              .toList();

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              children: [
                _Counters(all: all),
                const SizedBox(height: 10),
                TextField(
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search shop, login ID or owner',
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final f in _Filter.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(_filterLabel(f)),
                            selected: _filter == f,
                            onSelected: (_) => setState(() => _filter = f),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (shops.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: Text('No shops match.')),
                  )
                else
                  for (final shop in shops)
                    _ShopCard(
                      shop: shop,
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AdminShopDetailScreen(shop: shop),
                          ),
                        );
                        await _reload();
                      },
                    ),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _filterLabel(_Filter f) {
    switch (f) {
      case _Filter.all:
        return 'All';
      case _Filter.active:
        return 'Active';
      case _Filter.trial:
        return 'Trial';
      case _Filter.expiring:
        return 'Expiring';
      case _Filter.expired:
        return 'Expired';
      case _Filter.blocked:
        return 'Blocked';
    }
  }
}

class _Counters extends StatelessWidget {
  const _Counters({required this.all});

  final List<Shop> all;

  @override
  Widget build(BuildContext context) {
    int count(ShopStatus s) => all.where((e) => e.status == s).length;
    final items = <(String, int, Color)>[
      ('Total', all.length, Theme.of(context).colorScheme.primary),
      ('Active', count(ShopStatus.active), shopStatusColor(ShopStatus.active)),
      ('Trial', count(ShopStatus.trial), shopStatusColor(ShopStatus.trial)),
      (
        'Expiring',
        count(ShopStatus.expiringSoon),
        shopStatusColor(ShopStatus.expiringSoon)
      ),
      (
        'Expired',
        count(ShopStatus.expired),
        shopStatusColor(ShopStatus.expired)
      ),
      (
        'Blocked',
        count(ShopStatus.blocked),
        shopStatusColor(ShopStatus.blocked)
      ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (label, value, color) in items)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    '$value',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  Text(label,
                      style: TextStyle(fontSize: 11, color: color)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  const _ShopCard({required this.shop, required this.onTap});

  final Shop shop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        title: Row(
          children: [
            Expanded(
              child: Text(
                shop.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            ShopStatusChip(shop.status),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(shop.username ?? shop.phone ?? 'no login id'),
                ),
                if (!shop.activated)
                  Text('not activated',
                      style: TextStyle(
                          color: scheme.error,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
              ],
            ),
            Text(
              relativeExpiry(shop),
              style: TextStyle(color: scheme.outline, fontSize: 12),
            ),
            if (shop.lastSeenAt != null)
              Text(
                'Last seen ${prettyDate(shop.lastSeenAt!)}',
                style: TextStyle(color: scheme.outline, fontSize: 11),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        isThreeLine: true,
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
