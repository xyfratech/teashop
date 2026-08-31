import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_enums.dart';
import '../models/txn.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/app_icons.dart';
import '../utils/formatters.dart';
import 'amount_text.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.txn, this.onTap});

  final Txn txn;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final category = state.categoryById(txn.categoryId);
    final isIncome = txn.type == TxnType.income;
    final tint = isIncome ? AppTheme.income : AppTheme.expense;

    final subtitleParts = <String>[
      if (txn.note.trim().isNotEmpty) txn.note.trim(),
      '${timeLabel(txn.date)} · ${txn.method.label}',
    ];

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: tint.withValues(alpha: 0.14),
        foregroundColor: tint,
        child: Icon(iconFor(category?.iconKey)),
      ),
      title: Text(
        category?.name ?? 'Uncategorised',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        subtitleParts.join('  ·  '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: AmountText(
        isIncome ? txn.amount : -txn.amount,
        signed: true,
        color: tint,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}
