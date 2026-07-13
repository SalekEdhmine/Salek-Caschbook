import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_strings.dart';
import '../models/member.dart';
import '../models/book.dart';
import '../services/pb_service.dart';

final membersProvider = FutureProvider.family<List<Member>, String>((ref, bookId) {
  return PbService.instance.getMembers(bookId);
});

class MembersScreen extends ConsumerWidget {
  final Book book;
  /// false, wenn diese Ansicht bereits als Tab in einem anderen Bildschirm
  /// (mit eigener AppBar/Zurück-Pfeil) eingebettet ist – verhindert einen
  /// doppelten Zurück-Pfeil.
  final bool showAppBar;
  const MembersScreen({super.key, required this.book, this.showAppBar = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(membersProvider(book.id!));

    final body = membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${AppStrings.tr('error')}: $e')),
        data: (members) {
          if (members.isEmpty) {
            return Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.group_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text(AppStrings.tr('no_members_title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(AppStrings.tr('no_members_body'), textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
              ],
            ));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: members.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (_, i) => _MemberTile(
              member: members[i],
              onEdit: () => _showMemberForm(context, ref, members[i]),
              onDelete: () => _confirmDelete(context, ref, members[i]),
            ),
          );
        },
      );

    return Scaffold(
      appBar: showAppBar ? AppBar(title: Text(AppStrings.tr('members_title').replaceAll('{book}', book.name))) : null,
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showMemberForm(context, ref, null),
        icon: const Icon(Icons.person_add),
        label: Text(AppStrings.tr('invite_member')),
      ),
    );
  }

  void _showMemberForm(BuildContext context, WidgetRef ref, Member? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MemberForm(
        bookId: book.id!,
        existing: existing,
        onSave: (m) async {
          if (existing == null) {
            await PbService.instance.insertMember(m);
          } else {
            await PbService.instance.updateMember(m);
          }
          ref.invalidate(membersProvider(book.id!));
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Member m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppStrings.tr('remove_member_confirm').replaceAll('{name}', m.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppStrings.tr('cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppStrings.tr('remove')),
          ),
        ],
      ),
    );
    if (ok == true && m.id != null) {
      await PbService.instance.deleteMember(m.id!);
      ref.invalidate(membersProvider(book.id!));
    }
  }
}

class _MemberTile extends StatelessWidget {
  final Member member;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MemberTile({required this.member, required this.onEdit, required this.onDelete});

  Color get _roleColor {
    switch (member.role) {
      case MemberRole.primaryAdmin: return Colors.purple.shade700;
      case MemberRole.admin:        return Colors.amber.shade700;
      case MemberRole.employee:     return Colors.blue.shade600;
      case MemberRole.dataOperator: return Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) => ListTile(
        leading: CircleAvatar(
          backgroundColor: _roleColor.withValues(alpha: 0.12),
          child: Text(
            member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
            style: TextStyle(color: _roleColor, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(member.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(member.email),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Chip(
              label: Text(member.role.label, style: TextStyle(color: _roleColor, fontSize: 12)),
              backgroundColor: _roleColor.withValues(alpha: 0.1),
              padding: EdgeInsets.zero,
            ),
            PopupMenuButton(
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit',   child: ListTile(leading: const Icon(Icons.edit),                                                title: Text(AppStrings.tr('change_role')))),
                PopupMenuItem(value: 'delete', child: ListTile(leading: const Icon(Icons.remove_circle_outline, color: Colors.red), title: Text(AppStrings.tr('remove'), style: const TextStyle(color: Colors.red)))),
              ],
              onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
            ),
          ],
        ),
      );
}

class _MemberForm extends StatefulWidget {
  final String bookId;
  final Member? existing;
  final Future<void> Function(Member) onSave;

  const _MemberForm({required this.bookId, this.existing, required this.onSave});

  @override
  State<_MemberForm> createState() => _MemberFormState();
}

class _MemberFormState extends State<_MemberForm> {
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  MemberRole _role = MemberRole.dataOperator;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _nameCtrl.text  = widget.existing!.name;
      _emailCtrl.text = widget.existing!.email;
      _role           = widget.existing!.role;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.existing == null ? AppStrings.tr('invite_member') : AppStrings.tr('edit_role'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            decoration: InputDecoration(labelText: AppStrings.tr('name'), border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailCtrl,
            decoration: InputDecoration(labelText: AppStrings.tr('email_field'), border: const OutlineInputBorder()),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<MemberRole>(
            value: _role,
            decoration: InputDecoration(labelText: AppStrings.tr('role_field'), border: const OutlineInputBorder()),
            items: MemberRole.values.map((r) => DropdownMenuItem(
              value: r,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(r.label),
                  Text(r.description, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            )).toList(),
            onChanged: (v) => setState(() => _role = v!),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: Text(_saving ? AppStrings.tr('saving') : AppStrings.tr('save')),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    await widget.onSave(Member(
      id: widget.existing?.id,
      bookId: widget.bookId,
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      role: _role,
    ));
    if (mounted) Navigator.pop(context);
  }
}
