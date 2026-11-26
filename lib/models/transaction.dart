enum MovementType {
  expense,
  income,
  transfer,
  yieldAccrual, // Rendimiento / interés generado
}

class Transaction {
  final String id;
  final String title;
  final double amount; // Always positive
  final MovementType type;
  final String category; // e.g. "Comida", "Transporte", "Sueldo", "Rendimientos"
  final String accountId; // Source account ID
  final String? targetAccountId; // Target account ID (for transfers)
  final DateTime date;
  final DateTime? billingDate; // Optional posting/billing period override
  final bool balanceApplied; // False when imported/backfilled with skipBalanceUpdate
  final String? note;
  final bool isRecurring;
  final String? linkedOccurrenceId;
  final String? sourceTransactionId;
  final String? savingsRuleId;

  const Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.accountId,
    this.targetAccountId,
    required this.date,
    this.billingDate,
    this.balanceApplied = true,
    this.note,
    this.isRecurring = false,
    this.linkedOccurrenceId,
    this.sourceTransactionId,
    this.savingsRuleId,
  });

  Transaction copyWith({
    String? id,
    String? title,
    double? amount,
    MovementType? type,
    String? category,
    String? accountId,
    String? targetAccountId,
    DateTime? date,
    DateTime? billingDate,
    bool clearBillingDate = false,
    bool? balanceApplied,
    String? note,
    bool? isRecurring,
    String? linkedOccurrenceId,
    String? sourceTransactionId,
    String? savingsRuleId,
  }) {
    return Transaction(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      accountId: accountId ?? this.accountId,
      targetAccountId: targetAccountId ?? this.targetAccountId,
      date: date ?? this.date,
      billingDate: clearBillingDate ? null : (billingDate ?? this.billingDate),
      balanceApplied: balanceApplied ?? this.balanceApplied,
      note: note ?? this.note,
      isRecurring: isRecurring ?? this.isRecurring,
      linkedOccurrenceId: linkedOccurrenceId ?? this.linkedOccurrenceId,
      sourceTransactionId: sourceTransactionId ?? this.sourceTransactionId,
      savingsRuleId: savingsRuleId ?? this.savingsRuleId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'amount': amount,
    'type': type.name,
    'category': category,
    'accountId': accountId,
    'targetAccountId': targetAccountId,
    'date': date.toIso8601String(),
    'billingDate': billingDate?.toIso8601String(),
    'balanceApplied': balanceApplied,
    'note': note,
    'isRecurring': isRecurring,
    'linkedOccurrenceId': linkedOccurrenceId,
    'sourceTransactionId': sourceTransactionId,
    'savingsRuleId': savingsRuleId,
  };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    id: json['id'] as String,
    title: json['title'] as String,
    amount: (json['amount'] as num).toDouble(),
    type: MovementType.values.byName(json['type'] as String),
    category: json['category'] as String,
    accountId: json['accountId'] as String,
    targetAccountId: json['targetAccountId'] as String?,
    date: DateTime.parse(json['date'] as String),
    billingDate: json['billingDate'] != null ? DateTime.parse(json['billingDate'] as String) : null,
    balanceApplied: json['balanceApplied'] as bool? ?? true,
    note: json['note'] as String?,
    isRecurring: json['isRecurring'] as bool? ?? false,
    linkedOccurrenceId: json['linkedOccurrenceId'] as String?,
    sourceTransactionId: json['sourceTransactionId'] as String?,
    savingsRuleId: json['savingsRuleId'] as String?,
  );
}

