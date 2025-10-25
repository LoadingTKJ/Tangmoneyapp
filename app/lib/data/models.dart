import 'dart:convert';

enum TransactionType { expense, income, transfer, refund, planned }

enum TransactionSource { manual, excel, ocr, connector }

enum AccountType { cash, bank, credit, investment, wallet, virtual }

class MoneyAmount {
  MoneyAmount({
    required this.value,
    required this.currency,
  });

  final double value;
  final String currency;

  MoneyAmount copyWith({
    double? value,
    String? currency,
  }) {
    return MoneyAmount(
      value: value ?? this.value,
      currency: currency ?? this.currency,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'value': value,
        'currency': currency,
      };

  factory MoneyAmount.fromJson(Map<String, dynamic> json) {
    return MoneyAmount(
      value: (json['value'] as num).toDouble(),
      currency: json['currency'] as String,
    );
  }
}

class Account {
  Account({
    required this.id,
    required this.name,
    required this.type,
    required this.currency,
    this.balance = 0,
    this.includeInNetWorth = true,
    this.billDay,
    this.repayDay,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String name;
  final AccountType type;
  final String currency;
  final double balance;
  final bool includeInNetWorth;
  final int? billDay;
  final int? repayDay;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'type': type.name,
        'currency': currency,
        'balance': balance,
        'includeInNetWorth': includeInNetWorth,
        'billDay': billDay,
        'repayDay': repayDay,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as String,
      name: json['name'] as String,
      type: AccountType.values.firstWhere(
        (value) => value.name == json['type'],
        orElse: () => AccountType.cash,
      ),
      currency: json['currency'] as String,
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      includeInNetWorth: json['includeInNetWorth'] as bool? ?? true,
      billDay: json['billDay'] as int?,
      repayDay: json['repayDay'] as int?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Account copyWith({
    String? id,
    String? name,
    AccountType? type,
    String? currency,
    double? balance,
    bool? includeInNetWorth,
    int? billDay,
    int? repayDay,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      currency: currency ?? this.currency,
      balance: balance ?? this.balance,
      includeInNetWorth: includeInNetWorth ?? this.includeInNetWorth,
      billDay: billDay ?? this.billDay,
      repayDay: repayDay ?? this.repayDay,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class Category {
  Category({
    required this.code,
    required this.name,
  });

  final String code;
  final String name;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'code': code,
        'name': name,
      };

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      code: json['code'] as String,
      name: json['name'] as String,
    );
  }
}

class LedgerTransaction {
  LedgerTransaction({
    required this.id,
    required this.date,
    required this.type,
    required this.originalAmount,
    required this.accountId,
    required this.categoryCode,
    required this.project,
    required this.note,
    required this.source,
    this.counterAccountId,
    this.tags = const [],
    this.rateUsed,
    MoneyAmount? baseAmount,
    this.baseCurrency = 'CNY',
    this.confidence,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : baseAmount =
            baseAmount ?? originalAmount.copyWith(currency: baseCurrency),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final DateTime date;
  final TransactionType type;
  final MoneyAmount originalAmount;
  final double? rateUsed;
  final MoneyAmount baseAmount;
  final String baseCurrency;
  final String accountId;
  final String? counterAccountId;
  final String categoryCode;
  final String project;
  final String note;
  final TransactionSource source;
  final double? confidence;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isExpense => type == TransactionType.expense;
  bool get isIncome => type == TransactionType.income;

  LedgerTransaction copyWith({
    String? id,
    DateTime? date,
    TransactionType? type,
    MoneyAmount? originalAmount,
    double? rateUsed,
    MoneyAmount? baseAmount,
    String? baseCurrency,
    String? accountId,
    String? counterAccountId,
    String? categoryCode,
    String? project,
    String? note,
    TransactionSource? source,
    double? confidence,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LedgerTransaction(
      id: id ?? this.id,
      date: date ?? this.date,
      type: type ?? this.type,
      originalAmount: originalAmount ?? this.originalAmount,
      rateUsed: rateUsed ?? this.rateUsed,
      baseAmount: baseAmount ?? this.baseAmount,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      accountId: accountId ?? this.accountId,
      counterAccountId: counterAccountId ?? this.counterAccountId,
      categoryCode: categoryCode ?? this.categoryCode,
      project: project ?? this.project,
      note: note ?? this.note,
      source: source ?? this.source,
      confidence: confidence ?? this.confidence,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'date': date.toIso8601String(),
        'type': type.name,
        'originalAmount': originalAmount.toJson(),
        'rateUsed': rateUsed,
        'baseAmount': baseAmount.toJson(),
        'baseCurrency': baseCurrency,
        'accountId': accountId,
        'counterAccountId': counterAccountId,
        'categoryCode': categoryCode,
        'project': project,
        'note': note,
        'source': source.name,
        'confidence': confidence,
        'tags': tags,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory LedgerTransaction.fromJson(Map<String, dynamic> json) {
    return LedgerTransaction(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      type: TransactionType.values.firstWhere(
        (value) => value.name == json['type'],
        orElse: () => TransactionType.expense,
      ),
      originalAmount:
          MoneyAmount.fromJson(json['originalAmount'] as Map<String, dynamic>),
      rateUsed: (json['rateUsed'] as num?)?.toDouble(),
      baseAmount:
          MoneyAmount.fromJson(json['baseAmount'] as Map<String, dynamic>),
      baseCurrency: json['baseCurrency'] as String? ?? 'CNY',
      accountId: json['accountId'] as String,
      counterAccountId: json['counterAccountId'] as String?,
      categoryCode: json['categoryCode'] as String,
      project: json['project'] as String,
      note: json['note'] as String,
      source: TransactionSource.values.firstWhere(
        (value) => value.name == json['source'],
        orElse: () => TransactionSource.manual,
      ),
      confidence: (json['confidence'] as num?)?.toDouble(),
      tags: (json['tags'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic e) => e.toString())
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class RecurringRule {
  RecurringRule({
    required this.id,
    required this.frequency,
    required this.anchorDay,
    required this.remindDaysBefore,
    required this.autoCreatePlanned,
    required this.accountId,
    required this.categoryCode,
    required this.amount,
    this.note = '',
    this.active = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final RecurringFrequency frequency;
  final int anchorDay;
  final int remindDaysBefore;
  final bool autoCreatePlanned;
  final String accountId;
  final String categoryCode;
  final MoneyAmount amount;
  final String note;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'frequency': frequency.name,
        'anchorDay': anchorDay,
        'remindDaysBefore': remindDaysBefore,
        'autoCreatePlanned': autoCreatePlanned,
        'accountId': accountId,
        'categoryCode': categoryCode,
        'amount': amount.toJson(),
        'note': note,
        'active': active,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory RecurringRule.fromJson(Map<String, dynamic> json) {
    return RecurringRule(
      id: json['id'] as String,
      frequency: RecurringFrequency.values.firstWhere(
        (value) => value.name == json['frequency'],
        orElse: () => RecurringFrequency.monthly,
      ),
      anchorDay: json['anchorDay'] as int,
      remindDaysBefore: json['remindDaysBefore'] as int,
      autoCreatePlanned: json['autoCreatePlanned'] as bool? ?? false,
      accountId: json['accountId'] as String,
      categoryCode: json['categoryCode'] as String,
      amount: MoneyAmount.fromJson(json['amount'] as Map<String, dynamic>),
      note: json['note'] as String? ?? '',
      active: json['active'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

enum RecurringFrequency { weekly, biweekly, monthly, quarterly, yearly }

class RateQuote {
  RateQuote({
    required this.date,
    required this.fromCurrency,
    required this.toCurrency,
    required this.rate,
    required this.provider,
    DateTime? fetchedAt,
  }) : fetchedAt = fetchedAt ?? DateTime.now();

  final DateTime date;
  final String fromCurrency;
  final String toCurrency;
  final double rate;
  final String provider;
  final DateTime fetchedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'date': date.toIso8601String(),
        'fromCurrency': fromCurrency,
        'toCurrency': toCurrency,
        'rate': rate,
        'provider': provider,
        'fetchedAt': fetchedAt.toIso8601String(),
      };

  factory RateQuote.fromJson(Map<String, dynamic> json) {
    return RateQuote(
      date: DateTime.parse(json['date'] as String),
      fromCurrency: json['fromCurrency'] as String,
      toCurrency: json['toCurrency'] as String,
      rate: (json['rate'] as num).toDouble(),
      provider: json['provider'] as String,
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
    );
  }
}

class RateSeriesPoint {
  RateSeriesPoint({required this.date, required this.rate});

  final DateTime date;
  final double rate;
}

class DetailsFilter {
  DetailsFilter(
      {required this.range,
      this.categoryCode,
      this.sort = DetailsSort.dateDesc});

  final DateRange range;
  final String? categoryCode;
  final DetailsSort sort;

  DetailsFilter copyWith(
      {DateRange? range, String? categoryCode, DetailsSort? sort}) {
    return DetailsFilter(
      range: range ?? this.range,
      categoryCode: categoryCode ?? this.categoryCode,
      sort: sort ?? this.sort,
    );
  }

  static DetailsFilter initial() {
    final DateTime now = DateTime.now();
    final DateRange range = DateRange(
      start: DateTime(now.year, now.month, now.day),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
    return DetailsFilter(range: range);
  }
}

enum DetailsSort { dateDesc, dateAsc, amountDesc, amountAsc }

class LedgerExport {
  LedgerExport({
    required this.accounts,
    required this.categories,
    required this.transactions,
    required this.recurringRules,
  });

  final List<Account> accounts;
  final List<Category> categories;
  final List<LedgerTransaction> transactions;
  final List<RecurringRule> recurringRules;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'accounts': accounts.map((Account e) => e.toJson()).toList(),
        'categories': categories.map((Category e) => e.toJson()).toList(),
        'transactions':
            transactions.map((LedgerTransaction e) => e.toJson()).toList(),
        'recurringRules':
            recurringRules.map((RecurringRule e) => e.toJson()).toList(),
      };

  String encode() => jsonEncode(toJson());

  factory LedgerExport.fromJson(Map<String, dynamic> json) {
    return LedgerExport(
      accounts: (json['accounts'] as List<dynamic>)
          .map((dynamic e) => Account.fromJson(e as Map<String, dynamic>))
          .toList(),
      categories: (json['categories'] as List<dynamic>)
          .map((dynamic e) => Category.fromJson(e as Map<String, dynamic>))
          .toList(),
      transactions: (json['transactions'] as List<dynamic>)
          .map(
            (dynamic e) =>
                LedgerTransaction.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      recurringRules: (json['recurringRules'] as List<dynamic>)
          .map(
            (dynamic e) => RecurringRule.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class DateRange {
  DateRange({
    required this.start,
    required this.end,
  }) : assert(!end.isBefore(start), '结束时间不能早于开始时间');

  final DateTime start;
  final DateTime end;

  bool contains(DateTime date) {
    return (date.isAfter(start) || date.isAtSameMomentAs(start)) &&
        (date.isBefore(end) || date.isAtSameMomentAs(end));
  }
}

class ChartSegment {
  ChartSegment({required this.label, required this.value});

  final String label;
  final double value;
}

enum AnalyticsRangePreset { thisWeek, thisMonth, thisQuarter, custom }

class DailyFlowPoint {
  DailyFlowPoint({
    required this.date,
    required this.income,
    required this.expense,
  });

  final DateTime date;
  final double income;
  final double expense;
}

class WealthPoint {
  WealthPoint({
    required this.date,
    required this.total,
  });

  final DateTime date;
  final double total;
}

class AnalyticsSnapshot {
  AnalyticsSnapshot({
    required this.range,
    required this.dailyFlows,
    required this.wealthTrend,
    required this.incomeSegments,
    required this.expenseSegments,
    required this.currency,
  });

  final DateRange range;
  final List<DailyFlowPoint> dailyFlows;
  final List<WealthPoint> wealthTrend;
  final List<ChartSegment> incomeSegments;
  final List<ChartSegment> expenseSegments;
  final String currency;
}
