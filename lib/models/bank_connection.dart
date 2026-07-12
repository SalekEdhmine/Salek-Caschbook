class BankAspsp {
  final String name;
  final String country;
  final String? logo;
  final String? bic;

  const BankAspsp({required this.name, required this.country, this.logo, this.bic});

  factory BankAspsp.fromMap(Map<String, dynamic> m) => BankAspsp(
        name: m['name'] as String? ?? '',
        country: m['country'] as String? ?? '',
        logo: m['logo'] as String?,
        bic: m['bic'] as String?,
      );
}

class BankAccount {
  final String uid;
  final String? iban;
  final String? name;
  final String? currency;
  final String? defaultBookId;

  const BankAccount({required this.uid, this.iban, this.name, this.currency, this.defaultBookId});

  factory BankAccount.fromMap(Map<String, dynamic> m) => BankAccount(
        uid: m['uid'] as String? ?? '',
        iban: m['iban'] as String?,
        name: m['name'] as String?,
        currency: m['currency'] as String?,
        defaultBookId: m['default_book'] as String?,
      );
}

class BankConnection {
  final String id;
  final String aspspName;
  final String aspspCountry;
  final String status;
  final DateTime? validUntil;
  final List<BankAccount> accounts;

  const BankConnection({
    required this.id,
    required this.aspspName,
    required this.aspspCountry,
    required this.status,
    this.validUntil,
    this.accounts = const [],
  });

  factory BankConnection.fromMap(Map<String, dynamic> m) => BankConnection(
        id: m['id'] as String? ?? '',
        aspspName: m['aspsp_name'] as String? ?? '',
        aspspCountry: m['aspsp_country'] as String? ?? '',
        status: m['status'] as String? ?? 'active',
        validUntil: (m['valid_until'] as String?)?.isNotEmpty == true
            ? DateTime.tryParse(m['valid_until'] as String)
            : null,
        accounts: ((m['accounts'] as List?) ?? const [])
            .map((a) => BankAccount.fromMap(Map<String, dynamic>.from(a as Map)))
            .toList(),
      );
}

/// Ein Umsatz von Enable Banking, angereichert um die Dedup-Info, die der
/// Backend-Dienst mitliefert (`_external_ref`/`_already_imported`).
class BankTransaction {
  final String externalRef;
  final DateTime date;
  final double amount;
  final bool isCredit;
  final String? counterparty;
  final String? remittanceInfo;
  final bool alreadyImported;

  const BankTransaction({
    required this.externalRef,
    required this.date,
    required this.amount,
    required this.isCredit,
    this.counterparty,
    this.remittanceInfo,
    this.alreadyImported = false,
  });

  factory BankTransaction.fromMap(Map<String, dynamic> m) {
    final indicator = m['credit_debit_indicator'] as String? ?? 'DBIT';
    final isCredit = indicator == 'CRDT';
    final counterpartyMap = (isCredit ? m['debtor'] : m['creditor']) as Map?;
    final remittanceList = m['remittance_information'] as List?;
    final remittance = remittanceList?.join(' ').trim();
    final amountMap = m['transaction_amount'] as Map?;
    return BankTransaction(
      externalRef: m['_external_ref'] as String? ?? m['transaction_id'] as String? ?? '',
      date: DateTime.tryParse(m['booking_date'] as String? ?? '') ?? DateTime.now(),
      amount: double.tryParse('${amountMap?['amount'] ?? 0}') ?? 0,
      isCredit: isCredit,
      counterparty: counterpartyMap?['name'] as String?,
      remittanceInfo: (remittance?.isNotEmpty ?? false) ? remittance : null,
      alreadyImported: m['_already_imported'] as bool? ?? false,
    );
  }
}
