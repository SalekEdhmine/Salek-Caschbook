import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../providers/app_providers.dart';
import '../services/pb_service.dart';
import '../utils/formatters.dart';

class BudgetScreen extends ConsumerStatefulWidget {
  final String bookId;
  final String currency;

  const BudgetScreen({super.key, required this.bookId, required this.currency});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  @override
  Widget build(BuildContext context) {
    final budgetsAsync  = ref.watch(budgetsProvider(widget.bookId));
    final categoriesAsync = ref.watch(categoriesProvider(TransactionType.expense));

    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(budgetsProvider(widget.bookId)),
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Text('Monatsbudgets festlegen',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Lege für jede Ausgaben-Kategorie ein monatliches Limit fest.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 16),
          categoriesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (cats) {
              if (cats.isEmpty) return const Text('Keine Ausgaben-Kategorien vorhanden.');
              return budgetsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (budgets) {
                  final budgetMap = {for (final b in budgets) b.categoryId: b};
                  return Column(
                    children: cats.map((cat) {
                      final budget = budgetMap[cat.id];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Color(cat.colorValue).withValues(alpha: 0.15),
                            child: Icon(_iconFor(cat.icon), color: Color(cat.colorValue), size: 20),
                          ),
                          title: Text(cat.name),
                          subtitle: budget != null
                              ? Text('Limit: ${formatCurrency(budget.amount, currency: widget.currency)}',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12))
                              : Text('Kein Budget', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                          trailing: FilledButton.tonalIcon(
                            icon: Icon(budget != null ? Icons.edit : Icons.add, size: 16),
                            label: Text(budget != null ? 'Ändern' : 'Setzen', style: const TextStyle(fontSize: 12)),
                            onPressed: () => _showBudgetDialog(cat, budget),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              );
            },
          ),
        ]),
      ),
    );
  }

  IconData _iconFor(String icon) {
    final icons = {
      'local_grocery_store': Icons.local_grocery_store, 'home': Icons.home,
      'directions_car': Icons.directions_car, 'local_hospital': Icons.local_hospital,
      'sports_esports': Icons.sports_esports, 'restaurant': Icons.restaurant,
      'checkroom': Icons.checkroom, 'school': Icons.school, 'more_horiz': Icons.more_horiz,
      'payments': Icons.payments, 'work': Icons.work, 'trending_up': Icons.trending_up,
      'add_circle': Icons.add_circle, 'label': Icons.label, 'shopping_cart': Icons.shopping_cart,
      'flight': Icons.flight, 'pets': Icons.pets, 'fitness_center': Icons.fitness_center,
    };
    return icons[icon] ?? Icons.category;
  }

  Future<void> _showBudgetDialog(Category cat, Budget? existing) async {
    final ctrl = TextEditingController(
      text: existing != null ? existing.amount.toStringAsFixed(2) : '',
    );
    await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Budget: ${cat.name}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Monatslimit (${widget.currency})',
              prefixText: '${currencySymbol(widget.currency)} ',
              border: const OutlineInputBorder(),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: existing != null
                ? () async {
                    await PbService.instance.deleteBudget(widget.bookId, cat.id!);
                    ref.invalidate(budgetsProvider(widget.bookId));
                    if (ctx.mounted) Navigator.pop(ctx);
                  }
                : null,
            child: Text('Löschen', style: TextStyle(color: existing != null ? Colors.red : Colors.grey)),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () async {
              final amount = parseFlexibleNumber(ctrl.text);
              if (amount == null || amount <= 0) return;
              await PbService.instance.setBudget(Budget(
                bookId: widget.bookId,
                categoryId: cat.id!,
                categoryName: cat.name,
                categoryIcon: cat.icon,
                categoryColor: cat.colorValue,
                amount: amount,
              ));
              ref.invalidate(budgetsProvider(widget.bookId));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }
}
