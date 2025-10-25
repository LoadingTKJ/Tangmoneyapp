import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/recurring_service.dart';
import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';
import '../../utils/formatters.dart';

class CalendarBillingScreen extends ConsumerWidget {
  const CalendarBillingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final RecurringService service = ref.watch(recurringServiceProvider);
    final List<RecurringInstance> upcoming =
        service.upcomingInstances(days: 60);
    final ThemeData theme = Theme.of(context);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(l10n.text('calendarTitle')),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.text('recurringUpcoming'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: upcoming.isEmpty
                    ? DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.2),
                        ),
                        child: Center(
                          child: Text(
                            l10n.text('recurringEmpty'),
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: upcoming.length,
                        itemBuilder: (BuildContext context, int index) {
                          final RecurringInstance instance = upcoming[index];
                          return _RecurringTile(instance: instance);
                        },
                      ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('敬请期待：周期账单创建向导')),
                  );
                },
                icon: const Icon(Icons.add_alert),
                label: Text(l10n.text('createRecurring')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecurringTile extends StatelessWidget {
  const _RecurringTile({required this.instance});

  final RecurringInstance instance;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withValues(alpha: 0.85),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.repeat, color: theme.colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  instance.rule.note.isEmpty
                      ? instance.rule.categoryCode
                      : instance.rule.note,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '下次: ${formatDate(instance.dueDate)}  ·  提醒: ${formatDate(instance.remindAt)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            formatCurrency(
              instance.rule.amount.value,
              instance.rule.amount.currency,
            ),
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
