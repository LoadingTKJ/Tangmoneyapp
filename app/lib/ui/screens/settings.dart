import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, unnecessary_const

import '../../data/models.dart';
import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';
import 'import_excel.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String baseCurrency = ref.watch(selectedBaseCurrencyProvider);
    final Locale locale = ref.watch(localeProvider);
    final List<String> currencies = ref.watch(currencyOptionsProvider);
    final ledgerService = ref.read(ledgerServiceProvider);

    Future<void> updateBaseCurrency(String value) async {
      if (value == baseCurrency) {
        return;
      }
      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(content: Text('正在将基准币切换为 $value ...')),
      );
      await ledgerService.addCurrency(value);
      ref.read(selectedBaseCurrencyProvider.notifier).state = value;
      await ledgerService.rebaseTransactions(value);
      messenger.showSnackBar(
        SnackBar(content: Text('基准币已更新为 $value')),
      );
    }

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
          title: Text(l10n.text('settingsTitle')),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            const _AccountManagementSection(),
            const SizedBox(height: 24),
            const _CurrencyManagementSection(),
            const SizedBox(height: 24),
            _GroupTitle(l10n.text('settingsTitle')),
            Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.currency_exchange),
                  title: Text(l10n.text('baseCurrency')),
                  subtitle: Text(baseCurrency),
                  trailing: DropdownButton<String>(
                    value: baseCurrency,
                    underline: const SizedBox.shrink(),
                    onChanged: (String? value) {
                      if (value != null) {
                        updateBaseCurrency(value);
                        ref.invalidate(totalAssetsProvider);
                      }
                    },
                    items: currencies
                        .map(
                          (String code) => DropdownMenuItem<String>(
                            value: code,
                            child: Text(code),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(l10n.text('language')),
                  subtitle:
                      Text(locale.languageCode == 'zh' ? '中文' : 'English'),
                  trailing: SegmentedButton<String>(
                    segments: const <ButtonSegment<String>>[
                      ButtonSegment<String>(value: 'zh', label: Text('中文')),
                      ButtonSegment<String>(
                          value: 'en', label: Text('English')),
                    ],
                    selected: <String>{locale.languageCode},
                    onSelectionChanged: (Set<String> value) {
                      if (value.isNotEmpty) {
                        ref.read(localeProvider.notifier).state =
                            Locale(value.first);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _GroupTitle(l10n.text('cloudSync')),
          Card(
            child: Column(
              children: const <Widget>[
                const SwitchListTile(
                  value: false,
                  onChanged: null,
                  title: Text('启用 Google Drive'),
                  subtitle: Text('上传/下载加密后的账本文件'),
                ),
                Divider(height: 1),
                const SwitchListTile(
                  value: false,
                  onChanged: null,
                  title: Text('启用 OneDrive'),
                  subtitle: Text('上传/下载加密后的账本文件'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.cloud_upload),
                  title: Text('手动上传'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.download),
                  title: Text('手动下载'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _GroupTitle(l10n.text('security')),
          Card(
            child: Column(
              children: const <Widget>[
                const ListTile(
                  leading: Icon(Icons.lock),
                  title: Text('主密码'),
                  subtitle: Text('已开启'),
                  trailing: Icon(Icons.chevron_right),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.archive),
                  title: Text('导出加密备份'),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.delete_forever),
                  title: Text(
                    '清除所有数据',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _GroupTitle(l10n.text('importExcel')),
          Card(
            child: ListTile(
              leading: const Icon(Icons.file_upload),
              title: Text(l10n.text('importExcel')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ImportExcelScreen(),
                  ),
                );
              },
            ),
          ),
          ],
        ),
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _AccountManagementSection extends ConsumerWidget {
  const _AccountManagementSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Account> accounts = ref.watch(accountListProvider);
    final List<String> currencies = ref.watch(currencyOptionsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _GroupTitle('账户管理'),
        Card(
          child: Column(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: Text('账户总数：${accounts.length}'),
                trailing: FilledButton.tonalIcon(
                  onPressed: () => _showAddAccountDialog(context, ref, currencies),
                  icon: const Icon(Icons.add),
                  label: const Text('新增账户'),
                ),
              ),
              const Divider(height: 1),
              if (accounts.isEmpty)
                const ListTile(
                  title: Text('还没有账户，点击右上角新增一个吧。'),
                )
              else
                ...accounts.map(
                  (Account account) => Column(
                    children: <Widget>[
                      ListTile(
                        leading: const Icon(Icons.account_circle_outlined),
                        title: Text(account.name),
                        subtitle: Text(
                          '${_accountTypeLabel(account.type)} · ${account.currency}',
                        ),
                        trailing: TextButton.icon(
                          onPressed: () =>
                              _showUpdateBalanceDialog(context, ref, account),
                          icon: const Icon(Icons.edit),
                          label: const Text('调整余额'),
                        ),
                      ),
                      const Divider(height: 1),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showAddAccountDialog(
    BuildContext context,
    WidgetRef ref,
    List<String> currencies,
  ) async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController balanceController = TextEditingController();
    bool includeInNetWorth = true;
    AccountType selectedType = AccountType.cash;
    String selectedCurrency = currencies.isNotEmpty
        ? currencies.first
        : ref.read(selectedBaseCurrencyProvider);

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('新增账户'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: '账户名称'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<AccountType>(
                      key: ValueKey<AccountType>(selectedType),
                      initialValue: selectedType,
                      items: AccountType.values
                          .map(
                            (AccountType type) => DropdownMenuItem<AccountType>(
                              value: type,
                              child: Text(_accountTypeLabel(type)),
                            ),
                          )
                          .toList(),
                      onChanged: (AccountType? value) {
                        if (value != null) {
                          setState(() => selectedType = value);
                        }
                      },
                      decoration: const InputDecoration(labelText: '账户类型'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey<String>(selectedCurrency),
                      initialValue: selectedCurrency,
                      items: (currencies.isNotEmpty
                              ? currencies
                              : <String>[ref.read(selectedBaseCurrencyProvider)])
                          .map(
                            (String code) => DropdownMenuItem<String>(
                              value: code,
                              child: Text(code),
                            ),
                          )
                          .toList(),
                      onChanged: (String? value) {
                        if (value != null) {
                          setState(() => selectedCurrency = value);
                        }
                      },
                      decoration: const InputDecoration(labelText: '币种'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: balanceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: '初始余额'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Switch(
                          value: includeInNetWorth,
                          onChanged: (bool value) {
                            setState(() => includeInNetWorth = value);
                          },
                        ),
                        const SizedBox(width: 8),
                        const Expanded(child: Text('纳入净资产合计')),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) {
                  return;
                }
                Navigator.of(context).pop(true);
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final double balance = double.tryParse(balanceController.text) ?? 0;
      await ref.read(ledgerServiceProvider).createAccount(
            name: nameController.text.trim(),
            type: selectedType,
            currency: selectedCurrency,
            balance: balance,
            includeInNetWorth: includeInNetWorth,
          );
      ref.invalidate(totalAssetsProvider);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已新增账户：${nameController.text.trim()}')),
      );
    }
  }

  Future<void> _showUpdateBalanceDialog(
    BuildContext context,
    WidgetRef ref,
    Account account,
  ) async {
    final TextEditingController controller =
        TextEditingController(text: account.balance.toString());
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('调整余额 - ${account.name}'),
          content: TextField(
            controller: controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '当前余额'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final double newBalance = double.tryParse(controller.text) ?? 0;
      await ref
          .read(ledgerServiceProvider)
          .updateAccountBalance(account.id, newBalance);
      ref.invalidate(totalAssetsProvider);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已更新 ${account.name} 的余额')),
      );
    }
  }
}

class _CurrencyManagementSection extends ConsumerWidget {
  const _CurrencyManagementSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<String> currencies = ref.watch(currencyOptionsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _GroupTitle('货币管理'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    const Text(
                      '已启用的币种',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => _showAddCurrencyDialog(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('新增币种'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (currencies.isEmpty)
                  const Text('暂无自定义币种。')
                else
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: currencies
                        .map(
                          (String code) => Chip(
                            label: Text(code),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showAddCurrencyDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final TextEditingController controller = TextEditingController();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('新增币种'),
          content: TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(hintText: '如：HKD、EUR'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('添加'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final String code = controller.text.trim().toUpperCase();
      if (code.isEmpty) {
        return;
      }
      await ref.read(ledgerServiceProvider).addCurrency(code);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已添加币种：$code')),
      );
    }
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
