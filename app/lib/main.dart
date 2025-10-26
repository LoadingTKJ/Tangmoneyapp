import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'l10n/app_localizations.dart';
import 'state/providers.dart';
import 'theme/app_theme.dart';
import 'ui/screens/add_transaction.dart';
import 'ui/screens/analytics.dart';
import 'ui/screens/calendar_billing.dart';
import 'ui/screens/details.dart';
import 'ui/screens/home_dashboard.dart';
import 'ui/screens/import_excel.dart';
import 'ui/screens/rates.dart';
import 'ui/screens/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox<String>('rate_latest');
  await Hive.openBox<String>('rate_series');
  runApp(const ProviderScope(child: TangLedgerApp()));
}

class TangLedgerApp extends ConsumerWidget {
  const TangLedgerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Locale locale = ref.watch(localeProvider);
    final String appTitle = ref.watch(appTitleProvider);

    return MaterialApp(
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      title: appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  final List<Widget> _screens = const <Widget>[
    HomeDashboardScreen(),
    DetailsScreen(),
    CalendarBillingScreen(),
    RatesScreen(),
    AnalyticsScreen(),
    SettingsScreen(),
  ];

  void _onTap(int value) {
    setState(() {
      _index = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: _onTap,
        type: BottomNavigationBarType.fixed,
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: const Icon(Icons.book),
            label: l10n.text('tabLedger'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.view_list),
            label: l10n.text('tabDetails'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.calendar_today),
            label: l10n.text('tabCalendar'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.currency_exchange),
            label: l10n.text('tabRates'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.insert_chart_outlined),
            label: l10n.text('tabAnalytics'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: l10n.text('tabSettings'),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const AddTransactionScreen(),
          ),
        ),
        icon: const Icon(Icons.add),
        label: Text(l10n.text('actionAddEntry')),
      ),
    );
  }
}

class ImportShortcutButton extends StatelessWidget {
  const ImportShortcutButton({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return FilledButton.icon(
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const ImportExcelScreen(),
        ),
      ),
      icon: const Icon(Icons.upload_file),
      label: Text(l10n.text('importExcel')),
    );
  }
}
