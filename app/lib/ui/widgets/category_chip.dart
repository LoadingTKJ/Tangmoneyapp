import 'package:flutter/material.dart';

class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.code,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final String code;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final Color base = dark ? Colors.white : theme.colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected
              ? base.withValues(alpha: dark ? 0.25 : 0.15)
              : base.withValues(alpha: dark ? 0.1 : 0.05),
          border: Border.all(
            color: base.withValues(alpha: selected ? 0.7 : 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              code,
              style: TextStyle(
                color: dark ? Colors.white : base,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(color: dark ? Colors.white : base),
            ),
          ],
        ),
      ),
    );
  }
}
