import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_strings.dart';
import '../models/category.dart';
import '../services/pb_service.dart';
import '../models/transaction.dart';
import '../providers/app_providers.dart';
import '../utils/formatters.dart' show formatDate, formatTime, currencySymbol, parseFlexibleNumber;
import 'category_management_screen.dart';

List<String> _paymentModes() => [
      AppStrings.tr('payment_cash'),
      AppStrings.tr('payment_transfer'),
      AppStrings.tr('payment_ec'),
      AppStrings.tr('payment_credit_card'),
      AppStrings.tr('payment_paypal'),
      AppStrings.tr('payment_other'),
    ];

class AddTransactionScreen extends ConsumerStatefulWidget {
  final String bookId;
  final Transaction? existing;
  final String currency;
  final TransactionType? initialType;

  const AddTransactionScreen({
    super.key,
    required this.bookId,
    this.existing,
    this.currency = 'EUR',
    this.initialType,
  });

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey       = GlobalKey<FormState>();
  final _amountCtrl    = TextEditingController();
  final _titleCtrl     = TextEditingController();
  final _noteCtrl      = TextEditingController();
  final _contactCtrl   = TextEditingController();

  TransactionType _type = TransactionType.expense;
  Category?       _selectedCategory;
  String?         _existingCategoryId;
  DateTime        _date = DateTime.now();
  List<String>    _attachments = [];
  String?         _paymentMode;
  bool            _isRecurring = false;
  String?         _recurrenceInterval;
  bool            _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialType != null) _type = widget.initialType!;
    if (widget.existing != null) {
      final tx             = widget.existing!;
      _type                = tx.type;
      _existingCategoryId  = tx.categoryId;
      _amountCtrl.text     = tx.amount.toStringAsFixed(2);
      _titleCtrl.text      = tx.title;
      _noteCtrl.text       = tx.note ?? '';
      _contactCtrl.text    = tx.contact ?? '';
      _date                = tx.date;
      _attachments         = List.from(tx.attachments);
      _paymentMode         = tx.paymentMode;
      _isRecurring         = tx.isRecurring;
      _recurrenceInterval  = tx.recurrenceInterval;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    final ext = (file.extension ?? 'bin').toLowerCase();
    Uint8List bytes = file.bytes!;

    if (ext != 'pdf') {
      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        final resized = decoded.width > 1200 ? img.copyResize(decoded, width: 1200) : decoded;
        bytes = Uint8List.fromList(img.encodeJpg(resized, quality: 75));
      }
    } else if (bytes.lengthInBytes > 2 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.tr('pdf_too_large')), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    final base64str = base64Encode(bytes);
    final saveExt = ext == 'pdf' ? 'pdf' : 'jpg';
    setState(() => _attachments.add('$saveExt:$base64str'));
  }

  void _removeAttachment(int i) => setState(() => _attachments.removeAt(i));

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider(_type));

    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? AppStrings.tr('add_transaction_title') : AppStrings.tr('edit_transaction_title'))),
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          // Income / Expense toggle
          SegmentedButton<TransactionType>(
            segments: [
              ButtonSegment(value: TransactionType.expense, label: Text(AppStrings.tr('expense')),  icon: const Icon(Icons.remove_circle_outline)),
              ButtonSegment(value: TransactionType.income,  label: Text(AppStrings.tr('income')), icon: const Icon(Icons.add_circle_outline)),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() { _type = s.first; _selectedCategory = null; }),
          ),
          const SizedBox(height: 20),

          // Bezeichnung
          TextFormField(
            controller: _titleCtrl,
            decoration: InputDecoration(
              labelText: AppStrings.tr('title_field'),
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.label_outlined),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? AppStrings.tr('title_required') : null,
          ),
          const SizedBox(height: 16),

          // Amount
          TextFormField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: AppStrings.tr('amount_field'),
              prefixText: '${currencySymbol(widget.currency)} ',
              border: const OutlineInputBorder(),
              suffixIcon: Icon(
                _type == TransactionType.income ? Icons.arrow_upward : Icons.arrow_downward,
                color: _type == TransactionType.income ? Colors.green : Colors.red,
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return AppStrings.tr('amount_required');
              if (parseFlexibleNumber(v) == null) return AppStrings.tr('amount_invalid');
              if (double.parse(v.replaceAll(',', '.')) <= 0) return AppStrings.tr('amount_positive');
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Category
          categoriesAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (cats) {
              final preselect = _existingCategoryId != null && _selectedCategory == null
                  ? cats.where((c) => c.id == _existingCategoryId).firstOrNull
                  : null;
              if (preselect != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _selectedCategory = preselect);
                });
              }
              return Row(children: [
                Expanded(
                  child: DropdownButtonFormField<Category>(
                    value: _selectedCategory,
                    decoration: InputDecoration(labelText: AppStrings.tr('category_field'), border: const OutlineInputBorder()),
                    items: cats.map((c) => DropdownMenuItem(
                      value: c,
                      child: Row(children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: Color(c.colorValue), shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text(c.name),
                      ]),
                    )).toList(),
                    onChanged: (c) => setState(() => _selectedCategory = c),
                    validator: (v) => v == null ? AppStrings.tr('category_required') : null,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: AppStrings.tr('manage_categories'),
                  icon: const Icon(Icons.tune),
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const CategoryManagementScreen(),
                    ));
                    ref.invalidate(categoriesProvider(_type));
                    setState(() => _selectedCategory = null);
                  },
                ),
              ]);
            },
          ),
          const SizedBox(height: 16),

          // Date + Time
          Row(children: [
            Expanded(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text(formatDate(_date)),
                subtitle: Text(AppStrings.tr('date_label')),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade400),
                ),
                onTap: () async {
                  final p = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (p != null) {
                    setState(() => _date = DateTime(p.year, p.month, p.day, _date.hour, _date.minute));
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time),
                title: Text(formatTime(_date)),
                subtitle: Text(AppStrings.tr('time_label')),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade400),
                ),
                onTap: () async {
                  final p = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(hour: _date.hour, minute: _date.minute),
                  );
                  if (p != null) {
                    setState(() => _date = DateTime(_date.year, _date.month, _date.day, p.hour, p.minute));
                  }
                },
              ),
            ),
          ]),
          const SizedBox(height: 16),

          // Payment mode
          DropdownButtonFormField<String>(
            value: _paymentMode,
            decoration: InputDecoration(
              labelText: AppStrings.tr('payment_mode_field'),
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.payment_outlined),
            ),
            items: [
              DropdownMenuItem<String>(value: null, child: Text(AppStrings.tr('no_info'))),
              ..._paymentModes().map((m) => DropdownMenuItem(value: m, child: Text(m))),
            ],
            onChanged: (v) => setState(() => _paymentMode = v),
          ),
          const SizedBox(height: 16),

          // Contact
          TextFormField(
            controller: _contactCtrl,
            decoration: InputDecoration(
              labelText: AppStrings.tr('contact_field'),
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.person_outline),
              helperText: AppStrings.tr('contact_helper'),
            ),
          ),
          const SizedBox(height: 16),

          // Note
          TextFormField(
            controller: _noteCtrl,
            decoration: InputDecoration(
              labelText: AppStrings.tr('note_field'),
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.note_outlined),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),

          // Recurring toggle
          Card(
            elevation: 0,
            child: SwitchListTile(
              secondary: const Icon(Icons.repeat),
              title: Text(AppStrings.tr('recurring')),
              subtitle: Text(AppStrings.tr('recurring_subtitle')),
              value: _isRecurring,
              onChanged: (v) => setState(() {
                _isRecurring = v;
                if (v && _recurrenceInterval == null) _recurrenceInterval = 'monthly';
              }),
            ),
          ),
          if (_isRecurring) ...[
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'monthly',  label: Text(AppStrings.tr('monthly'))),
                ButtonSegment(value: 'quarterly', label: Text(AppStrings.tr('quarterly'))),
                ButtonSegment(value: 'yearly',   label: Text(AppStrings.tr('yearly'))),
              ],
              selected: {_recurrenceInterval ?? 'monthly'},
              onSelectionChanged: (s) => setState(() => _recurrenceInterval = s.first),
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 8)),
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Attachments
          Row(children: [
            Text(AppStrings.tr('attachments'), style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            TextButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.attach_file, size: 18),
              label: Text(AppStrings.tr('add')),
            ),
          ]),
          if (_attachments.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
              child: Text(AppStrings.tr('no_attachment'), style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _attachments.asMap().entries.map((entry) {
                final i   = entry.key;
                final raw = entry.value;
                final ext = raw.split(':').first.toLowerCase();
                return _AttachmentChip(
                  index: i,
                  isPdf: ext == 'pdf',
                  raw: raw,
                  onRemove: () => _removeAttachment(i),
                );
              }).toList(),
            ),
          const SizedBox(height: 24),

          // Save button
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
            label: Text(_saving ? AppStrings.tr('saving') : AppStrings.tr('save')),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final amount = double.parse(_amountCtrl.text.replaceAll(',', '.'));
    final tx = Transaction(
      id:          widget.existing?.id,
      bookId:      widget.bookId,
      categoryId:  _selectedCategory!.id!,
      title:       _titleCtrl.text.trim(),
      amount:      amount,
      type:        _type,
      date:        _date,
      note:        _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      attachments: _attachments,
      paymentMode: _paymentMode,
      contact:     _contactCtrl.text.trim().isEmpty ? null : _contactCtrl.text.trim(),
      isRecurring: _isRecurring,
      recurrenceInterval: _isRecurring ? _recurrenceInterval : null,
    );
    try {
      if (widget.existing == null) {
        await PbService.instance.insertTransaction(tx);
      } else {
        await PbService.instance.updateTransaction(tx);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.tr('error')}: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _AttachmentChip extends StatelessWidget {
  final int index;
  final bool isPdf;
  final String raw;
  final VoidCallback onRemove;

  const _AttachmentChip({required this.index, required this.isPdf, required this.raw, required this.onRemove});

  Uint8List get _bytes => base64Decode(raw.substring(raw.indexOf(':') + 1));

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPreview(context),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: isPdf ? Colors.red.shade50 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: isPdf
                ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.picture_as_pdf, color: Colors.red.shade400, size: 28),
                    Text(AppStrings.tr('pdf'), style: const TextStyle(fontSize: 11)),
                  ])
                : ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(_bytes, fit: BoxFit.cover)),
          ),
          Positioned(
            top: -6, right: -6,
            child: GestureDetector(
              onTap: onRemove,
              child: const CircleAvatar(
                radius: 10, backgroundColor: Colors.red,
                child: Icon(Icons.close, size: 12, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPreview(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: isPdf
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.picture_as_pdf, size: 80, color: Colors.red.shade400),
                  const SizedBox(height: 12),
                  Text(AppStrings.tr('pdf_attachment'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('${(_bytes.length / 1024).toStringAsFixed(1)} KB'),
                ]),
              )
            : Image.memory(_bytes),
      ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
