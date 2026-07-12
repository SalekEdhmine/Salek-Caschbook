class Book {
  final String? id;
  final String businessId;
  final String name;
  final String? description;
  final int colorValue;
  final String icon;
  final double initialBalance;
  final String currency;
  final String? logo;
  final DateTime? createdAt;

  const Book({
    this.id,
    required this.businessId,
    required this.name,
    this.description,
    this.colorValue = 0xFF4CAF50,
    this.icon = 'menu_book',
    this.initialBalance = 0.0,
    this.currency = 'EUR',
    this.logo,
    this.createdAt,
  });

  factory Book.fromMap(Map<String, dynamic> m) => Book(
        id: m['id'] as String?,
        businessId: m['businessId'] as String,
        name: m['name'] as String,
        description: m['description'] as String?,
        colorValue: (m['colorValue'] as num?)?.toInt() ?? 0xFF4CAF50,
        icon: m['icon'] as String? ?? 'menu_book',
        initialBalance: (m['initialBalance'] as num?)?.toDouble() ?? 0.0,
        currency: m['currency'] as String? ?? 'EUR',
        logo: m['logo'] as String?,
        createdAt: m['created'] != null ? DateTime.tryParse(m['created'] as String) : null,
      );

  Book copyWith({
    String? id, String? businessId, String? name, String? description,
    int? colorValue, String? icon, double? initialBalance,
    String? currency, String? logo, DateTime? createdAt,
  }) =>
      Book(
        id: id ?? this.id,
        businessId: businessId ?? this.businessId,
        name: name ?? this.name,
        description: description ?? this.description,
        colorValue: colorValue ?? this.colorValue,
        icon: icon ?? this.icon,
        initialBalance: initialBalance ?? this.initialBalance,
        currency: currency ?? this.currency,
        logo: logo ?? this.logo,
        createdAt: createdAt ?? this.createdAt,
      );
}
