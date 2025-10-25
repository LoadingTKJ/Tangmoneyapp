import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';
import '../../utils/formatters.dart';

class DetailsScreen extends ConsumerWidget {
  const DetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DetailsFilter filter = ref.watch(detailsFilterProvider);
    final AsyncValue<List<LedgerTransaction>> transactions =
        ref.watch(detailsListProvider);
    final Map<String, Category> categoryMap = ref.watch(categoryMapProvider);
    final List<Account> accounts = ref.watch(accountListProvider);
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[Color(0xFF6C63FF), Color(0xFFA084E8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: _DetailsFilterBar(
                  filter: filter, title: l10n.text('tabDetails')),
            ),
            Expanded(
              child: transactions.when(
                data: (List<LedgerTransaction> list) {
                  if (list.isEmpty) {
                    return const Center(
                      child: Text(
                        '暂无交易记录',
                        style: TextStyle(color: Colors.white70),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    itemBuilder: (BuildContext context, int index) {
                      final LedgerTransaction tx = list[index];
                      final Category? category = categoryMap[tx.categoryCode];
                      Account? account;
                      if (accounts.isNotEmpty) {
                        try {
                          account = accounts.firstWhere(
                              (Account acc) => acc.id == tx.accountId);
                        } catch (_) {
                          account = accounts.first;
                        }
                      }
                      return GestureDetector(
                        onTap: () => _showTransactionDetail(
                            context, tx, category, account),
                        child: _TransactionCard(
                          transaction: tx,
                          category: category,
                          account: account,
                          baseCurrency: ref.watch(selectedBaseCurrencyProvider),
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemCount: list.length,
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (Object error, StackTrace stackTrace) => Center(
                  child: Text(
                    '加载失败：$error',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetail(
    BuildContext context,
    LedgerTransaction tx,
    Category? category,
    Account? account,
  ) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    tx.project,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    formatCurrency(
                      tx.baseAmount.value,
                      tx.baseCurrency,
                      showSign: tx.isIncome,
                    ),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _DetailRow(label: '日期', value: formatDate(tx.date)),
              _DetailRow(label: '类别', value: category?.name ?? tx.categoryCode),
              if (account != null) _DetailRow(label: '账户', value: account.name),
              _DetailRow(
                label: '原币金额',
                value: formatCurrency(
                    tx.originalAmount.value, tx.originalAmount.currency),
              ),
              if (tx.rateUsed != null)
                _DetailRow(
                  label: '汇率',
                  value: tx.rateUsed!.toStringAsFixed(4),
                ),
              if (tx.note.isNotEmpty) _DetailRow(label: '备注', value: tx.note),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  '来源：${tx.source.name}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.transaction,
    required this.category,
    required this.account,
    required this.baseCurrency,
  });

  final LedgerTransaction transaction;
  final Category? category;
  final Account? account;
  final String baseCurrency;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool income = transaction.isIncome;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: income
                    ? Colors.greenAccent.withValues(alpha: 0.2)
                    : Colors.redAccent.withValues(alpha: 0.2),
              ),
              child: Icon(
                income ? Icons.trending_up : Icons.trending_down,
                color: income ? Colors.green : Colors.redAccent,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    transaction.project,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatDate(transaction.date)} · ${category?.name ?? transaction.categoryCode}${account != null ? ' · ${account!.name}' : ''}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  formatCurrency(
                    income
                        ? transaction.baseAmount.value
                        : -transaction.baseAmount.value,
                    baseCurrency,
                    showSign: true,
                  ),
                  style: TextStyle(
                    color: income ? Colors.green : Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${transaction.originalAmount.currency} ${transaction.originalAmount.value.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsFilterBar extends ConsumerWidget {
  const _DetailsFilterBar({required this.filter, required this.title});

  final DetailsFilter filter;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TextStyle? labelStyle = Theme.of(context)
        .textTheme
        .titleMedium
        ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: labelStyle),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: FilledButton.tonal(
                onPressed: () async {
                  final DateTimeRange? picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    initialDateRange: DateTimeRange(
                      start: filter.range.start,
                      end: filter.range.end,
                    ),
                  );
                  if (picked != null) {
                    ref.read(detailsFilterProvider.notifier).state =
                        filter.copyWith(
                      range: DateRange(
                        start: picked.start,
                        end: picked.end,
                      ),
                    );
                  }
                },
                child: Text(
                    '${formatDate(filter.range.start)} → ${formatDate(filter.range.end)}'),
              ),
            ),
            const SizedBox(width: 12),
            DropdownButton<DetailsSort>(
              value: filter.sort,
              dropdownColor: Theme.of(context).colorScheme.surface,
              items: const <DropdownMenuItem<DetailsSort>>[
                DropdownMenuItem(
                    value: DetailsSort.dateDesc, child: Text('日期↓')),
                DropdownMenuItem(
                    value: DetailsSort.dateAsc, child: Text('日期↑')),
                DropdownMenuItem(
                    value: DetailsSort.amountDesc, child: Text('金额↓')),
                DropdownMenuItem(
                    value: DetailsSort.amountAsc, child: Text('金额↑')),
              ],
              onChanged: (DetailsSort? sort) {
                if (sort != null) {
                  ref.read(detailsFilterProvider.notifier).state =
                      filter.copyWith(sort: sort);
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
