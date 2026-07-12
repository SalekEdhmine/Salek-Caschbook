class Activity {
  final String? id;
  final String bookId;
  final String action;
  final String entityType;
  final String? entityId;
  final String details;
  final String userEmail;
  final String? userName;
  final DateTime createdAt;

  const Activity({
    this.id,
    required this.bookId,
    required this.action,
    required this.entityType,
    this.entityId,
    this.details = '',
    this.userEmail = '',
    this.userName,
    required this.createdAt,
  });

  factory Activity.fromMap(Map<String, dynamic> m, {String? expandUserEmail}) => Activity(
    id: m['id'] as String?,
    bookId: m['book'] as String? ?? '',
    action: m['action'] as String? ?? '',
    entityType: m['entity_type'] as String? ?? '',
    entityId: m['entity_id'] as String?,
    details: m['details'] as String? ?? '',
    userEmail: expandUserEmail ?? (m['user_email'] as String? ?? ''),
    userName: m['user_name'] as String?,
    createdAt: DateTime.tryParse(m['created'] as String? ?? '') ?? DateTime.now(),
  );

  String get actionLabel {
    switch (action) {
      case 'created': return 'erstellt';
      case 'updated': return 'bearbeitet';
      case 'deleted': return 'gelöscht';
      default: return action;
    }
  }

  String get entityLabel {
    switch (entityType) {
      case 'transaction': return 'Buchung';
      case 'book':        return 'Buch';
      case 'member':      return 'Mitglied';
      case 'category':    return 'Kategorie';
      default: return entityType;
    }
  }
}
