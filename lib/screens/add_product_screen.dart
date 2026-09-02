import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../state/app_state.dart';
import '../utils/transliterate.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key, this.existing});

  final Product? existing;

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _nameMl;
  late final TextEditingController _price;
  late final TextEditingController _cost;
  late bool _active;

  /// Auto-transliteration of the English name into Malayalam. We only ever
  /// overwrite the Malayalam field while it still holds the last value we put
  /// there (tracked in [_autoMl]) — once the user edits it by hand, it's theirs.
  Timer? _mlDebounce;
  bool _mlBusy = false;
  String _autoMl = '';

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _name = TextEditingController(text: p?.name ?? '');
    _nameMl = TextEditingController(text: p?.nameMl ?? '');
    _price = TextEditingController(text: p == null ? '' : _num(p.price));
    _cost = TextEditingController(text: p == null ? '' : _num(p.cost));
    _active = p?.active ?? true;
    _name.addListener(_onNameChanged);
  }

  void _onNameChanged() {
    _mlDebounce?.cancel();
    _mlDebounce =
        Timer(const Duration(milliseconds: 500), () => _fillMalayalam());
  }

  /// Fetches the Malayalam spelling for the current English name and drops it
  /// into the Malayalam field. [force] ignores the "user edited it" guard — used
  /// by the convert button next to the field.
  Future<void> _fillMalayalam({bool force = false}) async {
    final src = _name.text.trim();
    final untouched = _nameMl.text.isEmpty || _nameMl.text == _autoMl;
    if (!force && !untouched) return;

    if (src.isEmpty) {
      if (untouched && _nameMl.text.isNotEmpty) {
        _nameMl.clear();
        _autoMl = '';
      }
      return;
    }

    setState(() => _mlBusy = true);
    final ml = await transliterateToMalayalam(src);
    if (!mounted) return;
    setState(() {
      _mlBusy = false;
      final canWrite = force || _nameMl.text.isEmpty || _nameMl.text == _autoMl;
      if (ml != null && canWrite) {
        _nameMl.text = ml;
        _autoMl = ml;
      }
    });
  }

  static String _num(double v) {
    final s = v.toStringAsFixed(2);
    return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
  }

  @override
  void dispose() {
    _mlDebounce?.cancel();
    _name.removeListener(_onNameChanged);
    _name.dispose();
    _nameMl.dispose();
    _price.dispose();
    _cost.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final state = context.read<AppState>();
    final product = Product(
      id: widget.existing?.id ?? state.newId(),
      name: _name.text.trim(),
      nameMl: _nameMl.text.trim(),
      price: double.parse(_price.text.trim()),
      cost: double.tryParse(_cost.text.trim()) ?? 0,
      active: _active,
    );
    if (_isEditing) {
      await state.updateProduct(product);
    } else {
      await state.addProduct(product);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this item?'),
        content: const Text(
          'Past sales that used it are kept. This cannot be undone.',
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
    if (confirmed != true || !mounted) return;
    await context.read<AppState>().deleteProduct(widget.existing!.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.read<AppState>().currency;
    final priceInput = double.tryParse(_price.text.trim()) ?? 0;
    final costInput = double.tryParse(_cost.text.trim()) ?? 0;
    final margin = priceInput - costInput;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit item' : 'New menu item'),
        actions: [
          if (_isEditing)
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Item name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameMl,
              decoration: InputDecoration(
                labelText: 'Malayalam name (optional)',
                hintText: 'ചായ',
                helperText: 'Auto-filled from the name above · shown when the '
                    'menu is switched to മല',
                suffixIcon: _mlBusy
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.translate),
                        tooltip: 'Convert name to Malayalam',
                        onPressed: () => _fillMalayalam(force: true),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _price,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Selling price',
                      prefixText: '$currency ',
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      final d = double.tryParse((v ?? '').trim());
                      if (d == null || d <= 0) return 'Enter a price';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _cost,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Cost (optional)',
                      prefixText: '$currency ',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Margin per unit: $currency ${margin.toStringAsFixed(2)}'
              '${priceInput > 0 ? '  (${(margin / priceInput * 100).toStringAsFixed(0)}%)' : ''}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Available on menu'),
              subtitle: const Text('Turn off to hide from quick sale'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: Text(_isEditing ? 'Save changes' : 'Add item'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
