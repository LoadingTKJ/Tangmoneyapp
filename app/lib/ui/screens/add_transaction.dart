import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../domain/services/ledger_service.dart';
import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';
import '../../utils/formatters.dart';
import '../widgets/amount_input.dart';
import '../widgets/category_chip.dart';
import '../widgets/currency_picker.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _projectController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  DateTime _date = DateTime.now();
  String _direction = 'expense';
  String _currency = 'CNY';
  bool _currencyUserOverride = false;
  String? _category;
  String? _accountId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _dateController.text = formatDate(_date);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _projectController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final LedgerService service = ref.read(ledgerServiceProvider);
    final String? accountId = _accountId;
    final String categoryCode =
        _category ?? ref.read(categoryMapProvider).keys.first;
    final double? amount =
        double.tryParse(_amountController.text.replaceAll(',', ''));
    if (accountId == null || amount == null || amount <= 0) {
      return;
    }

    final String project =
        _projectController.text.isEmpty ? '未命名项目' : _projectController.text;
    final String baseCurrency = ref.read(selectedBaseCurrencyProvider);
    setState(() => _isSaving = true);
    try {
      await service.addTransaction(
        date: _date,
        type: _direction == 'expense'
            ? TransactionType.expense
            : TransactionType.income,
        amount: amount,
        currency: _currency,
        accountId: accountId,
        categoryCode: categoryCode,
        project: project,
        note: _noteController.text,
        baseCurrency: baseCurrency,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).text('saved'))),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<Account> accounts = ref.watch(accountListProvider);
    final List<Category> categoryList = ref.watch(categoryListProvider);
    final String baseCurrency = ref.watch(selectedBaseCurrencyProvider);
    final List<String> currencyOptions = ref.watch(currencyOptionsProvider);
    final List<String> resolvedCurrencies = currencyOptions.isNotEmpty
        ? List<String>.from(currencyOptions)
        : <String>[baseCurrency];
    if (!resolvedCurrencies.contains(baseCurrency)) {
      resolvedCurrencies.add(baseCurrency);
    }
    Account? selectedAccount;
    if (accounts.isNotEmpty) {
      selectedAccount = accounts.firstWhere(
        (Account account) => account.id == _accountId,
        orElse: () => accounts.first,
      );
      _accountId = selectedAccount.id;
      if (!_currencyUserOverride) {
        _currency = selectedAccount.currency;
      }
    }
    if (_currency.isEmpty) {
      _currency = baseCurrency;
    }
    if (!resolvedCurrencies.contains(_currency)) {
      resolvedCurrencies.add(_currency);
    }
    if (_accountId == null && accounts.isNotEmpty) {
      _accountId = accounts.first.id;
    }
    final Map<String, Category> categories = ref.watch(categoryMapProvider);
    if (_category == null && categoryList.isNotEmpty) {
      _category = categoryList.first.code;
    } else if (_category != null &&
        categories[_category!] == null &&
        categoryList.isNotEmpty) {
      _category = categoryList.first.code;
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            Color(0xFF6366F1),
            Color(0xFF8B5CF6),
            Color(0xFF3B82F6)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(l10n.text('addTransaction')),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(28),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.text('addTransaction'),
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<String>(
                      segments: <ButtonSegment<String>>[
                        ButtonSegment<String>(
                          value: 'expense',
                          label: Text(l10n.text('expense')),
                          icon: const Icon(Icons.trending_down),
                        ),
                        ButtonSegment<String>(
                          value: 'income',
                          label: Text(l10n.text('income')),
                          icon: const Icon(Icons.trending_up),
                        ),
                      ],
                      selected: {_direction},
                      onSelectionChanged: (value) {
                        setState(() => _direction = value.first);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: l10n.text('date'),
                        suffixIcon: const Icon(Icons.calendar_today),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      controller: _dateController,
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() {
                            _date = picked;
                            _dateController.text = formatDate(picked);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      key: ValueKey<String?>(_accountId),
                      initialValue: _accountId,
                      decoration: InputDecoration(
                        labelText: l10n.text('account'),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      items: accounts
                          .map(
                            (Account account) => DropdownMenuItem<String>(
                              value: account.id,
                              child:
                                  Text('${account.name} (${account.currency})'),
                            ),
                          )
                          .toList(),
                      onChanged: (String? value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _accountId = value;
                          if (!_currencyUserOverride) {
                            final Account account = accounts.firstWhere(
                              (Account element) => element.id == value,
                              orElse: () => accounts.first,
                            );
                            _currency = account.currency;
                          }
                        });
                      },
                      validator: (String? value) =>
                          value == null ? '请选择账户' : null,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final Category category in categoryList)
                          CategoryChip(
                            code: category.code,
                            label: category.name,
                            selected: category.code == _category,
                            onTap: () =>
                                setState(() => _category = category.code),
                          ),
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 18),
                          label: const Text('新增类别'),
                          onPressed: _showAddCategoryDialog,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _projectController,
                      decoration: InputDecoration(
                        labelText: l10n.text('project'),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AmountInput(
                      controller: _amountController,
                      label: l10n.text('amount'),
                      onChanged: (_) => _formKey.currentState?.validate(),
                      validator: (String? value) {
                        final double? amount =
                            double.tryParse((value ?? '').replaceAll(',', ''));
                        if (amount == null || amount <= 0) {
                          return '请输入有效金额';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    CurrencyPicker(
                      initialValue: _currency,
                      currencies: resolvedCurrencies,
                      onChanged: (String? value) {
                        if (value != null) {
                          setState(() {
                            _currency = value;
                            _currencyUserOverride = true;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _noteController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: l10n.text('note'),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(l10n.text('save')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAddCategoryDialog() async {
    final TextEditingController controller = TextEditingController();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('新增类别'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: '类别名称',
              hintText: '例如：健身、宠物开销',
            ),
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
      final String name = controller.text.trim();
      if (name.isEmpty) {
        return;
      }
      try {
        final LedgerService service = ref.read(ledgerServiceProvider);
        final Category category = await service.createCategory(name: name);
        if (!mounted) return;
        setState(() => _category = category.code);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已添加类别：${category.name}')),
        );
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('新增类别失败：$error')),
        );
      }
    }
  }
}
