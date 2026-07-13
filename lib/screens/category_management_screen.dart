import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_strings.dart';
import '../models/category.dart';
import '../providers/app_providers.dart';
import '../services/pb_service.dart';
import '../utils/icon_helper.dart';

class CategoryManagementScreen extends ConsumerStatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  ConsumerState<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends ConsumerState<CategoryManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(categoriesProvider(null));
    ref.invalidate(categoriesProvider(TransactionType.income));
    ref.invalidate(categoriesProvider(TransactionType.expense));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr('manage_categories')),
        bottom: TabBar(controller: _tabs, tabs: [Tab(text: AppStrings.tr('summary_total_out')), Tab(text: AppStrings.tr('summary_total_in'))]),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(
          context,
          defaultType: _tabs.index == 0 ? TransactionType.expense : TransactionType.income,
        ),
        icon: const Icon(Icons.add),
        label: Text(AppStrings.tr('category')),
      ),
      body: TabBarView(controller: _tabs, children: [
        _CategoryList(type: TransactionType.expense, onRefresh: _refresh),
        _CategoryList(type: TransactionType.income,  onRefresh: _refresh),
      ]),
    );
  }

  void _showForm(BuildContext ctx, {Category? existing, required TransactionType defaultType}) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      builder: (_) => _CategoryForm(
        existing: existing,
        defaultType: defaultType,
        onSaved: _refresh,
      ),
    );
  }
}

class _CategoryList extends ConsumerWidget {
  final TransactionType type;
  final VoidCallback onRefresh;

  const _CategoryList({required this.type, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catsAsync = ref.watch(categoriesProvider(type));

    return catsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:   (e, _) => Center(child: Text('$e')),
      data: (cats) {
        if (cats.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.category_outlined, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(AppStrings.tr('no_category_of_type').replaceAll('{type}', type == TransactionType.expense ? AppStrings.tr('summary_total_out') : AppStrings.tr('summary_total_in'))),
            ]),
          );
        }
        return ListView.separated(
          itemCount: cats.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (ctx, i) {
            final cat = cats[i];
            final color = Color(cat.colorValue);
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(_iconData(cat.icon), color: color, size: 20),
              ),
              title: Text(cat.name),
              subtitle: Text(type == TransactionType.expense ? AppStrings.tr('expense') : AppStrings.tr('income'),
                  style: TextStyle(color: color, fontSize: 12)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _edit(ctx, ref, cat),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _delete(ctx, ref, cat),
                ),
              ]),
            );
          },
        );
      },
    );
  }

  void _edit(BuildContext ctx, WidgetRef ref, Category cat) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      builder: (_) => _CategoryForm(
        existing: cat,
        defaultType: cat.type,
        onSaved: onRefresh,
      ),
    );
  }

  Future<void> _delete(BuildContext ctx, WidgetRef ref, Category cat) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text(AppStrings.tr('delete_category_title')),
        content: Text(AppStrings.tr('delete_category_body').replaceAll('{name}', cat.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppStrings.tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: Text(AppStrings.tr('delete'))),
        ],
      ),
    );
    if (ok == true) {
      await PbService.instance.deleteCategory(cat.id!);
      onRefresh();
    }
  }

  IconData _iconData(String name) => categoryIcon(name);
}

class _CategoryForm extends StatefulWidget {
  final Category? existing;
  final TransactionType defaultType;
  final VoidCallback onSaved;

  const _CategoryForm({this.existing, required this.defaultType, required this.onSaved});

  @override
  State<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<_CategoryForm> {
  final _nameCtrl = TextEditingController();
  late TransactionType _type;
  String _icon = 'label_outline';
  int _color = 0xFF1976D2;

  @override
  void initState() {
    super.initState();
    _type = widget.existing?.type ?? widget.defaultType;
    _nameCtrl.text = widget.existing?.name ?? '';
    _icon  = widget.existing?.icon ?? 'label_outline';
    _color = widget.existing?.colorValue ?? 0xFF1976D2;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final cat = Category(
      id: widget.existing?.id,
      name: name,
      icon: _icon,
      colorValue: _color,
      type: _type,
    );

    if (widget.existing == null) {
      await PbService.instance.insertCategory(cat);
    } else {
      await PbService.instance.updateCategory(cat);
    }
    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.existing == null ? AppStrings.tr('new_category') : AppStrings.tr('edit_category'),
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        TextField(
          controller: _nameCtrl,
          decoration: InputDecoration(labelText: AppStrings.tr('name'), prefixIcon: const Icon(Icons.label_outlined)),
          autofocus: true,
        ),
        const SizedBox(height: 12),
        SegmentedButton<TransactionType>(
          segments: [
            ButtonSegment(value: TransactionType.expense, label: Text(AppStrings.tr('expense')), icon: const Icon(Icons.arrow_downward)),
            ButtonSegment(value: TransactionType.income,  label: Text(AppStrings.tr('income')), icon: const Icon(Icons.arrow_upward)),
          ],
          selected: {_type},
          onSelectionChanged: (s) => setState(() => _type = s.first),
        ),
        const SizedBox(height: 16),
        Text(AppStrings.tr('color'), style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: _colorOptions.map((c) {
          final selected = _color == c;
          return GestureDetector(
            onTap: () => setState(() => _color = c),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Color(c),
                shape: BoxShape.circle,
                border: selected ? Border.all(color: Colors.black, width: 2.5) : null,
              ),
              child: selected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
            ),
          );
        }).toList()),
        const SizedBox(height: 16),
        Text(AppStrings.tr('icon_label'), style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: categoryIconMap.entries.map((e) {
          final selected = _icon == e.key;
          return GestureDetector(
            onTap: () => setState(() => _icon = e.key),
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: selected ? Color(_color).withValues(alpha: 0.2) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: selected ? Color(_color) : Colors.grey.shade300),
              ),
              child: Icon(e.value, color: selected ? Color(_color) : Colors.grey, size: 22),
            ),
          );
        }).toList()),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _save,
            child: Text(widget.existing == null ? AppStrings.tr('create') : AppStrings.tr('save')),
          ),
        ),
      ]),
    );
  }
}

const _colorOptions = [
  0xFF1976D2, 0xFF388E3C, 0xFFF44336, 0xFFFF9800, 0xFF9C27B0,
  0xFF00BCD4, 0xFFE91E63, 0xFF795548, 0xFF607D8B, 0xFF3F51B5,
  0xFFFF5722, 0xFF009688, 0xFFCDDC39, 0xFFFFC107,
];

// Icon map is now in lib/utils/icon_helper.dart
