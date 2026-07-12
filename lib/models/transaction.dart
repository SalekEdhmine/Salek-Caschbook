import 'dart:convert';
import 'category.dart';

class Transaction {
  final String? id;
  final String bookId;
  final String categoryId;
  final String title;
  final double amount;
  final TransactionType type;
  final DateTime date;
  final String? note;
  final List<String> attachments;
  final String? categoryName;
  final String? categoryIcon;
  final int? categoryColor;
  final String? paymentMode;
  final String? contact;
  final bool isRecurring;
  final String? recurrenceInterval;
  final String? externalRef;
  final DateTime? createdAt;

  const Transaction({
    this.id,
    required this.bookId,
    required this.categoryId,
    required this.title,
    required this.amount,
    required this.type,
    required this.date,
    this.note,
    this.attachments = const [],
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
    this.paymentMode,
    this.contact,
    this.isRecurring = false,
    this.recurrenceInterval,
    this.externalRef,
    this.createdAt,
  });

  factory Transaction.fromMap(Map<String, dynamic> m) {
    List<String> attachments = [];
    final raw = m['attachments'];
    if (raw != null && raw.toString().isNotEmpty && raw.toString() != 'null') {
      try { attachments = List<String>.from(jsonDecode(raw.toString())); } catch (_) {}
    }
    return Transaction(
      id: m['id'] as String?,
      bookId: m['bookId'] as String,
      categoryId: m['categoryId'] as String? ?? '',
      title: m['title'] as String? ?? '',
      amount: (m['amount'] as num).toDouble(),
      type: TransactionType.values.firstWhere(
        (e) => e.name == m['type'], orElse: () => TransactionType.expense),
      date: DateTime.parse(m['date'] as String),
      note: m['note'] as String?,
      attachments: attachments,
      categoryName: m['categoryName'] as String?,
      categoryIcon: m['categoryIcon'] as String?,
      categoryColor: (m['categoryColor'] as num?)?.toInt(),
      paymentMode: m['payment_mode'] as String?,
      contact: m['contact'] as String?,
      isRecurring: (m['is_recurring'] as bool?) ?? false,
      recurrenceInterval: m['recurrence_interval'] as String?,
      externalRef: m['external_ref'] as String?,
      createdAt: m['created'] != null ? DateTime.tryParse(m['created'] as String) : null,
    );
  }

  Transaction copyWith({
    String? id, String? bookId, String? categoryId, String? title,
    double? amount, TransactionType? type, DateTime? date,
    String? note, List<String>? attachments,
    String? paymentMode, String? contact, bool? isRecurring,
    String? recurrenceInterval, String? externalRef,
  }) => Transaction(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    categoryId: categoryId ?? this.categoryId,
    title: title ?? this.title,
    amount: amount ?? this.amount,
    type: type ?? this.type,
    date: date ?? this.date,
    note: note ?? this.note,
    attachments: attachments ?? this.attachments,
    categoryName: categoryName,
    categoryIcon: categoryIcon,
    categoryColor: categoryColor,
    paymentMode: paymentMode ?? this.paymentMode,
    contact: contact ?? this.contact,
    isRecurring: isRecurring ?? this.isRecurring,
    recurrenceInterval: recurrenceInterval ?? this.recurrenceInterval,
    externalRef: externalRef ?? this.externalRef,
    createdAt: createdAt,
  );
}
