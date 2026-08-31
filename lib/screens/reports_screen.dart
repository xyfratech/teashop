import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/app_enums.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/chart_palette.dart';
import '../utils/context_ext.dart';
import '../utils/formatters.dart';
import '../widgets/section_header.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final months = state.recentMonths(6);
    final summary = state.summaryForMonth(_month);
    final expenseBreakdown = state.categoryBreakdown(_month, TxnType.expense);
    final incomeBreakdown = state.categoryBreakdown(_month, TxnType.income);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            onPressed: () => _showSummary(state),
            icon: const Icon(Icons.ios_share),
            tooltip: 'Text summary',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final m in state.recentMonths(12))
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(monthLabel(m)),
                      selected: m.year == _month.year && m.month == _month.month,
                      onSelected: (_) => setState(
                        () => _month = DateTime(m.year, m.month),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SummaryRow(summary: summary),
          const SizedBox(height: 8),
          const SectionHeader('Last 6 months'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 20, 16, 12),
              child: SizedBox(
                height: 200,
                child: _MonthsBarChart(state: state, months: months),
              ),
            ),
          ),
          const _Legend(),
          const SectionHeader('Where the money went'),
          if (expenseBreakdown.isEmpty)
            _emptyNote(context, 'No expenses recorded for this month.')
          else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: 200,
                  child: _BreakdownPie(entries: expenseBreakdown),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _BreakdownList(
              entries: expenseBreakdown,
              color: AppTheme.expense,
            ),
          ],
          const SectionHeader('Where the money came from'),
          if (incomeBreakdown.isEmpty)
            _emptyNote(context, 'No income recorded for this month.')
          else
            _BreakdownList(
              entries: incomeBreakdown,
              color: AppTheme.income,
            ),
        ],
      ),
    );
  }

  Widget _emptyNote(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            text,
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ),
      );

  Future<void> _showSummary(AppState state) async {
    final money = context.money;
    final s = state.summaryForMonth(_month);
    final buffer = StringBuffer()
      ..writeln(state.shopName)
      ..writeln(monthLabel(_month))
      ..writeln('------------------------------')
      ..writeln('Income:  ${money.format(s.income)}')
      ..writeln('Expense: ${money.format(s.expense)}')
      ..writeln('Profit:  ${money.format(s.profit)}')
      ..writeln()
      ..writeln('Income by category');
    for (final e in state.categoryBreakdown(_month, TxnType.income)) {
      buffer.writeln('  ${e.key}: ${money.format(e.value)}');
    }
    buffer
      ..writeln()
      ..writeln('Expense by category');
    for (final e in state.categoryBreakdown(_month, TxnType.expense)) {
      buffer.writeln('  ${e.key}: ${money.format(e.value)}');
    }
    buffer
      ..writeln()
      ..writeln('Account balance (all time): ${money.format(state.balance)}');

    final text = buffer.toString();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Monthly summary'),
        content: SingleChildScrollView(
          child: SelectableText(
            text,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Summary copied')),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy'),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.summary});

  final PeriodSummary summary;

  @override
  Widget build(BuildContext context) {
    final money = context.money;
    Widget cell(String label, double value, Color color) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Column(
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: color),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  child: Text(
                    money.format(value),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

    return Row(
      children: [
        cell('Income', summary.income, AppTheme.income),
        cell('Expense', summary.expense, AppTheme.expense),
        cell(
          summary.profit >= 0 ? 'Profit' : 'Loss',
          summary.profit,
          Theme.of(context).colorScheme.primary,
        ),
      ],
    );
  }
}

class _MonthsBarChart extends StatelessWidget {
  const _MonthsBarChart({required this.state, required this.months});

  final AppState state;
  final List<DateTime> months;

  @override
  Widget build(BuildContext context) {
    final incomes = <double>[];
    final expenses = <double>[];
    for (final m in months) {
      final s = state.summaryForMonth(m);
      incomes.add(s.income);
      expenses.add(s.expense);
    }
    final maxVal = [
      ...incomes,
      ...expenses,
      1.0,
    ].reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal * 1.2,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, _) {
                final i = value.toInt();
                if (i < 0 || i >= months.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    shortMonth(months[i]),
                    style: const TextStyle(fontSize: 11),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < months.length; i++)
            BarChartGroupData(
              x: i,
              barsSpace: 4,
              barRods: [
                BarChartRodData(
                  toY: incomes[i],
                  color: AppTheme.income,
                  width: 8,
                  borderRadius: BorderRadius.circular(3),
                ),
                BarChartRodData(
                  toY: expenses[i],
                  color: AppTheme.expense,
                  width: 8,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget dot(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
          ],
        );

    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 4),
      child: Row(
        children: [
          dot(AppTheme.income, 'Income'),
          const SizedBox(width: 16),
          dot(AppTheme.expense, 'Expense'),
        ],
      ),
    );
  }
}

class _BreakdownPie extends StatelessWidget {
  const _BreakdownPie({required this.entries});

  final List<MapEntry<String, double>> entries;

  @override
  Widget build(BuildContext context) {
    final total = entries.fold<double>(0, (s, e) => s + e.value);
    return Row(
      children: [
        SizedBox(
          width: 160,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 36,
              sections: [
                for (var i = 0; i < entries.length; i++)
                  PieChartSectionData(
                    value: entries[i].value,
                    color: paletteColor(i),
                    radius: 52,
                    title: total == 0
                        ? ''
                        : '${(entries[i].value / total * 100).round()}%',
                    titleStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < entries.length && i < 6; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: paletteColor(i),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          entries[i].key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BreakdownList extends StatelessWidget {
  const _BreakdownList({required this.entries, required this.color});

  final List<MapEntry<String, double>> entries;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final money = context.money;
    final total = entries.fold<double>(0, (s, e) => s + e.value);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            e.key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          money.format(e.value),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : e.value / total,
                        minHeight: 6,
                        backgroundColor: color.withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation(color),
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
