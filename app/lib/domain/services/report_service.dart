import '../../data/db.dart';
import '../../data/models.dart';

class ReportService {
  ReportService({required this.database, this.baseCurrency = 'CNY'});

  final LedgerDatabase database;
  final String baseCurrency;

  Future<MonthlyReport> generateMonthlyReport(DateTime month) async {
    final DateTime from = DateTime(month.year, month.month, 1);
    final DateTime to = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    final DateRange range = DateRange(start: from, end: to);

    final Map<String, double> byCategory =
        database.groupByCategory(range: range);
    final Map<String, double> byAccount = database.groupByAccount(range: range);
    final List<LedgerTransaction> transactions =
        (await database.fetchTransactions())
            .where((LedgerTransaction t) => range.contains(t.date))
            .toList();

    final double income =
        transactions.where((LedgerTransaction t) => t.isIncome).fold<double>(
              0,
              (double previous, LedgerTransaction element) =>
                  previous + element.baseAmount.value,
            );
    final double expense =
        transactions.where((LedgerTransaction t) => t.isExpense).fold<double>(
              0,
              (double previous, LedgerTransaction element) =>
                  previous + element.baseAmount.value,
            );

    return MonthlyReport(
      month: month,
      baseCurrency: baseCurrency,
      income: income,
      expense: expense,
      balance: income - expense,
      categoryBreakdown: byCategory,
      accountBreakdown: byAccount,
      transactions: transactions,
    );
  }

  Future<TaxReport> exportTaxReport(DateTime start, DateTime end) async {
    final DateRange range = DateRange(start: start, end: end);
    final List<LedgerTransaction> transactions =
        (await database.fetchTransactions())
            .where((LedgerTransaction t) => range.contains(t.date))
            .toList();

    final double taxableIncome =
        transactions.where((LedgerTransaction t) => t.isIncome).fold<double>(
              0,
              (double previous, LedgerTransaction element) =>
                  previous + element.baseAmount.value,
            );

    final double deductibleExpense =
        transactions.where((LedgerTransaction t) => t.isExpense).fold<double>(
              0,
              (double previous, LedgerTransaction element) =>
                  previous + element.baseAmount.value,
            );

    return TaxReport(
      range: range,
      transactions: transactions,
      taxableIncome: taxableIncome,
      deductibleExpense: deductibleExpense,
      baseCurrency: baseCurrency,
    );
  }
}

class MonthlyReport {
  MonthlyReport({
    required this.month,
    required this.baseCurrency,
    required this.income,
    required this.expense,
    required this.balance,
    required this.categoryBreakdown,
    required this.accountBreakdown,
    required this.transactions,
  });

  final DateTime month;
  final String baseCurrency;
  final double income;
  final double expense;
  final double balance;
  final Map<String, double> categoryBreakdown;
  final Map<String, double> accountBreakdown;
  final List<LedgerTransaction> transactions;
}

class TaxReport {
  TaxReport({
    required this.range,
    required this.transactions,
    required this.taxableIncome,
    required this.deductibleExpense,
    required this.baseCurrency,
  });

  final DateRange range;
  final List<LedgerTransaction> transactions;
  final double taxableIncome;
  final double deductibleExpense;
  final String baseCurrency;
}
