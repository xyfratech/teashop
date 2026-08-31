import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_enums.dart';
import '../models/product.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/context_ext.dart';
import '../widgets/empty_state.dart';
import 'add_product_screen.dart';

class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final products = state.products;

    return Scaffold(
      appBar: AppBar(title: const Text('Menu')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddProductScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Item'),
      ),
      body: products.isEmpty
          ? EmptyState(
              icon: Icons.local_cafe,
              title: 'No menu items yet',
              message: 'Add teas and snacks to record sales in one tap.',
              action: FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddProductScreen()),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add item'),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              itemCount: products.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final p = products[i];
                final money = context.money;
                return Card(
                  child: ListTile(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AddProductScreen(existing: p),
                      ),
                    ),
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primaryContainer,
                      child: Text(
                        p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                      ),
                    ),
                    title: Text(
                      p.name,
                      style: TextStyle(
                        decoration: p.active
                            ? null
                            : TextDecoration.lineThrough,
                      ),
                    ),
                    subtitle: Text(
                      '${money.format(p.price)}  ·  cost ${money.format(p.cost)}'
                      '  ·  ${p.marginPct.toStringAsFixed(0)}% margin',
                    ),
                    trailing: FilledButton.tonal(
                      onPressed:
                          p.active ? () => _sell(context, p) : null,
                      child: const Text('Sell'),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _sell(BuildContext context, Product product) async {
    final state = context.read<AppState>();
    var qty = 1;
    var method = PayMethod.cash;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sell ${product.name}',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text('${ctx.money.format(product.price)} each'),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text(
                      'Quantity',
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    IconButton.outlined(
                      onPressed: () =>
                          setSheet(() => qty = qty > 1 ? qty - 1 : 1),
                      icon: const Icon(Icons.remove),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '$qty',
                        style: Theme.of(ctx).textTheme.titleLarge,
                      ),
                    ),
                    IconButton.outlined(
                      onPressed: () => setSheet(() => qty++),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: PayMethod.values
                      .map(
                        (m) => ChoiceChip(
                          label: Text(m.label),
                          selected: method == m,
                          onSelected: (_) => setSheet(() => method = m),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: AppTheme.income,
                  ),
                  child: Text(
                    'Record sale  ·  ${ctx.money.format(product.price * qty)}',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed != true) return;
    await state.quickSale(product, qty: qty, method: method);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sale recorded: ${product.name} x$qty')),
    );
  }
}
