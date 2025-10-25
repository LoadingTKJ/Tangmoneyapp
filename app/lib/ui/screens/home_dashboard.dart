import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';
import '../../utils/formatters.dart';
import '../widgets/gradient_appbar.dart';
import '../widgets/rounded_card.dart';
import '../widgets/summary_chip.dart';
import 'add_transaction.dart';
import 'import_excel.dart';

class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String title = ref.watch(appTitleProvider);
    final MonthlySummary summary = ref.watch(monthlySummaryProvider);
    final AsyncValue<List<LedgerTransaction>> transactions =
        ref.watch(transactionListProvider);
    final Map<String, Category> categoryMap = ref.watch(categoryMapProvider);
    final List<Account> accounts = ref.watch(accountListProvider);
    final Map<String, Account> accountMap = <String, Account>{
      for (final Account account in accounts) account.id: account,
    };
    final AsyncValue<double> totalAssets = ref.watch(totalAssetsProvider);
    final List<String> currencies = ref.watch(currencyOptionsProvider);
    final ledgerService = ref.read(ledgerServiceProvider);

    Future<void> changeBaseCurrency(String value) async {
      if (value == summary.currency) {
        return;
      }
      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(content: Text('正在重算为 $value ...')),
      );
      ref.read(selectedBaseCurrencyProvider.notifier).state = value;
      await ledgerService.rebaseTransactions(value);
      messenger.showSnackBar(
        SnackBar(content: Text('基准币已切换为 $value')),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            Color(0xFF6366F1),
            Color(0xFF8B5CF6),
            Color(0xFF3B82F6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            GradientAppBar(
              title: title,
              actions: <Widget>[
                IconButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ImportExcelScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.upload_file_rounded,
                      color: Colors.white),
                  tooltip: l10n.text('importExcel'),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    RoundedCard(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AddTransactionScreen(),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              l10n.text('addTransaction'),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const AddTransactionScreen(),
                              ),
                            ),
                            child: Text(l10n.text('actionAddEntry')),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _TotalAssetCard(
                      totalAssets: totalAssets,
                      accounts: accounts,
                      baseCurrency: summary.currency,
                    ),
                    const SizedBox(height: 16),
                    RoundedCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  l10n.text('monthlyBill'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              DropdownButton<String>(
                                value: summary.currency,
                                items: currencies
                                    .map(
                                      (String code) => DropdownMenuItem<String>(
                                        value: code,
                                        child: Text(code),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (String? value) {
                                  if (value != null) {
                                    changeBaseCurrency(value);
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SummaryChip(
                            label: l10n.text('income'),
                            value: formatCurrency(
                              summary.income,
                              summary.currency,
                              showSign: true,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SummaryChip(
                            label: l10n.text('expense'),
                            value: formatCurrency(
                              -summary.expense,
                              summary.currency,
                              showSign: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    transactions.when(
                      data: (List<LedgerTransaction> list) {
                        if (list.isEmpty) {
                          return RoundedCard(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 24, horizontal: 12),
                              child: Center(
                                child: Text(
                                  l10n.text('emptyTransactions'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(color: Colors.white),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            RoundedCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    l10n.text('analysis'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ...list.take(5).map(
                                        (LedgerTransaction transaction) =>
                                            _TransactionTile(
                                          transaction: transaction,
                                          category: categoryMap[
                                              transaction.categoryCode],
                                          account:
                                              accountMap[transaction.accountId],
                                          baseCurrency: summary.currency,
                                        ),
                                      ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                      loading: () => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      error: (Object error, StackTrace stackTrace) =>
                          RoundedCard(
                        child: Text(
                          '加载失败：$error',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.redAccent),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalAssetCard extends StatelessWidget {
  const _TotalAssetCard({
    required this.totalAssets,
    required this.accounts,
    required this.baseCurrency,
  });

  final AsyncValue<double> totalAssets;
  final List<Account> accounts;
  final String baseCurrency;

  @override
  Widget build(BuildContext context) {
    return RoundedCard(
      child: totalAssets.when(
        data: (double value) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                '总资产',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                formatCurrency(value, baseCurrency),
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (accounts.isEmpty)
                Text(
                  '暂无账户，前往设置中添加。',
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              else
                Column(
                  children: accounts
                      .take(4)
                      .map(
                        (Account account) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      account.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _accountTypeLabel(account.type),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                formatCurrency(
                                  account.balance,
                                  account.currency,
                                ),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => Text(
          '资产计算失败：$error',
          style: const TextStyle(color: Colors.redAccent),
        ),
      ),
    );
  }
}

String _accountTypeLabel(AccountType type) {
  switch (type) {
    case AccountType.cash:
      return '现金账户';
    case AccountType.bank:
      return '储蓄账户';
    case AccountType.credit:
      return '信用账户';
    case AccountType.investment:
      return '投资账户';
    case AccountType.wallet:
      return '电子钱包';
    case AccountType.virtual:
      return '虚拟账户';
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
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
    final bool isExpense = transaction.isExpense;
    final Color accent =
        isExpense ? Colors.pinkAccent : Colors.lightGreenAccent;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.06),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            backgroundColor: accent.withValues(alpha: 0.2),
            child: Icon(
              isExpense ? Icons.trending_down : Icons.trending_up,
              color: accent,
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
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatDate(transaction.date)} · ${category?.name ?? transaction.categoryCode} · ${account?.name ?? account?.id ?? ''}',
                  style: const TextStyle(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                formatCurrency(
                  isExpense
                      ? -transaction.baseAmount.value
                      : transaction.baseAmount.value,
                  baseCurrency,
                  showSign: true,
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                formatCurrency(
                  transaction.originalAmount.value,
                  transaction.originalAmount.currency,
                ),
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
