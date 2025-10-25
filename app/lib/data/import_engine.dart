import 'dart:io';

import 'package:excel/excel.dart';

class ImportPreview {
  ImportPreview({
    required this.entries,
    required this.duplicates,
    required this.unknownCategories,
  });

  final List<ImportEntry> entries;
  final List<ImportEntry> duplicates;
  final Set<String> unknownCategories;

  bool get hasDuplication => duplicates.isNotEmpty;
  bool get hasUnknownCategory => unknownCategories.isNotEmpty;
}

class ImportEntry {
  ImportEntry({
    required this.date,
    required this.categoryCode,
    required this.project,
    required this.amount,
    required this.currency,
    required this.isExpense,
    required this.note,
  });

  final DateTime date;
  final String categoryCode;
  final String project;
  final double amount;
  final String currency;
  final bool isExpense;
  final String note;

  double get signedAmount => isExpense ? -amount : amount;

  Map<String, Object?> toJson() => <String, Object?>{
        'date': date.toIso8601String(),
        'categoryCode': categoryCode,
        'project': project,
        'amount': amount,
        'currency': currency,
        'isExpense': isExpense,
        'note': note,
      };
}

class ImportEngine {
  Future<ImportPreview> parse(String filePath) async {
    final File file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('导入文件不存在', filePath);
    }

    final List<int> bytes = await file.readAsBytes();
    final Excel excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      return ImportPreview(
        entries: const <ImportEntry>[],
        duplicates: const <ImportEntry>[],
        unknownCategories: <String>{},
      );
    }

    final String tableName = excel.tables.keys.first;
    final Sheet sheet = excel.tables[tableName]!;

    if (sheet.rows.isEmpty) {
      return ImportPreview(
        entries: const <ImportEntry>[],
        duplicates: const <ImportEntry>[],
        unknownCategories: <String>{},
      );
    }

    final List<Data?> header = sheet.rows.first;
    final _HeaderIndexes headerIndexes = _parseHeader(header);

    final List<ImportEntry> entries = <ImportEntry>[];
    final List<ImportEntry> duplicates = <ImportEntry>[];
    final Set<String> unknownCategories = <String>{};
    final Set<String> dedupeSet = <String>{};

    for (int rowIndex = 1; rowIndex < sheet.rows.length; rowIndex++) {
      final List<Data?> row = sheet.rows[rowIndex];
      final DateTime? date = _parseDate(row, headerIndexes.dateIndex);
      if (date == null) {
        continue;
      }
      final String categoryCode =
          _readCell(row, headerIndexes.categoryIndex)?.trim().toUpperCase() ??
              '';
      if (categoryCode.isEmpty) {
        unknownCategories.add('未填写');
      }
      final String project =
          _readCell(row, headerIndexes.projectIndex) ?? '未命名项目';
      final String note = _readCell(row, headerIndexes.noteIndex) ?? '';

      for (final _CurrencyColumn column in headerIndexes.currencyColumns) {
        final double? value = _parseDouble(row, column.index);
        if (value == null || value == 0) {
          continue;
        }
        final ImportEntry entry = ImportEntry(
          date: date,
          categoryCode: categoryCode,
          project: project,
          amount: value.abs(),
          currency: column.currency,
          isExpense: column.kind == _CurrencyKind.expense,
          note: note,
        );
        final String dedupeKey =
            '${entry.date.toIso8601String()}|${entry.currency}|${entry.amount}|${entry.project}';
        if (!dedupeSet.add(dedupeKey)) {
          duplicates.add(entry);
        } else {
          entries.add(entry);
        }
        if (categoryCode.isEmpty) {
          unknownCategories.add(categoryCode);
        }
      }
    }

    return ImportPreview(
      entries: entries,
      duplicates: duplicates,
      unknownCategories: unknownCategories
        ..removeWhere((String element) => element.isEmpty),
    );
  }

  _HeaderIndexes _parseHeader(List<Data?> header) {
    final int dateIndex = header.indexWhere(
      (Data? cell) => (cell?.value ?? '').toString().contains('日期'),
    );
    final int categoryIndex = header.indexWhere(
      (Data? cell) => (cell?.value ?? '').toString().contains('类别'),
    );
    final int projectIndex = header.indexWhere(
      (Data? cell) => (cell?.value ?? '').toString().contains('项目'),
    );
    final int noteIndex = header.indexWhere(
      (Data? cell) => (cell?.value ?? '').toString().contains('备注'),
    );

    final List<_CurrencyColumn> currencyColumns = <_CurrencyColumn>[];
    for (int i = 0; i < header.length; i++) {
      final String title = (header[i]?.value ?? '').toString();
      if (title.contains('收入(') || title.contains('支出(')) {
        final _CurrencyKind kind =
            title.contains('收入') ? _CurrencyKind.income : _CurrencyKind.expense;
        final int start = title.indexOf('(');
        final int end = title.indexOf(')');
        final String currency = start != -1 && end != -1 && end > start
            ? title.substring(start + 1, end).trim().toUpperCase()
            : 'CNY';
        currencyColumns.add(
          _CurrencyColumn(index: i, currency: currency, kind: kind),
        );
      }
    }

    return _HeaderIndexes(
      dateIndex: dateIndex,
      categoryIndex: categoryIndex,
      projectIndex: projectIndex,
      noteIndex: noteIndex,
      currencyColumns: currencyColumns,
    );
  }

  DateTime? _parseDate(List<Data?> row, int index) {
    if (index < 0 || index >= row.length) {
      return null;
    }
    final Data? cell = row[index];
    if (cell == null || cell.value == null) {
      return null;
    }
    final Object? value = cell.value;
    if (value is DateTime) {
      return value;
    }
    final String text = value.toString().trim();
    if (text.isEmpty) {
      return null;
    }
    try {
      return DateTime.parse(text);
    } on FormatException {
      final double? numeric = double.tryParse(text);
      if (numeric != null) {
        return DateTime.fromMillisecondsSinceEpoch(
          DateTime(1899, 12, 30)
              .add(Duration(milliseconds: (numeric * 86400000).round()))
              .millisecondsSinceEpoch,
        );
      }
    }
    return null;
  }

  String? _readCell(List<Data?> row, int index) {
    if (index < 0 || index >= row.length) {
      return null;
    }
    final Data? cell = row[index];
    return cell?.value?.toString();
  }

  double? _parseDouble(List<Data?> row, int index) {
    final String? raw = _readCell(row, index);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return double.tryParse(raw.replaceAll(',', ''));
  }
}

class _HeaderIndexes {
  _HeaderIndexes({
    required this.dateIndex,
    required this.categoryIndex,
    required this.projectIndex,
    required this.noteIndex,
    required this.currencyColumns,
  });

  final int dateIndex;
  final int categoryIndex;
  final int projectIndex;
  final int noteIndex;
  final List<_CurrencyColumn> currencyColumns;
}

class _CurrencyColumn {
  _CurrencyColumn({
    required this.index,
    required this.currency,
    required this.kind,
  });

  final int index;
  final String currency;
  final _CurrencyKind kind;
}

enum _CurrencyKind { income, expense }
