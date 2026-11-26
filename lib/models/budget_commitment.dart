class BudgetCommitment {
  final String id;
  final String name; // e.g., "Renta", "Internet", "Netflix", "Gimnasio"
  final double amount;
  final int dueDay; // Day of month (1-31)
  final String category;
  final String accountId; // Linked account or credit card
  final bool isPaidThisMonth;
  final bool isAutopay; // Pago domiciliado (cargo automático)

  const BudgetCommitment({
    required this.id,
    required this.name,
    required this.amount,
    required this.dueDay,
    required this.category,
    required this.accountId,
    this.isPaidThisMonth = false,
    this.isAutopay = false,
  });

  BudgetCommitment copyWith({
    String? id,
    String? name,
    double? amount,
    int? dueDay,
    String? category,
    String? accountId,
    bool? isPaidThisMonth,
    bool? isAutopay,
  }) {
    return BudgetCommitment(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      dueDay: dueDay ?? this.dueDay,
      category: category ?? this.category,
      accountId: accountId ?? this.accountId,
      isPaidThisMonth: isPaidThisMonth ?? this.isPaidThisMonth,
      isAutopay: isAutopay ?? this.isAutopay,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'amount': amount,
    'dueDay': dueDay,
    'category': category,
    'accountId': accountId,
    'isPaidThisMonth': isPaidThisMonth,
    'isAutopay': isAutopay,
  };

  factory BudgetCommitment.fromJson(Map<String, dynamic> json) => BudgetCommitment(
    id: json['id'] as String,
    name: json['name'] as String,
    amount: (json['amount'] as num).toDouble(),
    dueDay: json['dueDay'] as int,
    category: json['category'] as String,
    accountId: json['accountId'] as String,
    isPaidThisMonth: json['isPaidThisMonth'] as bool? ?? false,
    isAutopay: json['isAutopay'] as bool? ?? false,
  );
}

