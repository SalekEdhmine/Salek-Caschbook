import '../l10n/app_strings.dart';

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
      case 'created': return AppStrings.tr('activity_created');
      case 'updated': return AppStrings.tr('activity_updated');
      case 'deleted': return AppStrings.tr('activity_deleted');
      default: return action;
    }
  }

  String get entityLabel {
    switch (entityType) {
      case 'transaction': return AppStrings.tr('entity_transaction');
      case 'book':        return AppStrings.tr('entity_book');
      case 'member':      return AppStrings.tr('entity_member');
      case 'category':    return AppStrings.tr('entity_category');
      default: return entityType;
    }
  }
}
