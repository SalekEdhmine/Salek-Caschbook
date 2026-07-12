import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/business.dart';
import '../models/book.dart';
import '../providers/app_providers.dart';
import '../services/pb_service.dart';
import '../services/exchange_rate_service.dart';
import '../utils/formatters.dart';
import '../l10n/app_strings.dart';
import 'book_detail_screen.dart';
import 'members_screen.dart';

class CashbooksTab extends ConsumerStatefulWidget {
  const CashbooksTab({super.key});

  @override
  ConsumerState<CashbooksTab> createState() => _CashbooksTabState();
}

class _CashbooksTabState extends ConsumerState<CashbooksTab> {
  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider); // rebuild on language change
    final businessesAsync  = ref.watch(businessesProvider);
    final selectedBusiness = ref.watch(selectedBusinessProvider);

    ref.listen(businessesProvider, (_, next) {
      next.whenData((list) async {
        if (ref.read(selectedBusinessProvider) != null || list.isEmpty) return;
        // Beim App-Start: zuletzt geöffnetes Business wiederherstellen, statt
        // immer das erste in der Liste zu nehmen.
        final prefs = await SharedPreferences.getInstance();
        final lastId = prefs.getString('last_business_id');
        final matches = lastId != null ? list.where((b) => b.id == lastId).toList() : <Business>[];
        ref.read(selectedBusinessProvider.notifier).state = matches.isNotEmpty ? matches.first : list.first;
      });
    });

    ref.listen(selectedBusinessProvider, (_, next) {
      if (next != null) {
        SharedPreferences.getInstance().then((p) => p.setString('last_business_id', next.id!));
      }
    });

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: _BusinessSelectorButton(
          business: selectedBusiness,
          onTap: () => _showSelector(context),
        ),
        actions: [
          if (selectedBusiness != null)
            IconButton(
              icon: const Icon(Icons.person_add_outlined),
              tooltip: AppStrings.tr('mem_invite'),
              onPressed: () => _addMember(context, selectedBusiness),
            ),
          IconButton(
            icon: const Icon(Icons.add_business_outlined),
            tooltip: AppStrings.tr('business_new'),
            onPressed: () => _showAddBusiness(context),
          ),
        ],
      ),
      body: businessesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${AppStrings.tr("error")}: $e')),
        data: (businesses) {
          if (businesses.isEmpty) {
            return _EmptyBusinessView(onAdd: () => _showAddBusiness(context));
          }
          if (selectedBusiness == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return _BooksListView(business: selectedBusiness);
        },
      ),
      floatingActionButton: selectedBusiness != null
          ? FloatingActionButton.extended(
              onPressed: () => _showAddBook(context, selectedBusiness),
              icon: const Icon(Icons.add),
              label: Text(AppStrings.tr('add_new_book')),
            )
          : null,
    );
  }

  void _showSelector(BuildContext context) {
    final businesses = ref.read(businessesProvider).valueOrNull ?? [];
    final selected   = ref.read(selectedBusinessProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _BusinessSelectorSheet(
        businesses: businesses,
        selected: selected,
        onSelect: (b) {
          ref.read(selectedBusinessProvider.notifier).state = b;
          Navigator.pop(context);
        },
        onAdd: () { Navigator.pop(context); _showAddBusiness(context); },
        onEdit: (b) { Navigator.pop(context); _showEditBusiness(context, b); },
        onDelete: (b) { Navigator.pop(context); _confirmDeleteBusiness(context, b); },
      ),
    );
  }

  void _showAddBusiness(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => BusinessFormSheet(
        onSave: (b) async {
          await PbService.instance.insertBusiness(b);
          ref.invalidate(businessesProvider);
          final list = await PbService.instance.getBusinesses();
          if (list.isNotEmpty) {
            ref.read(selectedBusinessProvider.notifier).state = list.last;
          }
        },
      ),
    );
  }

  void _showEditBusiness(BuildContext context, Business b) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => BusinessFormSheet(
        existing: b,
        onSave: (updated) async {
          await PbService.instance.updateBusiness(updated);
          ref.invalidate(businessesProvider);
          ref.read(selectedBusinessProvider.notifier).state = updated;
        },
      ),
    );
  }

  Future<void> _confirmDeleteBusiness(BuildContext context, Business b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('"${b.name}" ${AppStrings.tr("delete")}?'),
        content: Text(AppStrings.tr('business_delete_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppStrings.tr('cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppStrings.tr('delete')),
          ),
        ],
      ),
    );
    if (ok == true && b.id != null) {
      await PbService.instance.deleteBusiness(b.id!);
      ref.invalidate(businessesProvider);
      ref.read(selectedBusinessProvider.notifier).state = null;
    }
  }

  void _showAddBook(BuildContext context, Business business) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BookFormSheet(
        businessId: business.id!,
        defaultCurrency: business.currency,
        onSave: (b) async {
          await PbService.instance.insertBook(b);
          ref.invalidate(booksProvider(business.id!));
        },
      ),
    );
  }

  Future<void> _addMember(BuildContext context, Business business) async {
    final books = ref.read(booksProvider(business.id!)).valueOrNull
        ?? await PbService.instance.getBooks(business.id!);
    if (!context.mounted) return;
    if (books.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.tr('book_no_books'))),
      );
      return;
    }
    if (books.length == 1) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => MembersScreen(book: books.first),
      ));
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (_) => BookPickerSheet(
        books: books,
        title: AppStrings.tr('member_add_to'),
        onSelect: (book) {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => MembersScreen(book: book),
          ));
        },
      ),
    );
  }
}

// ── Business Selector Button ──────────────────────────────────────────────────
class _BusinessSelectorButton extends StatelessWidget {
  final Business? business;
  final VoidCallback onTap;
  const _BusinessSelectorButton({required this.business, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (business != null) ...[
            _BusinessAvatar(business: business!, size: 30),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              business?.name ?? AppStrings.tr('business_switch'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down_rounded,
              size: 20, color: scheme.onSurface.withValues(alpha: 0.6)),
        ],
      ),
    );
  }
}

// ── Business Avatar (shows logo or colored icon) ──────────────────────────────
class _BusinessAvatar extends StatelessWidget {
  final Business business;
  final double size;
  const _BusinessAvatar({required this.business, this.size = 40});

  @override
  Widget build(BuildContext context) {
    if (business.logo != null && business.logo!.isNotEmpty) {
      try {
        final bytes = base64Decode(business.logo!);
        return ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.25),
          child: Image.memory(bytes, width: size, height: size, fit: BoxFit.cover),
        );
      } catch (_) {}
    }
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: Color(business.colorValue).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: Icon(Icons.business_rounded,
          color: Color(business.colorValue), size: size * 0.55),
    );
  }
}

// ── Business Selector Sheet ───────────────────────────────────────────────────
class _BusinessSelectorSheet extends StatefulWidget {
  final List<Business> businesses;
  final Business? selected;
  final ValueChanged<Business> onSelect;
  final VoidCallback onAdd;
  final ValueChanged<Business> onEdit;
  final ValueChanged<Business> onDelete;

  const _BusinessSelectorSheet({
    required this.businesses,
    required this.selected,
    required this.onSelect,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_BusinessSelectorSheet> createState() => _BusinessSelectorSheetState();
}

class _BusinessSelectorSheetState extends State<_BusinessSelectorSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filtered = _search.isEmpty
        ? widget.businesses
        : widget.businesses
            .where((b) => b.name.toLowerCase().contains(_search.toLowerCase()))
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (_, controller) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(AppStrings.tr('business_switch'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: AppStrings.tr('business_search'),
              prefixIcon: const Icon(Icons.search),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              controller: controller,
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final b = filtered[i];
                final isSelected = widget.selected?.id == b.id;
                return ListTile(
                  leading: _BusinessAvatar(business: b, size: 40),
                  title: Text(b.name,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? scheme.primary : null)),
                  subtitle: Text('${AppStrings.tr("owner")} · ${b.currency}',
                      style: const TextStyle(fontSize: 12)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (isSelected)
                      Icon(Icons.check_circle, color: Colors.green.shade600),
                    PopupMenuButton<String>(
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'edit', child: ListTile(
                            leading: const Icon(Icons.edit_outlined),
                            title: Text(AppStrings.tr('edit')), dense: true)),
                        PopupMenuItem(value: 'delete', child: ListTile(
                            leading: const Icon(Icons.delete_outline, color: Colors.red),
                            title: Text(AppStrings.tr('delete'), style: const TextStyle(color: Colors.red)),
                            dense: true)),
                      ],
                      onSelected: (v) =>
                          v == 'edit' ? widget.onEdit(b) : widget.onDelete(b),
                    ),
                  ]),
                  onTap: () => widget.onSelect(b),
                );
              },
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.add_business_outlined),
            title: Text(AppStrings.tr('business_add_new'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            textColor: scheme.primary,
            iconColor: scheme.primary,
            onTap: widget.onAdd,
          ),
        ]),
      ),
    );
  }
}

// ── Books List View ───────────────────────────────────────────────────────────
class _BooksListView extends ConsumerStatefulWidget {
  final Business business;
  const _BooksListView({required this.business});

  @override
  ConsumerState<_BooksListView> createState() => _BooksListViewState();
}

class _BooksListViewState extends ConsumerState<_BooksListView> {
  final _searchCtrl = TextEditingController();
  String _sortBy = 'name';
  bool _sortAsc = true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final booksAsync  = ref.watch(booksProvider(widget.business.id!));
    final sharedAsync = ref.watch(sharedBooksProvider);

    return booksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('${AppStrings.tr("error")}: $e')),
      data: (books) {
        final sharedBooks = sharedAsync.valueOrNull ?? [];

        // Filter
        final query = _searchCtrl.text.toLowerCase().trim();
        var filtered = books.where((b) {
          if (query.isEmpty) return true;
          return b.name.toLowerCase().contains(query) ||
                 (b.description?.toLowerCase().contains(query) ?? false);
        }).toList();

        // Sort
        filtered.sort((a, b) {
          int cmp;
          switch (_sortBy) {
            case 'name': cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase()); break;
            case 'balance': cmp = (a.initialBalance).compareTo(b.initialBalance); break;
            case 'created':
              cmp = (a.createdAt ?? DateTime(2000)).compareTo(b.createdAt ?? DateTime(2000));
              break;
            default: cmp = 0;
          }
          return _sortAsc ? cmp : -cmp;
        });

        var filteredShared = sharedBooks.where((b) {
          if (query.isEmpty) return true;
          return b.name.toLowerCase().contains(query);
        }).toList();

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(booksProvider(widget.business.id!));
            ref.invalidate(sharedBooksProvider);
          },
          child: CustomScrollView(slivers: [
          if (filtered.length > 1)
            SliverToBoxAdapter(child: _TotalBalanceCard(books: filtered)),
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Bücher durchsuchen...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                    suffixIcon: query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () { _searchCtrl.clear(); setState(() {}); },
                          ) : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: Icon(_sortAsc ? Icons.sort : Icons.sort, size: 20),
                tooltip: 'Sortieren',
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'name_asc', child: Text('Name A-Z ${_sortBy == 'name' && _sortAsc ? '✓' : ''}')),
                  PopupMenuItem(value: 'name_desc', child: Text('Name Z-A ${_sortBy == 'name' && !_sortAsc ? '✓' : ''}')),
                  const PopupMenuDivider(),
                  PopupMenuItem(value: 'balance_desc', child: Text('Höchster Saldo ${_sortBy == 'balance' && !_sortAsc ? '✓' : ''}')),
                  PopupMenuItem(value: 'balance_asc', child: Text('Niedrigster Saldo ${_sortBy == 'balance' && _sortAsc ? '✓' : ''}')),
                  const PopupMenuDivider(),
                  PopupMenuItem(value: 'created_desc', child: Text('Neueste zuerst ${_sortBy == 'created' && !_sortAsc ? '✓' : ''}')),
                  PopupMenuItem(value: 'created_asc', child: Text('Älteste zuerst ${_sortBy == 'created' && _sortAsc ? '✓' : ''}')),
                ],
                onSelected: (v) {
                  setState(() {
                    final parts = v.split('_');
                    _sortBy = parts[0];
                    _sortAsc = parts[1] == 'asc';
                  });
                },
              ),
            ]),
          )),
          SliverToBoxAdapter(child: _sectionHeader(context, AppStrings.tr('books_yours'), filtered.length)),
          if (filtered.isEmpty && query.isNotEmpty)
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(child: Text('Keine Bücher gefunden', style: TextStyle(color: Colors.grey.shade600))),
            )),
          if (filtered.isEmpty && query.isEmpty)
            SliverToBoxAdapter(child: _EmptyBooksNote())
          else
            SliverList(delegate: SliverChildBuilderDelegate(
              (ctx, i) => _BookListTile(
                book: filtered[i],
                currency: filtered[i].currency,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) =>
                      BookDetailScreen(book: filtered[i], business: widget.business)),
                ).then((_) {
                  ref.invalidate(booksProvider(widget.business.id!));
                  ref.invalidate(bookTotalBalanceProvider(filtered[i].id!));
                }),
                onEdit: () => _showEditBook(context, ref, filtered[i]),
                onDelete: () => _confirmDelete(context, ref, filtered[i]),
              ),
              childCount: filtered.length,
            )),
          if (filteredShared.isNotEmpty) ...[
            SliverToBoxAdapter(child: _sectionHeader(context, AppStrings.tr('books_shared'), filteredShared.length,
                icon: Icons.people_outline)),
            SliverList(delegate: SliverChildBuilderDelegate(
              (ctx, i) => _BookListTile(
                book: filteredShared[i],
                currency: 'EUR',
                isShared: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => BookDetailScreen(
                    book: filteredShared[i],
                    business: Business(name: AppStrings.tr('shared_badge'), currency: 'EUR'),
                  )),
                ),
              ),
              childCount: filteredShared.length,
            )),
          ],
        ]));
      },
    );
  }

  Widget _sectionHeader(BuildContext context, String title, int count,
      {IconData icon = Icons.menu_book_outlined}) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(children: [
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: 8),
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('$count',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: scheme.primary)),
        ),
      ]),
    );
  }

  void _showEditBook(BuildContext context, WidgetRef ref, Book b) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BookFormSheet(
        businessId: widget.business.id!,
        existing: b,
        onSave: (updated) async {
          await PbService.instance.updateBook(updated);
          ref.invalidate(booksProvider(widget.business.id!));
          ref.invalidate(bookTotalBalanceProvider(b.id!));
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Book b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('"${b.name}" ${AppStrings.tr("delete")}?'),
        content: Text(AppStrings.tr("book_delete_all_confirm")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppStrings.tr('cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppStrings.tr('delete')),
          ),
        ],
      ),
    );
    if (ok == true && b.id != null) {
      await PbService.instance.deleteBook(b.id!);
      ref.invalidate(booksProvider(widget.business.id!));
    }
  }
}

// ── Total Balance Card (über alle Bücher, währungsumgerechnet) ────────────────
class _TotalBalanceCard extends ConsumerWidget {
  final List<Book> books;
  const _TotalBalanceCard({required this.books});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<({Map<String, double> rates, String ref})>(
      future: () async {
        final rates = await ExchangeRateService.getRates();
        final reference = await ExchangeRateService.getReferenceCurrency();
        return (rates: rates, ref: reference);
      }(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final rates = snap.data!.rates;
        final reference = snap.data!.ref;

        double total = 0;
        bool anyLoading = false;
        bool anyMissingRate = false;
        for (final b in books) {
          final balanceAsync = ref.watch(bookTotalBalanceProvider(b.id!));
          final balance = balanceAsync.valueOrNull;
          if (balance == null) { anyLoading = true; continue; }
          if (b.currency != reference && !rates.containsKey(b.currency)) anyMissingRate = true;
          total += ExchangeRateService.convert(balance, b.currency, reference, rates);
        }

        return Card(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Icon(Icons.summarize_outlined, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Gesamt (umgerechnet)', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  Text(
                    anyLoading ? '…' : formatCurrency(total, currency: reference),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  if (anyMissingRate)
                    Text('Für manche Bücher fehlt ein Wechselkurs – Einstellungen → Wechselkurse',
                        style: TextStyle(fontSize: 11, color: Colors.orange.shade800)),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }
}

// ── Book List Tile ────────────────────────────────────────────────────────────
class _BookListTile extends ConsumerWidget {
  final Book book;
  final String currency;
  final bool isShared;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _BookListTile({
    required this.book,
    required this.currency,
    this.isShared = false,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color        = Color(book.colorValue);
    final balanceAsync = ref.watch(bookTotalBalanceProvider(book.id!));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.25)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: book.logo != null && book.logo!.isNotEmpty
                  ? Image.memory(base64Decode(book.logo!), fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(Icons.menu_book_rounded, color: color, size: 22))
                  : Icon(Icons.menu_book_rounded, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(book.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                if (book.description != null && book.description!.isNotEmpty)
                  Text(book.description!,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                if (isShared)
                  Row(children: [
                    Icon(Icons.share_outlined, size: 11, color: Colors.orange.shade600),
                    const SizedBox(width: 4),
                    Text(AppStrings.tr('shared_badge'),
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w500)),
                  ]),
              ]),
            ),
            const SizedBox(width: 8),
            balanceAsync.when(
              loading: () => const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              error: (_, __) => const SizedBox.shrink(),
              data: (balance) {
                final isPos = balance >= 0;
                return Text(
                  formatCurrency(balance, currency: currency),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isPos ? Colors.green.shade600 : Colors.red.shade600,
                  ),
                );
              },
            ),
            if (!isShared && onEdit != null)
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                iconSize: 20,
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      title: Text(AppStrings.tr('edit')), dense: true)),
                  PopupMenuItem(value: 'delete', child: ListTile(
                      leading: const Icon(Icons.delete_outline, color: Colors.red),
                      title: Text(AppStrings.tr('delete'), style: const TextStyle(color: Colors.red)),
                      dense: true)),
                ],
                onSelected: (v) => v == 'edit' ? onEdit!() : onDelete!(),
              ),
          ]),
        ),
      ),
    );
  }
}

// ── Empty Views ───────────────────────────────────────────────────────────────
class _EmptyBusinessView extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyBusinessView({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
            child: Icon(Icons.business_center_outlined, size: 52, color: scheme.primary),
          ),
          const SizedBox(height: 24),
          Text(AppStrings.tr('welcome'),
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(AppStrings.tr('welcome_sub'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_business_outlined),
            label: Text(AppStrings.tr('business_create')),
            style: FilledButton.styleFrom(minimumSize: const Size(200, 50)),
          ),
        ]),
      ),
    );
  }
}

class _EmptyBooksNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.menu_book_outlined, size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        Text(AppStrings.tr('book_no_books'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(AppStrings.tr('book_no_books_sub'),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600)),
      ]),
    );
  }
}

// ── Book Picker Sheet ─────────────────────────────────────────────────────────
class BookPickerSheet extends StatelessWidget {
  final List<Book> books;
  final String title;
  final ValueChanged<Book> onSelect;

  const BookPickerSheet({
    super.key,
    required this.books,
    required this.title,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...books.map((b) => ListTile(
                leading: Icon(Icons.menu_book_rounded, color: Color(b.colorValue)),
                title: Text(b.name),
                subtitle: b.description != null ? Text(b.description!) : null,
                onTap: () => onSelect(b),
              )),
        ],
      ),
    );
  }
}

// ── Business Form Sheet (with logo picker) ────────────────────────────────────
class BusinessFormSheet extends StatefulWidget {
  final Business? existing;
  final Future<void> Function(Business) onSave;
  const BusinessFormSheet({super.key, this.existing, required this.onSave});

  @override
  State<BusinessFormSheet> createState() => _BusinessFormSheetState();
}

class _BusinessFormSheetState extends State<BusinessFormSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String  _currency = 'EUR';
  int     _color    = 0xFF1976D2;
  String? _logo;       // base64 encoded thumbnail
  bool    _saving   = false;

  final _colors = [
    0xFF1976D2, 0xFF388E3C, 0xFFE64A19, 0xFF7B1FA2,
    0xFF0097A7, 0xFFF57C00, 0xFFE91E63, 0xFF00897B,
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _nameCtrl.text = widget.existing!.name;
      _descCtrl.text = widget.existing?.description ?? '';
      _currency = widget.existing!.currency;
      _color = widget.existing!.colorValue;
      _logo  = widget.existing!.logo;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) return;
    // Resize to max 128×128 px
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Dieses Bildformat wird nicht unterstützt (z.B. HEIC von iPhone). Bitte als JPG oder PNG wählen.'),
          backgroundColor: Colors.red,
        ));
      }
      return;
    }
    final resized = img.copyResize(decoded,
        width: decoded.width > decoded.height ? 128 : -1,
        height: decoded.height >= decoded.width ? 128 : -1);
    final jpeg = img.encodeJpg(resized, quality: 80);
    setState(() => _logo = base64Encode(Uint8List.fromList(jpeg)));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.existing == null
            ? AppStrings.tr('business_new')
            : AppStrings.tr('business_edit'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        // Logo picker
        Center(
          child: GestureDetector(
            onTap: _pickLogo,
            child: Stack(children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: Color(_color).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Color(_color).withValues(alpha: 0.3)),
                ),
                child: _logo != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(19),
                        child: Image.memory(base64Decode(_logo!),
                            fit: BoxFit.cover, width: 80, height: 80),
                      )
                    : Icon(Icons.business_rounded, color: Color(_color), size: 40),
              ),
              Positioned(
                right: 0, bottom: 0,
                child: Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: Color(_color),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 12),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        TextField(controller: _nameCtrl, autofocus: true,
            decoration: InputDecoration(labelText: '${AppStrings.tr("name")} *')),
        const SizedBox(height: 12),
        TextField(controller: _descCtrl,
            decoration: InputDecoration(labelText: AppStrings.tr('book_description'))),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _currency,
          decoration: InputDecoration(labelText: AppStrings.tr('currency')),
          items: ['EUR', 'USD', 'GBP', 'CHF', 'TRY', 'INR', 'DZD', 'MAD', 'SAR', 'MRU']
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) => setState(() => _currency = v!),
        ),
        const SizedBox(height: 12),
        Text(AppStrings.tr('color'), style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 8),
        Row(children: _colors.map((c) => GestureDetector(
          onTap: () => setState(() => _color = c),
          child: Container(
            margin: const EdgeInsets.only(right: 10),
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: Color(c), shape: BoxShape.circle,
              border: _color == c ? Border.all(color: Colors.white, width: 3) : null,
              boxShadow: _color == c
                  ? [BoxShadow(color: Color(c).withValues(alpha: 0.5), blurRadius: 8)]
                  : null,
            ),
            child: _color == c ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
          ),
        )).toList()),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: Text(_saving
              ? AppStrings.tr('loading')
              : (widget.existing == null
                  ? AppStrings.tr('create')
                  : AppStrings.tr('save'))),
        ),
      ]),
    );
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(Business(
        id: widget.existing?.id,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        currency: _currency,
        colorValue: _color,
        logo: _logo,
      ));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.tr("error")}: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// ── Book Form Sheet ───────────────────────────────────────────────────────────
class _BookFormSheet extends StatefulWidget {
  final String businessId;
  final Book? existing;
  final String defaultCurrency;
  final Future<void> Function(Book) onSave;
  const _BookFormSheet({
    required this.businessId,
    this.existing,
    this.defaultCurrency = 'EUR',
    required this.onSave,
  });

  @override
  State<_BookFormSheet> createState() => _BookFormSheetState();
}

class _BookFormSheetState extends State<_BookFormSheet> {
  final _nameCtrl    = TextEditingController();
  final _descCtrl    = TextEditingController();
  final _balanceCtrl = TextEditingController();
  int _color = 0xFF4CAF50;
  String _currency = 'EUR';
  String? _logo;
  bool _saving = false;

  final _colors = [0xFF4CAF50, 0xFF1976D2, 0xFFE64A19, 0xFF7B1FA2, 0xFFF57C00, 0xFF0097A7];

  @override
  void initState() {
    super.initState();
    _currency = widget.defaultCurrency;
    if (widget.existing != null) {
      _nameCtrl.text    = widget.existing!.name;
      _descCtrl.text    = widget.existing?.description ?? '';
      _balanceCtrl.text = widget.existing!.initialBalance.toStringAsFixed(2);
      _color            = widget.existing!.colorValue;
      _currency         = widget.existing!.currency;
      _logo             = widget.existing!.logo;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) return;
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Dieses Bildformat wird nicht unterstützt (z.B. HEIC von iPhone). Bitte als JPG oder PNG wählen.'),
          backgroundColor: Colors.red,
        ));
      }
      return;
    }
    final resized = img.copyResize(decoded,
        width: decoded.width > decoded.height ? 128 : -1,
        height: decoded.height >= decoded.width ? 128 : -1);
    final jpeg = img.encodeJpg(resized, quality: 80);
    setState(() => _logo = base64Encode(Uint8List.fromList(jpeg)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.existing == null
            ? AppStrings.tr('book_new')
            : AppStrings.tr('book_edit'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Center(
          child: GestureDetector(
            onTap: _pickLogo,
            child: Stack(children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: Color(_color).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Color(_color).withValues(alpha: 0.3)),
                ),
                child: _logo != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(17),
                        child: Image.memory(base64Decode(_logo!), fit: BoxFit.cover, width: 72, height: 72),
                      )
                    : Icon(Icons.menu_book_rounded, color: Color(_color), size: 36),
              ),
              Positioned(
                right: 0, bottom: 0,
                child: Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: Color(_color), shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 11),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        TextField(controller: _nameCtrl, autofocus: true,
            decoration: InputDecoration(labelText: '${AppStrings.tr("name")} *', border: const OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: _descCtrl,
            decoration: InputDecoration(
                labelText: AppStrings.tr('book_description'), border: const OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(
          controller: _balanceCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
              labelText: AppStrings.tr('book_initial_balance'),
              prefixText: '${currencySymbol(_currency)} ', border: const OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _currency,
          decoration: InputDecoration(labelText: AppStrings.tr('currency'), border: const OutlineInputBorder()),
          items: ['EUR', 'USD', 'GBP', 'CHF', 'TRY', 'INR', 'DZD', 'MAD', 'SAR', 'MRU']
              .map((c) => DropdownMenuItem(value: c, child: Text('$c ${currencySymbol(c)}')))
              .toList(),
          onChanged: (v) => setState(() => _currency = v!),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Text('${AppStrings.tr("color")}: '),
          ..._colors.map((c) => GestureDetector(
            onTap: () => setState(() => _color = c),
            child: Container(
              margin: const EdgeInsets.only(left: 8),
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: Color(c), shape: BoxShape.circle,
                border: _color == c ? Border.all(width: 3, color: Colors.white) : null,
                boxShadow: _color == c
                    ? [BoxShadow(color: Color(c).withValues(alpha: 0.5), blurRadius: 6)]
                    : null,
              ),
            ),
          )),
        ]),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: Text(_saving ? AppStrings.tr('loading') : AppStrings.tr('save')),
        ),
      ]),
    );
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final balance = parseFlexibleNumber(_balanceCtrl.text) ?? 0.0;
    try {
      await widget.onSave(Book(
        id: widget.existing?.id,
        businessId: widget.businessId,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        initialBalance: balance,
        colorValue: _color,
        currency: _currency,
        logo: _logo,
      ));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.tr("error")}: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
