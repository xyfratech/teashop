import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_enums.dart';
import '../models/category.dart';
import '../state/app_state.dart';
import '../utils/app_icons.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final income = state.categoriesOfType(TxnType.income);
    final expense = state.categoriesOfType(TxnType.expense);

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Category'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          _GroupHeader('Income (${income.length})'),
          for (final c in income) _tile(context, state, c),
          _GroupHeader('Expense (${expense.length})'),
          for (final c in expense) _tile(context, state, c),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, AppState state, Category c) {
    final uses = state.categoryUsageCount(c.id);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
        child: Icon(iconFor(c.iconKey)),
      ),
      title: Text(c.name),
      subtitle: Text(uses == 1 ? '1 entry' : '$uses entries'),
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'edit') _edit(context, c);
          if (v == 'delete') _delete(context, state, c);
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
      onTap: () => _edit(context, c),
    );
  }

  Future<void> _delete(
    BuildContext context,
    AppState state,
    Category c,
  ) async {
    final uses = state.categoryUsageCount(c.id);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${c.name}"?'),
        content: Text(
          uses == 0
              ? 'This category is not used by any entry.'
              : '$uses entries use this category. They will show as '
                  '"Uncategorised" but keep their amounts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await state.deleteCategory(c.id);
    }
  }

  Future<void> _edit(BuildContext context, Category? existing) async {
    final state = context.read<AppState>();
    await showDialog<void>(
      context: context,
      builder: (_) => _CategoryDialog(existing: existing, state: state),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
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

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({required this.existing, required this.state});

  final Category? existing;
  final AppState state;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final TextEditingController _name;
  late TxnType _type;
  late String _iconKey;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _type = widget.existing?.type ?? TxnType.expense;
    _iconKey = widget.existing?.iconKey ?? 'other';
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final category = Category(
      id: widget.existing?.id ?? widget.state.newId(),
      name: name,
      type: _type,
      iconKey: _iconKey,
    );
    if (widget.existing == null) {
      await widget.state.addCategory(category);
    } else {
      await widget.state.updateCategory(category);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final keys = kIconChoices.keys.toList();
    return AlertDialog(
      title: Text(widget.existing == null ? 'New category' : 'Edit category'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 16),
            SegmentedButton<TxnType>(
              segments: const [
                ButtonSegment(value: TxnType.income, label: Text('Income')),
                ButtonSegment(value: TxnType.expense, label: Text('Expense')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Icon',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final k in keys)
                  InkWell(
                    onTap: () => setState(() => _iconKey = k),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _iconKey == k
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _iconKey == k
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                        ),
                      ),
                      child: Icon(iconFor(k), size: 22),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
