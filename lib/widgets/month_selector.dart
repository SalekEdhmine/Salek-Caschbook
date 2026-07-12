import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../utils/formatters.dart';

class MonthSelector extends ConsumerWidget {
  final DateTime month;

  const MonthSelector({super.key, required this.month});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => ref.read(selectedMonthProvider.notifier).state =
                DateTime(month.year, month.month - 1),
          ),
          TextButton(
            onPressed: () => ref.read(selectedMonthProvider.notifier).state = DateTime.now(),
            child: Text(
              formatMonthYear(month),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: month.year == DateTime.now().year && month.month == DateTime.now().month
                ? null
                : () => ref.read(selectedMonthProvider.notifier).state =
                    DateTime(month.year, month.month + 1),
          ),
        ],
      ),
    );
  }
}
