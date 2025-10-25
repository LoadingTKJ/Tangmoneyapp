import 'dart:async';

import 'package:uuid/uuid.dart';

import 'models.dart';

class LedgerDatabase {
  LedgerDatabase._internal() {
    _seedBootstrapData();
  }

  static final LedgerDatabase instance = LedgerDatabase._internal();

  static const Uuid _uuid = Uuid();

  final List<Account> _accounts = <Account>[];
  final List<Category> _categories = <Category>[];
  final List<LedgerTransaction> _transactions = <LedgerTransaction>[];
  final List<RecurringRule> _recurringRules = <RecurringRule>[];
  final Map<String, RateQuote> _latestRates = <String, RateQuote>{};
  final List<RateQuote> _historicalRates = <RateQuote>[];
  final Set<String> _currencies = <String>{'CNY', 'AUD', 'USD'};

  final StreamController<List<Account>> _accountStream =
      StreamController<List<Account>>.broadcast();
  final StreamController<Set<String>> _currencyStream =
      StreamController<Set<String>>.broadcast();
  final StreamController<List<LedgerTransaction>> _transactionStream =
      StreamController<List<LedgerTransaction>>.broadcast();

  List<Account> get accounts => List<Account>.unmodifiable(_accounts);
  List<Category> get categories => List<Category>.unmodifiable(_categories);
  List<RecurringRule> get recurringRules =>
      List<RecurringRule>.unmodifiable(_recurringRules);
  Set<String> get currencies => Set<String>.unmodifiable(_currencies);

  Future<List<LedgerTransaction>> fetchTransactions() async {
    return List<LedgerTransaction>.unmodifiable(_sortedTransactions());
  }

  Stream<List<LedgerTransaction>> watchTransactions() {
    return _transactionStream.stream;
  }

  Stream<List<Account>> watchAccounts() {
    return _accountStream.stream;
  }

  Stream<Set<String>> watchCurrencies() {
    return _currencyStream.stream;
  }

  Account? findAccountById(String id) {
    for (final Account account in _accounts) {
      if (account.id == id) {
        return account;
      }
    }
    return null;
  }

  Future<LedgerTransaction> insertTransaction(
    LedgerTransaction transaction,
  ) async {
    _transactions.add(transaction);
    _notify();
    return transaction;
  }

  Future<void> deleteTransaction(String id) async {
    _transactions.removeWhere((LedgerTransaction element) => element.id == id);
    _notify();
  }

  Future<void> replaceTransaction(LedgerTransaction updated) async {
    final int index = _transactions.indexWhere(
      (LedgerTransaction element) => element.id == updated.id,
    );
    if (index == -1) {
      return;
    }
    _transactions[index] = updated;
    _notify();
  }

  Future<Account> addAccount(Account account) async {
    _accounts.add(account);
    addCurrency(account.currency);
    _notifyAccounts();
    return account;
  }

  Future<void> updateAccount(Account updated) async {
    final int index =
        _accounts.indexWhere((Account element) => element.id == updated.id);
    if (index == -1) {
      return;
    }
    _accounts[index] = updated;
    addCurrency(updated.currency);
    _notifyAccounts();
  }

  Future<void> updateAccountBalance(String id, double newBalance) async {
    final int index =
        _accounts.indexWhere((Account element) => element.id == id);
    if (index == -1) {
      return;
    }
    final Account current = _accounts[index];
    _accounts[index] = current.copyWith(
      balance: double.parse(newBalance.toStringAsFixed(2)),
      updatedAt: DateTime.now(),
    );
    _notifyAccounts();
  }

  void addCurrency(String code) {
    final String normalized = code.toUpperCase();
    if (_currencies.add(normalized)) {
      _notifyCurrencies();
    }
  }

  Future<void> upsertRecurringRule(RecurringRule rule) async {
    final int index = _recurringRules.indexWhere(
      (RecurringRule element) => element.id == rule.id,
    );
    if (index == -1) {
      _recurringRules.add(rule);
    } else {
      _recurringRules[index] = rule;
    }
  }

  Future<List<LedgerTransaction>> listTransactions({
    DateRange? range,
    String? categoryCode,
    DetailsSort sort = DetailsSort.dateDesc,
  }) async {
    Iterable<LedgerTransaction> data = _transactions;
    if (range != null) {
      data = data.where((LedgerTransaction t) => range.contains(t.date));
    }
    if (categoryCode != null && categoryCode.isNotEmpty) {
      data =
          data.where((LedgerTransaction t) => t.categoryCode == categoryCode);
    }

    final List<LedgerTransaction> list = data.toList();
    list.sort((LedgerTransaction a, LedgerTransaction b) {
      switch (sort) {
        case DetailsSort.dateAsc:
          return a.date.compareTo(b.date);
        case DetailsSort.amountDesc:
          return b.baseAmount.value.compareTo(a.baseAmount.value);
        case DetailsSort.amountAsc:
          return a.baseAmount.value.compareTo(b.baseAmount.value);
        case DetailsSort.dateDesc:
          return b.date.compareTo(a.date);
      }
    });
    return list;
  }

  MoneyAmount computeMonthlyTotal({
    required int year,
    required int month,
    required TransactionType type,
    String baseCurrency = 'CNY',
  }) {
    final Iterable<LedgerTransaction> filtered = _transactions.where(
      (LedgerTransaction t) =>
          t.date.year == year && t.date.month == month && t.type == type,
    );

    final double sum = filtered.fold<double>(
      0,
      (double previous, LedgerTransaction element) {
        if (element.baseCurrency == baseCurrency) {
          return previous + element.baseAmount.value;
        }
        return previous + element.originalAmount.value;
      },
    );

    return MoneyAmount(
      value: double.parse(sum.toStringAsFixed(2)),
      currency: baseCurrency,
    );
  }

  Map<String, double> groupByCategory({
    required DateRange range,
  }) {
    final Map<String, double> result = <String, double>{};
    for (final LedgerTransaction transaction in _transactions) {
      if (!range.contains(transaction.date)) {
        continue;
      }
      final double signed = transaction.isExpense
          ? -transaction.baseAmount.value
          : transaction.baseAmount.value;
      result.update(
        transaction.categoryCode,
        (double value) => value + signed,
        ifAbsent: () => signed,
      );
    }
    return result;
  }

  Map<String, double> groupByAccount({
    required DateRange range,
  }) {
    final Map<String, double> result = <String, double>{};
    for (final LedgerTransaction transaction in _transactions) {
      if (!range.contains(transaction.date)) {
        continue;
      }
      final double signed = transaction.isExpense
          ? -transaction.baseAmount.value
          : transaction.baseAmount.value;
      result.update(
        transaction.accountId,
        (double value) => value + signed,
        ifAbsent: () => signed,
      );
    }
    return result;
  }

  void upsertRateQuote(RateQuote quote) {
    final String key = _rateKey(
      quote.date,
      quote.fromCurrency,
      quote.toCurrency,
    );
    _latestRates[key] = quote;
    _historicalRates.removeWhere((RateQuote element) =>
        element.date == quote.date &&
        element.fromCurrency == quote.fromCurrency &&
        element.toCurrency == quote.toCurrency);
    _historicalRates.add(quote);
  }

  RateQuote? findLatestRate(String from, String to, {DateTime? date}) {
    final DateTime reference = date == null
        ? DateTime.now()
        : DateTime(date.year, date.month, date.day);
    final String key = _rateKey(reference, from, to);
    final RateQuote? exact = _latestRates[key];
    if (exact != null) {
      return exact;
    }
    for (final RateQuote quote in _historicalRates.reversed) {
      if (quote.fromCurrency == from && quote.toCurrency == to) {
        return quote;
      }
    }
    return null;
  }

  List<RateSeriesPoint> findSeries({
    required String from,
    required String to,
    required DateRange range,
  }) {
    return _historicalRates
        .where((RateQuote quote) =>
            quote.fromCurrency == from &&
            quote.toCurrency == to &&
            range.contains(quote.date))
        .map((RateQuote quote) =>
            RateSeriesPoint(date: quote.date, rate: quote.rate))
        .toList()
      ..sort(
          (RateSeriesPoint a, RateSeriesPoint b) => a.date.compareTo(b.date));
  }

  String _rateKey(DateTime date, String from, String to) {
    final DateTime normalized = DateTime(date.year, date.month, date.day);
    return '${normalized.toIso8601String()}-${from.toUpperCase()}-${to.toUpperCase()}';
  }

  void dispose() {
    _accountStream.close();
    _currencyStream.close();
    _transactionStream.close();
  }

  void _notify() {
    if (_transactionStream.isClosed) {
      return;
    }
    _transactionStream.add(
      List<LedgerTransaction>.unmodifiable(_sortedTransactions()),
    );
  }

  void _notifyAccounts() {
    if (_accountStream.isClosed) {
      return;
    }
    _accountStream.add(List<Account>.unmodifiable(_accounts));
  }

  void _notifyCurrencies() {
    if (_currencyStream.isClosed) {
      return;
    }
    _currencyStream.add(Set<String>.unmodifiable(_currencies));
  }

  void _seedBootstrapData() {
    if (_accounts.isNotEmpty) {
      return;
    }

    final DateTime now = DateTime.now();

    _accounts.addAll(<Account>[
      Account(
        id: 'acc_cash',
        name: '现金钱包',
        type: AccountType.cash,
        currency: 'CNY',
        balance: 5230.25,
      ),
      Account(
        id: 'acc_cc',
        name: '信用卡',
        type: AccountType.credit,
        currency: 'CNY',
        billDay: 18,
        repayDay: 5,
        balance: -820.5,
      ),
      Account(
        id: 'acc_fx',
        name: '澳洲账户',
        type: AccountType.bank,
        currency: 'AUD',
        balance: 2875.7,
      ),
    ]);

    for (final Account account in _accounts) {
      _currencies.add(account.currency.toUpperCase());
    }

    _categories.addAll(<Category>[
      Category(code: 'A', name: '吃饭'),
      Category(code: 'B', name: '住宿'),
      Category(code: 'C', name: '出行'),
      Category(code: 'D', name: '生活用品'),
      Category(code: 'E', name: '衣服'),
      Category(code: 'F', name: '信用卡还款'),
      Category(code: 'G', name: '学习'),
      Category(code: 'H', name: '大件购物'),
      Category(code: 'I', name: '通讯'),
      Category(code: 'P', name: '玩'),
    ]);

    _transactions.addAll(<LedgerTransaction>[
      LedgerTransaction(
        id: _uuid.v4(),
        date: now.subtract(const Duration(days: 2)),
        type: TransactionType.expense,
        originalAmount: MoneyAmount(value: 35.5, currency: 'CNY'),
        rateUsed: 1,
        baseCurrency: 'CNY',
        baseAmount: MoneyAmount(value: 35.5, currency: 'CNY'),
        accountId: 'acc_cash',
        categoryCode: 'A',
        project: '早餐',
        note: '便利店早餐',
        source: TransactionSource.manual,
        tags: const <String>['日常'],
      ),
      LedgerTransaction(
        id: _uuid.v4(),
        date: now.subtract(const Duration(days: 1)),
        type: TransactionType.income,
        originalAmount: MoneyAmount(value: 250, currency: 'AUD'),
        rateUsed: 4.77,
        baseCurrency: 'CNY',
        baseAmount: MoneyAmount(value: 1192.5, currency: 'CNY'),
        accountId: 'acc_fx',
        categoryCode: 'E',
        project: '兼职收入',
        note: '自由职业款项',
        source: TransactionSource.manual,
        tags: const <String>['副业'],
      ),
      LedgerTransaction(
        id: _uuid.v4(),
        date: now,
        type: TransactionType.expense,
        originalAmount: MoneyAmount(value: 120, currency: 'USD'),
        rateUsed: 7.15,
        baseCurrency: 'CNY',
        baseAmount: MoneyAmount(value: 858, currency: 'CNY'),
        accountId: 'acc_cc',
        categoryCode: 'B',
        project: '酒店',
        note: '周末出行',
        source: TransactionSource.manual,
        tags: const <String>['旅行'],
      ),
    ]);

    _recurringRules.addAll(<RecurringRule>[
      RecurringRule(
        id: _uuid.v4(),
        frequency: RecurringFrequency.monthly,
        anchorDay: 10,
        remindDaysBefore: 3,
        autoCreatePlanned: true,
        accountId: 'acc_cc',
        categoryCode: 'F',
        amount: MoneyAmount(value: 1200, currency: 'CNY'),
        note: '信用卡还款',
      ),
      RecurringRule(
        id: _uuid.v4(),
        frequency: RecurringFrequency.monthly,
        anchorDay: 1,
        remindDaysBefore: 1,
        autoCreatePlanned: false,
        accountId: 'acc_fx',
        categoryCode: 'B',
        amount: MoneyAmount(value: 1800, currency: 'AUD'),
        note: '房租',
      ),
    ]);

    _notifyAccounts();
    _notifyCurrencies();
    _notify();
  }

  List<LedgerTransaction> _sortedTransactions() {
    final List<LedgerTransaction> copy =
        List<LedgerTransaction>.from(_transactions);
    copy.sort(
      (LedgerTransaction a, LedgerTransaction b) => b.date.compareTo(a.date),
    );
    return copy;
  }
}
