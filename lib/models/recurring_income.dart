enum IncomeFrequency {
  daily,    // Diario
  weekly,   // Semanal
  biweekly, // Quincenal
  monthly,  // Mensual
  yearly,   // Anual
  custom,   // Calendario personalizado (fechas exactas)
}

class RecurringIncome {
  final String id;
  final String name; // e.g., "Nómina Empleo", "Renta Cobrada"
  final double amount;
  final IncomeFrequency frequency;
  final int payDay; // Day of month (1-31) for monthly, or 1st pay day for biweekly
  final String accountId; // Target account where income is deposited
  final String category;
  final bool isActive;
  final DateTime? lastLoggedAt;

  const RecurringIncome({
    required this.id,
    required this.name,
    required this.amount,
    required this.frequency,
    required this.payDay,
    required this.accountId,
    this.category = 'Sueldo',
    this.isActive = true,
    this.lastLoggedAt,
  });

  RecurringIncome copyWith({
    String? id,
    String? name,
    double? amount,
    IncomeFrequency? frequency,
    int? payDay,
    String? accountId,
    String? category,
    bool? isActive,
    DateTime? lastLoggedAt,
  }) {
    return RecurringIncome(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      frequency: frequency ?? this.frequency,
      payDay: payDay ?? this.payDay,
      accountId: accountId ?? this.accountId,
      category: category ?? this.category,
      isActive: isActive ?? this.isActive,
      lastLoggedAt: lastLoggedAt ?? this.lastLoggedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'amount': amount,
        'frequency': frequency.name,
        'payDay': payDay,
        'accountId': accountId,
        'category': category,
        'isActive': isActive,
        'lastLoggedAt': lastLoggedAt?.toIso8601String(),
      };

  factory RecurringIncome.fromJson(Map<String, dynamic> json) => RecurringIncome(
        id: json['id'] as String,
        name: json['name'] as String,
        amount: (json['amount'] as num).toDouble(),
        frequency: IncomeFrequency.values.byName(json['frequency'] as String),
        payDay: json['payDay'] as int,
        accountId: json['accountId'] as String,
        category: (json['category'] as String?) ?? 'Sueldo',
        isActive: json['isActive'] as bool? ?? true,
        lastLoggedAt: json['lastLoggedAt'] != null
            ? DateTime.parse(json['lastLoggedAt'] as String)
            : null,
      );
}

class PendingIncome {
  final String id;
  final String incomeId;
  final String name;
  final String accountId;
  final double suggestedAmount;
  final String category;
  final DateTime expectedDate;
  final String reason;

  const PendingIncome({
    required this.id,
    required this.incomeId,
    required this.name,
    required this.accountId,
    required this.suggestedAmount,
    required this.category,
    required this.expectedDate,
    required this.reason,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'incomeId': incomeId,
        'name': name,
        'accountId': accountId,
        'suggestedAmount': suggestedAmount,
        'category': category,
        'expectedDate': expectedDate.toIso8601String(),
        'reason': reason,
      };

  factory PendingIncome.fromJson(Map<String, dynamic> json) => PendingIncome(
        id: json['id'] as String,
        incomeId: json['incomeId'] as String,
        name: json['name'] as String,
        accountId: json['accountId'] as String,
        suggestedAmount: (json['suggestedAmount'] as num).toDouble(),
        category: (json['category'] as String?) ?? 'Sueldo',
        expectedDate: DateTime.parse(json['expectedDate'] as String),
        reason: json['reason'] as String,
      );
}

enum PayOccurrenceStatus {
  projected, // Proyectado a futuro o pendiente de confirmar
  confirmed, // Ya recibido y registrado en Movimientos
  skipped,   // No recibido / omitido
}

class ScheduledPayOccurrence {
  final String id;
  final String incomeId;
  final DateTime date;
  final double amount;
  final PayOccurrenceStatus status;
  final String? note;
  final String? linkedTransactionId;

  const ScheduledPayOccurrence({
    required this.id,
    required this.incomeId,
    required this.date,
    required this.amount,
    this.status = PayOccurrenceStatus.projected,
    this.note,
    this.linkedTransactionId,
  });

  ScheduledPayOccurrence copyWith({
    String? id,
    String? incomeId,
    DateTime? date,
    double? amount,
    PayOccurrenceStatus? status,
    String? note,
    String? linkedTransactionId,
    bool clearLinkedTransaction = false,
  }) {
    return ScheduledPayOccurrence(
      id: id ?? this.id,
      incomeId: incomeId ?? this.incomeId,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      note: note ?? this.note,
      linkedTransactionId: clearLinkedTransaction ? null : (linkedTransactionId ?? this.linkedTransactionId),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'incomeId': incomeId,
        'date': date.toIso8601String(),
        'amount': amount,
        'status': status.name,
        'note': note,
        'linkedTransactionId': linkedTransactionId,
      };

  factory ScheduledPayOccurrence.fromJson(Map<String, dynamic> json) => ScheduledPayOccurrence(
        id: json['id'] as String,
        incomeId: json['incomeId'] as String,
        date: DateTime.parse(json['date'] as String),
        amount: (json['amount'] as num).toDouble(),
        status: PayOccurrenceStatus.values.byName(json['status'] as String),
        note: json['note'] as String?,
        linkedTransactionId: json['linkedTransactionId'] as String?,
      );
}

