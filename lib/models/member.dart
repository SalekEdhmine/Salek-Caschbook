enum MemberRole { primaryAdmin, admin, employee, dataOperator }

extension MemberRoleX on MemberRole {
  String get pbValue {
    switch (this) {
      case MemberRole.primaryAdmin:  return 'primaryAdmin';
      case MemberRole.admin:         return 'admin';
      case MemberRole.employee:      return 'employee';
      case MemberRole.dataOperator:  return 'dataOperator';
    }
  }

  String get label {
    switch (this) {
      case MemberRole.primaryAdmin:  return 'Haupt-Admin';
      case MemberRole.admin:         return 'Admin';
      case MemberRole.employee:      return 'Mitarbeiter';
      case MemberRole.dataOperator:  return 'Dateneingabe';
    }
  }

  String get description {
    switch (this) {
      case MemberRole.primaryAdmin:  return 'Vollzugriff – alles bearbeiten & löschen';
      case MemberRole.admin:         return 'Mitglieder & Buchungen verwalten';
      case MemberRole.employee:      return 'Buchungen hinzufügen & bearbeiten';
      case MemberRole.dataOperator:  return 'Nur Buchungen hinzufügen';
    }
  }

  bool get canEdit    => this == MemberRole.primaryAdmin || this == MemberRole.admin || this == MemberRole.employee;
  bool get canDelete  => this == MemberRole.primaryAdmin || this == MemberRole.admin;
  bool get canManageMembers => this == MemberRole.primaryAdmin || this == MemberRole.admin;

  static MemberRole fromString(String s) {
    switch (s) {
      case 'primaryAdmin': return MemberRole.primaryAdmin;
      case 'admin':        return MemberRole.admin;
      case 'employee':     return MemberRole.employee;
      case 'dataOperator': return MemberRole.dataOperator;
      // Backward compatibility
      case 'owner':   return MemberRole.primaryAdmin;
      case 'editor':  return MemberRole.admin;
      case 'viewer':  return MemberRole.dataOperator;
      default:        return MemberRole.dataOperator;
    }
  }
}

class Member {
  final String? id;
  final String bookId;
  final String name;
  final String email;
  final MemberRole role;

  const Member({
    this.id,
    required this.bookId,
    required this.name,
    required this.email,
    this.role = MemberRole.dataOperator,
  });

  factory Member.fromMap(Map<String, dynamic> m) => Member(
    id: m['id'] as String?,
    bookId: m['bookId'] as String,
    name: m['name'] as String? ?? '',
    email: m['email'] as String,
    role: MemberRoleX.fromString(m['role'] as String? ?? ''),
  );

  String get roleLabel => role.label;
}
