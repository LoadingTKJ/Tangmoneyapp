import 'package:uuid/uuid.dart';

import '../../data/db.dart';
import '../../data/import_engine.dart';
import '../../data/models.dart';
import '../../data/rate_provider.dart';

class LedgerService {
  LedgerService({
    required this.database,
    required this.rateProvider,
    this.defaultBaseCurrency = 'CNY',
  });

  final LedgerDatabase database;
  final RateProvider rateProvider;
  final String defaultBaseCurrency;
  static const Uuid _uuid = Uuid();

  Future<Account> createAccount({
    required String name,
    required AccountType type,
    required String currency,
    double balance = 0,
    bool includeInNetWorth = true,
  }) async {
    final Account account = Account(
      id: _uuid.v4(),
      name: name,
      type: type,
      currency: currency.toUpperCase(),
      balance: double.parse(balance.toStringAsFixed(2)),
      includeInNetWorth: includeInNetWorth,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await database.addAccount(account);
    await addCurrency(account.currency);
    return account;
  }

  Future<void> updateAccountBalance(String accountId, double balance) {
    return database.updateAccountBalance(accountId, balance);
  }

  Future<void> addCurrency(String code) async {
    database.addCurrency(code.toUpperCase());
  }

  Future<double> computeTotalAssets(String baseCurrency) async {
    double total = 0;
    for (final Account account in database.accounts) {
      final double current = account.balance;
      if (account.currency.toUpperCase() == baseCurrency.toUpperCase()) {
        total += current;
        continue;
      }
      try {
        final double converted = await rateProvider.convert(
          date: DateTime.now(),
          amount: current,
          from: account.currency,
          to: baseCurrency,
        );
        total += converted;
      } on RateNotFoundException {
        total += current;
      }
    }
    return double.parse(total.toStringAsFixed(2));
  }

  Future<LedgerTransaction> addTransaction({
    required DateTime date,
    required TransactionType type,
    required double amount,
    required String currency,
    required String accountId,
    required String categoryCode,
    String? project,
    String note = '',
    List<String> tags = const <String>[],
    String? baseCurrency,
  }) async {
    final String resolvedBaseCurrency = baseCurrency ?? defaultBaseCurrency;
    double rate;
    try {
      rate = await rateProvider.getRate(
        date: date,
        from: currency,
        to: resolvedBaseCurrency,
      );
    } on RateNotFoundException {
      if (currency.toUpperCase() == resolvedBaseCurrency.toUpperCase()) {
        rate = 1;
      } else {
        rethrow;
      }
    }

    final double converted = double.parse(
      (currency.toUpperCase() == resolvedBaseCurrency.toUpperCase()
              ? amount
              : amount * rate)
          .toStringAsFixed(2),
    );

    final LedgerTransaction transaction = LedgerTransaction(
      id: _uuid.v4(),
      date: date,
      type: type,
      originalAmount: MoneyAmount(
        value: double.parse(amount.toStringAsFixed(2)),
        currency: currency,
      ),
      rateUsed: rate,
      baseCurrency: resolvedBaseCurrency,
      baseAmount: MoneyAmount(
        value: converted,
        currency: resolvedBaseCurrency,
      ),
      accountId: accountId,
      categoryCode: categoryCode,
      project: project ?? '未命名项目',
      note: note,
      source: TransactionSource.manual,
      tags: tags,
    );

    await database.insertTransaction(transaction);
    await _applyTransactionToAccount(transaction);
    return transaction;
  }

  Future<void> deleteTransaction(String id) {
    return database.deleteTransaction(id);
  }

  Future<List<LedgerTransaction>> fetchTransactions() {
    return database.fetchTransactions();
  }

  Future<List<LedgerTransaction>> listTransactions({
    DateRange? range,
    String? category,
    DetailsSort sort = DetailsSort.dateDesc,
  }) {
    return database.listTransactions(
      range: range,
      categoryCode: category,
      sort: sort,
    );
  }

  Future<void> importEntries(
    List<ImportEntry> entries, {
    String? baseCurrency,
  }) async {
    for (final ImportEntry entry in entries) {
      await addTransaction(
        date: entry.date,
        type:
            entry.isExpense ? TransactionType.expense : TransactionType.income,
        amount: entry.amount,
        currency: entry.currency,
        accountId: database.accounts.first.id,
        categoryCode: entry.categoryCode.isEmpty
            ? database.categories.first.code
            : entry.categoryCode,
        project: entry.project,
        note: entry.note,
        baseCurrency: baseCurrency,
      );
    }
  }

  Future<void> rebaseTransactions(String targetCurrency) async {
    final String normalizedTarget = targetCurrency.toUpperCase();
    final List<LedgerTransaction> transactions = await fetchTransactions();
    for (final LedgerTransaction transaction in transactions) {
      if (transaction.baseCurrency.toUpperCase() == normalizedTarget) {
        continue;
      }
      try {
        final double converted = await rateProvider.convert(
          date: transaction.date,
          amount: transaction.originalAmount.value,
          from: transaction.originalAmount.currency,
          to: normalizedTarget,
        );
        final double newRate = await rateProvider.getRate(
          date: transaction.date,
          from: transaction.originalAmount.currency,
          to: normalizedTarget,
        );

        final LedgerTransaction updated = transaction.copyWith(
          baseCurrency: normalizedTarget,
          baseAmount: MoneyAmount(value: converted, currency: normalizedTarget),
          rateUsed: newRate,
          updatedAt: DateTime.now(),
        );
        await database.replaceTransaction(updated);
      } on RateNotFoundException {
        // Skip transactions without known rates; retains previous base currency.
      }
    }
  }

  Future<void> _applyTransactionToAccount(
      LedgerTransaction transaction) async {
    final Account? account =
        database.findAccountById(transaction.accountId);
    if (account == null) {
      return;
    }
    if (!transaction.isIncome && !transaction.isExpense) {
      return;
    }

    final String accountCurrency = account.currency.toUpperCase();
    final String originalCurrency =
        transaction.originalAmount.currency.toUpperCase();
    double amountInAccountCurrency =
        transaction.originalAmount.value;

    if (originalCurrency != accountCurrency) {
      try {
        amountInAccountCurrency = await rateProvider.convert(
          date: transaction.date,
          amount: transaction.originalAmount.value,
          from: transaction.originalAmount.currency,
          to: account.currency,
        );
      } on RateNotFoundException {
        if (transaction.baseCurrency.toUpperCase() ==
            accountCurrency) {
          amountInAccountCurrency = transaction.baseAmount.value;
        }
      }
    }

    double delta = double.parse(
      amountInAccountCurrency.toStringAsFixed(2),
    );
    if (transaction.isExpense) {
      delta = -delta;
    }

    final double newBalance =
        double.parse((account.balance + delta).toStringAsFixed(2));
    await database.updateAccountBalance(account.id, newBalance);
  }
}
