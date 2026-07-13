class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final String? transactionId;
  final String? bookId;
  final bool read;
  final DateTime? created;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.transactionId,
    this.bookId,
    this.read = false,
    this.created,
  });

  factory AppNotification.fromMap(Map<String, dynamic> m) => AppNotification(
        id: m['id'] as String? ?? '',
        title: m['title'] as String? ?? '',
        body: m['body'] as String? ?? '',
        type: m['type'] as String? ?? '',
        transactionId: (m['transaction_id'] as String?)?.isNotEmpty == true ? m['transaction_id'] as String : null,
        bookId: (m['book_id'] as String?)?.isNotEmpty == true ? m['book_id'] as String : null,
        read: m['read'] as bool? ?? false,
        created: DateTime.tryParse(m['created'] as String? ?? ''),
      );
}
