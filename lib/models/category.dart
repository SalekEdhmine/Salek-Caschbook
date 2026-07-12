enum TransactionType { income, expense }

class Category {
  final String? id;
  final String name;
  final String icon;
  final int colorValue;
  final TransactionType type;

  const Category({
    this.id,
    required this.name,
    required this.icon,
    required this.colorValue,
    required this.type,
  });

  factory Category.fromMap(Map<String, dynamic> map) => Category(
        id: map['id'] as String?,
        name: map['name'] as String,
        icon: map['icon'] as String,
        colorValue: (map['colorValue'] as num?)?.toInt() ?? 0xFF9E9E9E,
        type: TransactionType.values.firstWhere(
          (e) => e.name == map['type'],
          orElse: () => TransactionType.expense,
        ),
      );

  Category copyWith({String? id, String? name, String? icon, int? colorValue, TransactionType? type}) =>
      Category(
        id: id ?? this.id,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        colorValue: colorValue ?? this.colorValue,
        type: type ?? this.type,
      );
}

const List<Category> defaultCategories = [
  Category(name: 'Gehalt',         icon: 'payments',              colorValue: 0xFF4CAF50, type: TransactionType.income),
  Category(name: 'Nebeneinkommen', icon: 'work',                  colorValue: 0xFF8BC34A, type: TransactionType.income),
  Category(name: 'Zinsen',         icon: 'trending_up',           colorValue: 0xFF009688, type: TransactionType.income),
  Category(name: 'Sonstiges',      icon: 'add_circle',            colorValue: 0xFF00BCD4, type: TransactionType.income),
  Category(name: 'Lebensmittel',   icon: 'local_grocery_store',   colorValue: 0xFFF44336, type: TransactionType.expense),
  Category(name: 'Wohnen',         icon: 'home',                  colorValue: 0xFF9C27B0, type: TransactionType.expense),
  Category(name: 'Transport',      icon: 'directions_car',        colorValue: 0xFF3F51B5, type: TransactionType.expense),
  Category(name: 'Gesundheit',     icon: 'local_hospital',        colorValue: 0xFFE91E63, type: TransactionType.expense),
  Category(name: 'Freizeit',       icon: 'sports_esports',        colorValue: 0xFFFF9800, type: TransactionType.expense),
  Category(name: 'Restaurant',     icon: 'restaurant',            colorValue: 0xFFFF5722, type: TransactionType.expense),
  Category(name: 'Kleidung',       icon: 'checkroom',             colorValue: 0xFF795548, type: TransactionType.expense),
  Category(name: 'Bildung',        icon: 'school',                colorValue: 0xFF607D8B, type: TransactionType.expense),
  Category(name: 'Sonstiges',      icon: 'more_horiz',            colorValue: 0xFF9E9E9E, type: TransactionType.expense),
];
