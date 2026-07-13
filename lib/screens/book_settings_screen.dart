import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import '../l10n/app_strings.dart';
import '../models/book.dart';
import '../services/pb_service.dart';
import '../providers/app_providers.dart';
import '../utils/formatters.dart';

class BookSettingsScreen extends ConsumerStatefulWidget {
  final Book book;
  const BookSettingsScreen({super.key, required this.book});

  @override
  ConsumerState<BookSettingsScreen> createState() => _BookSettingsScreenState();
}

class _BookSettingsScreenState extends ConsumerState<BookSettingsScreen> {
  final _nameCtrl    = TextEditingController();
  final _descCtrl    = TextEditingController();
  final _balanceCtrl = TextEditingController();
  late int _colorValue;
  late String _currency;
  String? _logo;
  bool _saving = false;

  static const _colorOptions = [
    Colors.blue, Colors.green, Colors.orange, Colors.purple,
    Colors.red,  Colors.teal,  Colors.indigo, Colors.amber,
    Colors.pink, Colors.cyan,
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl.text    = widget.book.name;
    _descCtrl.text    = widget.book.description ?? '';
    _balanceCtrl.text = widget.book.initialBalance.toStringAsFixed(2);
    _colorValue       = widget.book.colorValue;
    _currency         = widget.book.currency;
    _logo             = widget.book.logo;
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppStrings.tr('unsupported_image_format')),
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
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.tr('book_settings_title'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Profilbild
        Center(
          child: GestureDetector(
            onTap: _pickLogo,
            child: Stack(children: [
              Container(
                width: 88, height: 88,
                decoration: BoxDecoration(
                  color: Color(_colorValue).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Color(_colorValue).withValues(alpha: 0.3)),
                ),
                child: _logo != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(19),
                        child: Image.memory(base64Decode(_logo!), fit: BoxFit.cover, width: 88, height: 88),
                      )
                    : Icon(Icons.menu_book_rounded, color: Color(_colorValue), size: 44),
              ),
              Positioned(
                right: 0, bottom: 0,
                child: Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: Color(_colorValue), shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 13),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 20),

        // Name
        TextFormField(
          controller: _nameCtrl,
          decoration: InputDecoration(
            labelText: AppStrings.tr('book_name_field'),
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.menu_book_outlined),
          ),
        ),
        const SizedBox(height: 16),

        // Description
        TextFormField(
          controller: _descCtrl,
          decoration: InputDecoration(
            labelText: AppStrings.tr('description_optional'),
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.notes_outlined),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 16),

        // Initial balance
        TextFormField(
          controller: _balanceCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: AppStrings.tr('initial_balance_field'),
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.account_balance_outlined),
            helperText: AppStrings.tr('initial_balance_helper'),
          ),
        ),
        const SizedBox(height: 16),

        // Currency
        DropdownButtonFormField<String>(
          value: _currency,
          decoration: InputDecoration(
            labelText: AppStrings.tr('currency'),
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.attach_money),
          ),
          items: ['EUR', 'USD', 'GBP', 'CHF', 'TRY', 'INR', 'DZD', 'MAD', 'SAR', 'MRU']
              .map((c) => DropdownMenuItem(value: c, child: Text('$c ${currencySymbol(c)}')))
              .toList(),
          onChanged: (v) => setState(() => _currency = v!),
        ),
        const SizedBox(height: 16),

        // Color picker
        Text(AppStrings.tr('color'), style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _colorOptions.map((c) {
            final colorVal = c.toARGB32();
            final selected = colorVal == _colorValue;
            return GestureDetector(
              onTap: () => setState(() => _colorValue = colorVal),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: selected ? Border.all(color: Colors.white, width: 2) : null,
                  boxShadow: selected ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 8)] : null,
                ),
                child: selected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        // Save button
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save),
          label: Text(_saving ? AppStrings.tr('saving') : AppStrings.tr('save_changes')),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
        const SizedBox(height: 32),

        // Danger zone
        Text(AppStrings.tr('danger_zone'), style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.red)),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          color: Colors.red.shade50,
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
              title: Text(AppStrings.tr('delete_all_transactions'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
              subtitle: Text(AppStrings.tr('delete_all_transactions_sub')),
              trailing: OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                onPressed: () => _confirmDeleteAll(context),
                child: Text(AppStrings.tr('delete')),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 40),
      ]),
    );
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final balance = parseFlexibleNumber(_balanceCtrl.text) ?? widget.book.initialBalance;
    final updated = Book(
      id:             widget.book.id,
      businessId:     widget.book.businessId,
      name:           _nameCtrl.text.trim(),
      description:    _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      colorValue:     _colorValue,
      initialBalance: balance,
      currency:       _currency,
      logo:           _logo,
    );
    try {
      await PbService.instance.updateBook(updated);
      ref.invalidate(booksProvider(widget.book.businessId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.tr('book_saved'))));
        Navigator.pop(context, updated);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppStrings.tr('error')}: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _confirmDeleteAll(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppStrings.tr('delete_all_title')),
        content: Text(AppStrings.tr('delete_all_body').replaceAll('{name}', widget.book.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppStrings.tr('cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppStrings.tr('delete_all_button')),
          ),
        ],
      ),
    );
    if (ok == true && widget.book.id != null) {
      try {
        await PbService.instance.deleteAllTransactions(widget.book.id!);
        ref.invalidate(transactionsProvider(widget.book.id!));
        ref.invalidate(summaryProvider(widget.book.id!));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.tr('all_transactions_deleted'))));
          Navigator.pop(context);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppStrings.tr('error')}: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }
}
