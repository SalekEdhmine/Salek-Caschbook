class Business {
  final String? id;
  final String name;
  final String? description;
  final int colorValue;
  final String icon;
  final String currency;
  final String? logo;
  final String? address;
  final String? phone;
  final String? email;
  final String? businessType;
  final String? registrationType;
  final int? employeeCount;
  final String? businessCategory;

  const Business({
    this.id,
    required this.name,
    this.description,
    this.colorValue = 0xFF1976D2,
    this.icon = 'business',
    this.currency = 'EUR',
    this.logo,
    this.address,
    this.phone,
    this.email,
    this.businessType,
    this.registrationType,
    this.employeeCount,
    this.businessCategory,
  });

  double get profileStrength {
    int filled = 0;
    const total = 10;
    if (name.isNotEmpty) filled++;
    if (description != null && description!.isNotEmpty) filled++;
    if (logo != null && logo!.isNotEmpty) filled++;
    if (address != null && address!.isNotEmpty) filled++;
    if (phone != null && phone!.isNotEmpty) filled++;
    if (email != null && email!.isNotEmpty) filled++;
    if (businessType != null && businessType!.isNotEmpty) filled++;
    if (registrationType != null && registrationType!.isNotEmpty) filled++;
    if (employeeCount != null && employeeCount! > 0) filled++;
    if (businessCategory != null && businessCategory!.isNotEmpty) filled++;
    return filled / total;
  }

  String get profileStrengthLabel {
    final p = profileStrength;
    if (p < 0.3) return 'Niedrig';
    if (p < 0.7) return 'Mittel';
    return 'Hoch';
  }

  factory Business.fromMap(Map<String, dynamic> m) => Business(
        id: m['id'] as String?,
        name: m['name'] as String,
        description: m['description'] as String?,
        colorValue: (m['colorValue'] as num?)?.toInt() ?? 0xFF1976D2,
        icon: m['icon'] as String? ?? 'business',
        currency: m['currency'] as String? ?? 'EUR',
        logo: m['logo'] as String?,
        address: m['address'] as String?,
        phone: m['phone'] as String?,
        email: m['email'] as String?,
        businessType: m['business_type'] as String?,
        registrationType: m['registration_type'] as String?,
        employeeCount: (m['employee_count'] as num?)?.toInt(),
        businessCategory: m['business_category'] as String?,
      );

  Business copyWith({
    String? id, String? name, String? description,
    int? colorValue, String? icon, String? currency, String? logo,
    String? address, String? phone, String? email,
    String? businessType, String? registrationType,
    int? employeeCount, String? businessCategory,
  }) =>
      Business(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        colorValue: colorValue ?? this.colorValue,
        icon: icon ?? this.icon,
        currency: currency ?? this.currency,
        logo: logo ?? this.logo,
        address: address ?? this.address,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        businessType: businessType ?? this.businessType,
        registrationType: registrationType ?? this.registrationType,
        employeeCount: employeeCount ?? this.employeeCount,
        businessCategory: businessCategory ?? this.businessCategory,
      );
}
