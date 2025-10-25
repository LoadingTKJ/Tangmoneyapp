import '../../data/db.dart';
import '../../data/models.dart';

class RecurringService {
  RecurringService({required this.database});

  final LedgerDatabase database;

  List<RecurringInstance> upcomingInstances({int days = 90}) {
    final DateTime now = DateTime.now();
    final DateTime end = now.add(Duration(days: days));
    final List<RecurringInstance> instances = <RecurringInstance>[];

    for (final RecurringRule rule in database.recurringRules) {
      if (!rule.active) {
        continue;
      }
      DateTime cursor = _nextOccurrence(rule, now);
      while (!cursor.isAfter(end)) {
        final DateTime remindAt =
            cursor.subtract(Duration(days: rule.remindDaysBefore));
        instances.add(
          RecurringInstance(
            rule: rule,
            dueDate: cursor,
            remindAt: remindAt.isBefore(now) ? now : remindAt,
          ),
        );
        cursor = _nextOccurrence(rule, cursor.add(const Duration(days: 1)));
      }
    }

    instances.sort(
      (RecurringInstance a, RecurringInstance b) =>
          a.dueDate.compareTo(b.dueDate),
    );
    return instances;
  }

  List<RecurringInstance> remindersDue(DateTime reference) {
    final List<RecurringInstance> instances = upcomingInstances(days: 7);
    return instances
        .where(
          (RecurringInstance instance) => !instance.remindAt.isAfter(reference),
        )
        .toList();
  }

  DateTime _nextOccurrence(RecurringRule rule, DateTime from) {
    DateTime tentative;
    final DateTime base =
        DateTime(from.year, from.month, rule.anchorDay.clamp(1, 28));

    if (rule.frequency == RecurringFrequency.weekly ||
        rule.frequency == RecurringFrequency.biweekly) {
      tentative = base;
      while (!tentative.isAfter(from)) {
        final int increment =
            rule.frequency == RecurringFrequency.weekly ? 7 : 14;
        tentative = tentative.add(Duration(days: increment));
      }
      return tentative;
    }

    int monthsToAdd = 0;
    switch (rule.frequency) {
      case RecurringFrequency.monthly:
        monthsToAdd = 1;
        break;
      case RecurringFrequency.quarterly:
        monthsToAdd = 3;
        break;
      case RecurringFrequency.yearly:
        monthsToAdd = 12;
        break;
      default:
        monthsToAdd = 1;
    }

    tentative = DateTime(from.year, from.month, rule.anchorDay.clamp(1, 28));
    if (!tentative.isAfter(from)) {
      int year = tentative.year;
      int month = tentative.month + monthsToAdd;
      while (!tentative.isAfter(from)) {
        while (month > 12) {
          month -= 12;
          year += 1;
        }
        tentative = DateTime(year, month, rule.anchorDay.clamp(1, 28));
        month += monthsToAdd;
      }
    }
    return tentative;
  }
}

class RecurringInstance {
  RecurringInstance({
    required this.rule,
    required this.dueDate,
    required this.remindAt,
  });

  final RecurringRule rule;
  final DateTime dueDate;
  final DateTime remindAt;
}
