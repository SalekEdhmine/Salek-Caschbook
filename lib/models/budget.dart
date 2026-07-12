class Budget {
  final String? id;
  final String bookId;
  final String categoryId;
  final String? categoryName;
  final String? categoryIcon;
  final int? categoryColor;
  final double amount;
  final String period;

  const Budget({
    this.id,
    required this.bookId,
    required this.categoryId,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
    required this.amount,
    this.period = 'monthly',
  });

  factory Budget.fromMap(Map<String, dynamic> m) => Budget(
    id: m['id'] as String?,
    bookId: m['bookId'] as String,
    categoryId: m['categoryId'] as String,
    categoryName: m['categoryName'] as String?,
    categoryIcon: m['categoryIcon'] as String?,
    categoryColor: (m['categoryColor'] as num?)?.toInt(),
    amount: (m['amount'] as num).toDouble(),
    period: m['period'] as String? ?? 'monthly',
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'bookId': bookId,
    'categoryId': categoryId,
    'categoryName': categoryName,
    'categoryIcon': categoryIcon,
    'categoryColor': categoryColor,
    'amount': amount,
    'period': period,
  };

  Budget copyWith({
    String? id, String? bookId, String? categoryId,
    String? categoryName, String? categoryIcon, int? categoryColor,
    double? amount, String? period,
  }) => Budget(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    categoryId: categoryId ?? this.categoryId,
    categoryName: categoryName ?? this.categoryName,
    categoryIcon: categoryIcon ?? this.categoryIcon,
    categoryColor: categoryColor ?? this.categoryColor,
    amount: amount ?? this.amount,
    period: period ?? this.period,
  );
}
