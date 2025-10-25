import 'package:flutter/material.dart';

class CurrencyPicker extends StatelessWidget {
  const CurrencyPicker({
    super.key,
    required this.initialValue,
    required this.onChanged,
    this.currencies,
  });

  final String initialValue;
  final ValueChanged<String?>? onChanged;
  final List<String>? currencies;

  @override
  Widget build(BuildContext context) {
    final List<String> options = <String>[
      ...(currencies != null && currencies!.isNotEmpty
          ? currencies!
          : const <String>['CNY', 'AUD', 'USD', 'JPY', 'HKD'])
    ];

    if (!options.contains(initialValue) && initialValue.isNotEmpty) {
      options.add(initialValue);
    }

    final String resolvedValue =
        options.contains(initialValue) && initialValue.isNotEmpty
            ? initialValue
            : options.first;

    return DropdownButtonFormField<String>(
      key: ValueKey<String>(resolvedValue),
      initialValue: resolvedValue,
      items: options
          .map(
            (String code) => DropdownMenuItem<String>(
              value: code,
              child: Text(code),
            ),
          )
          .toList(),
      decoration: InputDecoration(
        labelText: '币种',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      onChanged: onChanged,
    );
  }
}
