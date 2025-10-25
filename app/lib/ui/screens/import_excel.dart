import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/import_engine.dart';
import '../../domain/services/ledger_service.dart';
import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';

class ImportExcelScreen extends ConsumerStatefulWidget {
  const ImportExcelScreen({super.key});

  @override
  ConsumerState<ImportExcelScreen> createState() => _ImportExcelScreenState();
}

class _ImportExcelScreenState extends ConsumerState<ImportExcelScreen> {
  String? _filePath;
  ImportPreview? _preview;
  bool _isParsing = false;
  bool _isImporting = false;

  Future<void> _pickFile() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['xlsx'],
    );
    if (result == null || result.files.isEmpty) {
      return;
    }
    final String? path = result.files.single.path;
    if (path == null) {
      return;
    }
    setState(() {
      _filePath = path;
      _preview = null;
    });
    await _parse(path);
  }

  Future<void> _parse(String path) async {
    setState(() => _isParsing = true);
    final ImportEngine engine = ImportEngine();
    try {
      final ImportPreview preview = await engine.parse(path);
      setState(() => _preview = preview);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('解析失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isParsing = false);
      }
    }
  }

  Future<void> _importEntries() async {
    final ImportPreview? preview = _preview;
    if (preview == null || preview.entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择并解析文件。')),
      );
      return;
    }
    setState(() => _isImporting = true);
    final LedgerService service = ref.read(ledgerServiceProvider);
    try {
      await service.importEntries(preview.entries);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('导入成功，共 ${preview.entries.length} 条。'),
        ),
      );
      setState(() {
        _preview = null;
        _filePath = null;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final ImportPreview? preview = _preview;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.text('importExcel'))),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          _StepCard(
            index: 1,
            title: l10n.text('chooseFile'),
            description: _filePath ?? '支持模板 TangLedger_Import_Spec_v1.xlsx',
            actionLabel: l10n.text('chooseFile'),
            onAction: _isParsing ? null : _pickFile,
            trailing: _isParsing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          _StepCard(
            index: 2,
            title: l10n.text('columnMapping'),
            description: '自动识别类别代码与多币种字段，可手动调整。',
          ),
          const SizedBox(height: 16),
          _StepCard(
            index: 3,
            title: l10n.text('preview'),
            description: preview == null
                ? '等待文件解析...'
                : '解析 ${preview.entries.length} 条记录，重复 ${preview.duplicates.length} 条',
            child: preview == null
                ? null
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (preview.duplicates.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            '发现重复 ${preview.duplicates.length} 条，将自动跳过。',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: Colors.orangeAccent),
                          ),
                        ),
                      if (preview.unknownCategories.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            '未知类别: ${preview.unknownCategories.join(', ')}',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: Colors.orangeAccent),
                          ),
                        ),
                      _PreviewTable(entries: preview.entries.take(10).toList()),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          _StepCard(
            index: 4,
            title: l10n.text('importReport'),
            description: '导入完成后生成交易统计与错误日志。',
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _isImporting || _preview == null ? null : _importEntries,
            icon: _isImporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_circle),
            label: Text(l10n.text('startImport')),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.index,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
    this.child,
    this.trailing,
  });

  final int index;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    '$index',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (actionLabel != null)
                  FilledButton.tonal(
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
                if (trailing != null) ...<Widget>[
                  const SizedBox(width: 12),
                  trailing!,
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (child != null) ...<Widget>[
              const SizedBox(height: 16),
              child!,
            ],
          ],
        ),
      ),
    );
  }
}

class _PreviewTable extends StatelessWidget {
  const _PreviewTable({required this.entries});

  final List<ImportEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Text('无记录');
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: DataTable(
        columns: const <DataColumn>[
          DataColumn(label: Text('日期')),
          DataColumn(label: Text('类别')),
          DataColumn(label: Text('项目')),
          DataColumn(label: Text('金额')),
          DataColumn(label: Text('币种')),
        ],
        rows: entries
            .map(
              (ImportEntry entry) => DataRow(
                cells: <DataCell>[
                  DataCell(Text(entry.date.toIso8601String().split('T').first)),
                  DataCell(Text(entry.categoryCode)),
                  DataCell(Text(entry.project)),
                  DataCell(Text(entry.amount.toStringAsFixed(2))),
                  DataCell(Text(entry.currency)),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}
