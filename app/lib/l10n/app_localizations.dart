import 'package:flutter/widgets.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const List<Locale> supportedLocales = <Locale>[
    Locale('zh'),
    Locale('en'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(
          context,
          AppLocalizations,
        ) ??
        AppLocalizations(const Locale('zh'));
  }

  static const Map<String, Map<String, String>> _localizedValues =
      <String, Map<String, String>>{
    'zh': <String, String>{
      'appTitle': '小唐账本',
      'tabLedger': '账本',
      'tabCalendar': '日历',
      'tabDetails': '明细',
      'tabRates': '汇率',
      'tabAnalytics': '分析',
      'tabSettings': '设置',
      'actionAddEntry': '新增一笔',
      'monthlyBill': '本月账单',
      'income': '收入',
      'expense': '支出',
      'analysis': '消费分析',
      'emptyTransactions': '暂无交易，点击右下角新增一笔吧！',
      'addTransaction': '新增记账',
      'account': '账户',
      'category': '类别',
      'project': '项目',
      'amount': '金额',
      'currency': '币种',
      'note': '备注',
      'save': '保存',
      'saved': '已保存到账本',
      'date': '日期',
      'calendarTitle': '账单日历',
      'createRecurring': '新建周期账单',
      'analysisTitle': '消费分析',
      'timeRange': '时间区间',
      'currentMonth': '本月',
      'settingsTitle': '设置',
      'baseCurrency': '基准币',
      'language': '多语言',
      'cloudSync': '云盘同步',
      'security': '安全',
      'importExcel': '导入 Excel',
      'startImport': '开始导入',
      'preview': '预览与去重',
      'importReport': '导入报告',
      'chooseFile': '选择文件',
      'columnMapping': '列映射',
      'recurringEmpty': '暂无周期账单，点击下方按钮创建。',
      'noData': '暂无数据',
      'trendChart': '净流趋势',
      'noTrendData': '暂无趋势数据',
      'accountDistribution': '账户分布',
      'noAccountData': '暂无账户数据',
      'recurringUpcoming': '周期提醒',
    },
    'en': <String, String>{
      'appTitle': 'Tang Ledger',
      'tabLedger': 'Ledger',
      'tabCalendar': 'Calendar',
      'tabDetails': 'Details',
      'tabRates': 'Rates',
      'tabAnalytics': 'Analytics',
      'tabSettings': 'Settings',
      'actionAddEntry': 'Add Entry',
      'monthlyBill': 'This Month',
      'income': 'Income',
      'expense': 'Expense',
      'analysis': 'Spending Insight',
      'emptyTransactions':
          'No transactions yet. Tap the button below to add one.',
      'addTransaction': 'Add Transaction',
      'account': 'Account',
      'category': 'Category',
      'project': 'Project',
      'amount': 'Amount',
      'currency': 'Currency',
      'note': 'Note',
      'save': 'Save',
      'saved': 'Saved to ledger',
      'date': 'Date',
      'calendarTitle': 'Billing Calendar',
      'createRecurring': 'New Recurring',
      'analysisTitle': 'Analytics',
      'timeRange': 'Period',
      'currentMonth': 'Current Month',
      'settingsTitle': 'Settings',
      'baseCurrency': 'Base Currency',
      'language': 'Languages',
      'cloudSync': 'Cloud Sync',
      'security': 'Security',
      'importExcel': 'Import Excel',
      'startImport': 'Start Import',
      'preview': 'Preview & Deduplicate',
      'importReport': 'Import Report',
      'chooseFile': 'Select File',
      'columnMapping': 'Column Mapping',
      'recurringEmpty': 'No recurring bills yet. Tap below to add one.',
      'noData': 'No data yet',
      'trendChart': 'Net Flow Trend',
      'noTrendData': 'No trend data yet',
      'accountDistribution': 'Account Distribution',
      'noAccountData': 'No account data yet',
      'recurringUpcoming': 'Upcoming Recurring Bills',
    },
  };

  String text(String key) {
    final Map<String, String> bundle =
        _localizedValues[locale.languageCode] ?? _localizedValues['zh']!;
    return bundle[key] ?? key;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales.any(
        (Locale supported) => supported.languageCode == locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}
