import 'package:flutter/material.dart';
import '../utils/formatters.dart';

class SummaryCard extends StatelessWidget {
  final Map<String, double> summary;
  final String currency;
  final VoidCallback? onViewReports;

  const SummaryCard({
    super.key,
    required this.summary,
    this.currency = 'EUR',
    this.onViewReports,
  });

  @override
  Widget build(BuildContext context) {
    final balance    = summary['balance']  ?? 0;
    final income     = summary['income']   ?? 0;
    final expense    = summary['expense']  ?? 0;
    final isPositive = balance >= 0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Text('Kontostand',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer)),
            const SizedBox(height: 4),
            Text(
              formatCurrency(balance, currency: currency),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: isPositive ? Colors.green.shade700 : Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _StatItem(label: 'Einnahmen', value: income,  currency: currency, color: Colors.green.shade600, icon: Icons.arrow_upward)),
              const SizedBox(width: 12),
              Expanded(child: _StatItem(label: 'Ausgaben',  value: expense, currency: currency, color: Colors.red.shade600,   icon: Icons.arrow_downward)),
            ]),
            if (onViewReports != null) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: onViewReports,
                icon: const Icon(Icons.bar_chart_outlined, size: 16),
                label: const Text('BERICHTE ANZEIGEN', style: TextStyle(fontSize: 12)),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final double value;
  final String currency;
  final Color color;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.currency,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 11)),
              Text(
                formatCurrency(value, currency: currency),
                style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ]),
          ),
        ]),
      );
}
