import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import '../models/business.dart';
import '../providers/app_providers.dart';
import '../services/pb_service.dart';
import '../utils/formatters.dart';

const _colors = [
  0xFF1976D2, 0xFF388E3C, 0xFFE64A19, 0xFF7B1FA2,
  0xFF0097A7, 0xFFF57C00, 0xFFE91E63, 0xFF00897B,
];

const _businessTypes = ['Einzelunternehmen', 'GmbH', 'UG', 'AG', 'KG', 'OHG', 'Freiberufler', 'Sonstiges'];
const _businessCategories = ['Einzelhandel', 'Gastronomie', 'Dienstleistung', 'IT', 'Handwerk', 'Landwirtschaft', 'Freiberuf', 'Bildung', 'Gesundheit', 'Sonstiges'];

class BusinessSettingsScreen extends ConsumerStatefulWidget {
  final Business business;
  const BusinessSettingsScreen({super.key, required this.business});

  @override
  ConsumerState<BusinessSettingsScreen> createState() => _BusinessSettingsScreenState();
}

class _BusinessSettingsScreenState extends ConsumerState<BusinessSettingsScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  String  _currency = 'EUR';
  int     _color = 0xFF1976D2;
  String? _logo;
  String? _businessType;
  String? _registrationType;
  int?    _employeeCount;
  String? _businessCategory;
  bool    _saving = false;

  @override
  void initState() {
    super.initState();
    final b = widget.business;
    _nameCtrl = TextEditingController(text: b.name);
    _descCtrl = TextEditingController(text: b.description ?? '');
    _addressCtrl = TextEditingController(text: b.address ?? '');
    _phoneCtrl = TextEditingController(text: b.phone ?? '');
    _emailCtrl = TextEditingController(text: b.email ?? '');
    _currency = b.currency;
    _color = b.colorValue;
    _logo = b.logo;
    _businessType = b.businessType;
    _registrationType = b.registrationType;
    _employeeCount = b.employeeCount;
    _businessCategory = b.businessCategory;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image, withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) return;
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return;
    final resized = img.copyResize(decoded, width: decoded.width > decoded.height ? 128 : -1, height: decoded.height >= decoded.width ? 128 : -1);
    final jpeg = img.encodeJpg(resized, quality: 80);
    setState(() => _logo = base64Encode(Uint8List.fromList(jpeg)));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final updated = widget.business.copyWith(
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      colorValue: _color,
      currency: _currency,
      logo: _logo,
      address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      businessType: _businessType,
      registrationType: _registrationType,
      employeeCount: _employeeCount,
      businessCategory: _businessCategory,
    );
    try {
      await PbService.instance.updateBusiness(updated);
      ref.invalidate(businessesProvider);
      ref.read(selectedBusinessProvider.notifier).state = updated;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gespeichert')));
        Navigator.pop(context, updated);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteBusiness() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Business löschen?'),
        content: const Text('Alle Bücher, Buchungen und Daten werden unwiderruflich gelöscht.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (ok == true) {
      try {
        await PbService.instance.deleteBusiness(widget.business.id!);
        ref.invalidate(businessesProvider);
        ref.read(selectedBusinessProvider.notifier).state = null;
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pct = widget.business.profileStrength;
    final pctLabel = widget.business.profileStrengthLabel;

    return Scaffold(
      appBar: AppBar(title: const Text('Business-Einstellungen'), actions: [
        TextButton(onPressed: _saving ? null : _save, child: _saving
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Speichern')),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [

        // Profile strength
        Card(
          child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            Row(children: [
              SizedBox(
                width: 48, height: 48,
                child: Stack(fit: StackFit.expand, children: [
                  CircularProgressIndicator(
                    value: pct, strokeWidth: 4,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(pct < 0.3 ? Colors.red : pct < 0.7 ? Colors.orange : Colors.green),
                  ),
                  Center(child: Text('${(pct * 100).toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                ]),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Profilstärke', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('$pctLabel – ${(pct * 100).toInt()}% ausgefüllt', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ])),
            ]),
          ])),
        ),
        const SizedBox(height: 16),

        // Logo + Name section
        Center(
          child: GestureDetector(
            onTap: _pickLogo,
            child: Stack(children: [
              Container(
                width: 88, height: 88,
                decoration: BoxDecoration(
                  color: Color(_color).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Color(_color).withValues(alpha: 0.3)),
                ),
                child: _logo != null
                    ? ClipRRect(borderRadius: BorderRadius.circular(21),
                        child: Image.memory(base64Decode(_logo!), fit: BoxFit.cover))
                    : Icon(Icons.business_rounded, color: Color(_color), size: 44),
              ),
              Positioned(right: 0, bottom: 0, child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(color: Color(_color), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
              )),
            ]),
          ),
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _nameCtrl,
          decoration: const InputDecoration(labelText: 'Name *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.business)),
          validator: (v) => v == null || v.trim().isEmpty ? 'Name eingeben' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Beschreibung', border: OutlineInputBorder(), prefixIcon: Icon(Icons.description)), maxLines: 2),
        const SizedBox(height: 12),

        // Currency
        DropdownButtonFormField<String>(
          value: _currency,
          decoration: const InputDecoration(labelText: 'Währung', border: OutlineInputBorder(), prefixIcon: Icon(Icons.monetization_on_outlined)),
          items: ['EUR', 'USD', 'GBP', 'CHF', 'TRY', 'INR', 'DZD', 'MAD', 'SAR', 'MRU'].map((c) => DropdownMenuItem(value: c, child: Text('$c ${currencySymbol(c)}'))).toList(),
          onChanged: (v) => setState(() => _currency = v!),
        ),
        const SizedBox(height: 12),

        // Color picker
        const Text('Farbe', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: _colors.map((c) => GestureDetector(
          onTap: () => setState(() => _color = c),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Color(c), shape: BoxShape.circle,
              border: _color == c ? Border.all(color: Colors.white, width: 3) : null,
              boxShadow: _color == c ? [BoxShadow(color: Color(c).withValues(alpha: 0.4), blurRadius: 8)] : null,
            ),
          ),
        )).toList()),
        const SizedBox(height: 20),

        // Extended business fields
        const Divider(),
        const SizedBox(height: 8),
        Text('Geschäftsinformationen', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.grey.shade700)),
        const SizedBox(height: 12),

        TextFormField(controller: _addressCtrl, decoration: const InputDecoration(labelText: 'Adresse', border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_on_outlined))),
        const SizedBox(height: 12),
        TextFormField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Telefon', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone_outlined)), keyboardType: TextInputType.phone),
        const SizedBox(height: 12),
        TextFormField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'E-Mail', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email_outlined)), keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 12),

        DropdownButtonFormField<String>(
          value: _businessType,
          decoration: const InputDecoration(labelText: 'Geschäftstyp', border: OutlineInputBorder(), prefixIcon: Icon(Icons.category_outlined)),
          items: [const DropdownMenuItem(value: null, child: Text('Nicht angegeben')), ..._businessTypes.map((t) => DropdownMenuItem(value: t, child: Text(t)))],
          onChanged: (v) => setState(() => _businessType = v),
        ),
        const SizedBox(height: 12),

        DropdownButtonFormField<String>(
          value: _businessCategory,
          decoration: const InputDecoration(labelText: 'Branche', border: OutlineInputBorder(), prefixIcon: Icon(Icons.grid_view_outlined)),
          items: [const DropdownMenuItem(value: null, child: Text('Nicht angegeben')), ..._businessCategories.map((c) => DropdownMenuItem(value: c, child: Text(c)))],
          onChanged: (v) => setState(() => _businessCategory = v),
        ),
        const SizedBox(height: 12),

        DropdownButtonFormField<String>(
          value: _registrationType,
          decoration: const InputDecoration(labelText: 'Registrierungstyp', border: OutlineInputBorder(), prefixIcon: Icon(Icons.assignment_outlined)),
          items: [const DropdownMenuItem(value: null, child: Text('Nicht angegeben')), ..._businessTypes.map((t) => DropdownMenuItem(value: t, child: Text(t)))],
          onChanged: (v) => setState(() => _registrationType = v),
        ),
        const SizedBox(height: 12),

        TextFormField(
          initialValue: _employeeCount?.toString() ?? '',
          decoration: const InputDecoration(labelText: 'Mitarbeiterzahl', border: OutlineInputBorder(), prefixIcon: Icon(Icons.people_outline), helperText: 'Optional'),
          keyboardType: TextInputType.number,
          onChanged: (v) => setState(() => _employeeCount = int.tryParse(v)),
        ),
        const SizedBox(height: 24),

        // Danger zone
        const Divider(),
        const SizedBox(height: 8),
        Text('Gefahrenzone', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.red.shade700)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.delete_forever_outlined, color: Colors.red),
          label: const Text('Business löschen', style: TextStyle(color: Colors.red)),
          style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.red.shade200)),
          onPressed: _deleteBusiness,
        ),
        const SizedBox(height: 32),
      ]),
    );
  }
}
