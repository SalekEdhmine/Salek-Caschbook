import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import '../l10n/app_strings.dart';
import '../models/business.dart';
import '../providers/app_providers.dart';
import '../services/pb_service.dart';
import '../utils/formatters.dart';

const _colors = [
  0xFF1976D2, 0xFF388E3C, 0xFFE64A19, 0xFF7B1FA2,
  0xFF0097A7, 0xFFF57C00, 0xFFE91E63, 0xFF00897B,
];

// GmbH/UG/AG/KG/OHG sind feststehende deutsche Rechtsformen-Kürzel (wie "LLC"
// oder "SARL" in anderen Rechtssystemen) - bewusst nicht übersetzt.
List<String> _businessTypes() => [
      AppStrings.tr('biz_sole_proprietorship'), 'GmbH', 'UG', 'AG', 'KG', 'OHG',
      AppStrings.tr('biz_freelancer'), AppStrings.tr('biz_other'),
    ];
List<String> _businessCategories() => [
      AppStrings.tr('biz_retail'), AppStrings.tr('biz_hospitality'), AppStrings.tr('biz_services'), 'IT',
      AppStrings.tr('biz_trade'), AppStrings.tr('biz_agriculture'), AppStrings.tr('biz_freelance_cat'),
      AppStrings.tr('biz_education'), AppStrings.tr('biz_health'), AppStrings.tr('biz_other'),
    ];

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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.tr('saved'))));
        Navigator.pop(context, updated);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppStrings.tr('error')}: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteBusiness() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppStrings.tr('delete_business_title')),
        content: Text(AppStrings.tr('delete_business_body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppStrings.tr('cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppStrings.tr('delete'), style: const TextStyle(color: Colors.white))),
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppStrings.tr('error')}: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pct = widget.business.profileStrength;
    final pctLabel = widget.business.profileStrengthLabel;

    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.tr('business_settings_title')), actions: [
        TextButton(onPressed: _saving ? null : _save, child: _saving
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(AppStrings.tr('save'))),
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
                Text(AppStrings.tr('profile_strength'), style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(AppStrings.tr('profile_filled').replaceAll('{label}', pctLabel).replaceAll('{pct}', '${(pct * 100).toInt()}'), style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
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
          decoration: InputDecoration(labelText: '${AppStrings.tr('name')} *', border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.business)),
          validator: (v) => v == null || v.trim().isEmpty ? AppStrings.tr('name_required') : null,
        ),
        const SizedBox(height: 12),
        TextFormField(controller: _descCtrl, decoration: InputDecoration(labelText: AppStrings.tr('description'), border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.description)), maxLines: 2),
        const SizedBox(height: 12),

        // Currency
        DropdownButtonFormField<String>(
          value: _currency,
          decoration: InputDecoration(labelText: AppStrings.tr('currency'), border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.monetization_on_outlined)),
          items: ['EUR', 'USD', 'GBP', 'CHF', 'TRY', 'INR', 'DZD', 'MAD', 'SAR', 'MRU'].map((c) => DropdownMenuItem(value: c, child: Text('$c ${currencySymbol(c)}'))).toList(),
          onChanged: (v) => setState(() => _currency = v!),
        ),
        const SizedBox(height: 12),

        // Color picker
        Text(AppStrings.tr('color'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
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
        Text(AppStrings.tr('business_info'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.grey.shade700)),
        const SizedBox(height: 12),

        TextFormField(controller: _addressCtrl, decoration: InputDecoration(labelText: AppStrings.tr('address_field'), border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.location_on_outlined))),
        const SizedBox(height: 12),
        TextFormField(controller: _phoneCtrl, decoration: InputDecoration(labelText: AppStrings.tr('phone_field'), border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.phone_outlined)), keyboardType: TextInputType.phone),
        const SizedBox(height: 12),
        TextFormField(controller: _emailCtrl, decoration: InputDecoration(labelText: AppStrings.tr('email_field'), border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.email_outlined)), keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 12),

        DropdownButtonFormField<String>(
          value: _businessType,
          decoration: InputDecoration(labelText: AppStrings.tr('business_type_field'), border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.category_outlined)),
          items: [DropdownMenuItem(value: null, child: Text(AppStrings.tr('not_specified'))), ..._businessTypes().map((t) => DropdownMenuItem(value: t, child: Text(t)))],
          onChanged: (v) => setState(() => _businessType = v),
        ),
        const SizedBox(height: 12),

        DropdownButtonFormField<String>(
          value: _businessCategory,
          decoration: InputDecoration(labelText: AppStrings.tr('business_category_field'), border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.grid_view_outlined)),
          items: [DropdownMenuItem(value: null, child: Text(AppStrings.tr('not_specified'))), ..._businessCategories().map((c) => DropdownMenuItem(value: c, child: Text(c)))],
          onChanged: (v) => setState(() => _businessCategory = v),
        ),
        const SizedBox(height: 12),

        DropdownButtonFormField<String>(
          value: _registrationType,
          decoration: InputDecoration(labelText: AppStrings.tr('registration_type_field'), border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.assignment_outlined)),
          items: [DropdownMenuItem(value: null, child: Text(AppStrings.tr('not_specified'))), ..._businessTypes().map((t) => DropdownMenuItem(value: t, child: Text(t)))],
          onChanged: (v) => setState(() => _registrationType = v),
        ),
        const SizedBox(height: 12),

        TextFormField(
          initialValue: _employeeCount?.toString() ?? '',
          decoration: InputDecoration(labelText: AppStrings.tr('employee_count_field'), border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.people_outline), helperText: AppStrings.tr('optional')),
          keyboardType: TextInputType.number,
          onChanged: (v) => setState(() => _employeeCount = int.tryParse(v)),
        ),
        const SizedBox(height: 24),

        // Danger zone
        const Divider(),
        const SizedBox(height: 8),
        Text(AppStrings.tr('danger_zone'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.red.shade700)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.delete_forever_outlined, color: Colors.red),
          label: Text(AppStrings.tr('delete_business_button'), style: const TextStyle(color: Colors.red)),
          style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.red.shade200)),
          onPressed: _deleteBusiness,
        ),
        const SizedBox(height: 32),
      ]),
    );
  }
}
