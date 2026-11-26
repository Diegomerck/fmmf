enum RoutingFrequency {
  onIncome, // Triggered as a % whenever an income is logged
  daily,    // Fixed amount suggested every day
  weekly,   // Fixed amount suggested every week
  monthly,  // Fixed amount suggested every month
  yearly,   // Fixed amount suggested every year
}

class SavingsRule {
  final String id;
  final String name;
  final String targetAccountId; // Must be a savings (or yieldVault) account
  final String? sourceAccountId; // Optional for onIncome (uses deposit account if null)
  final RoutingFrequency frequency;
  final double percentage; // Used when frequency == onIncome (e.g., 10.0 for 10%)
  final double fixedAmount; // Used when frequency is daily/weekly/monthly/yearly
  final bool isActive;
  final DateTime? lastTriggeredAt;

  const SavingsRule({
    required this.id,
    required this.name,
    required this.targetAccountId,
    this.sourceAccountId,
    required this.frequency,
    this.percentage = 0.0,
    this.fixedAmount = 0.0,
    this.isActive = true,
    this.lastTriggeredAt,
  });

  SavingsRule copyWith({
    String? id,
    String? name,
    String? targetAccountId,
    String? sourceAccountId,
    RoutingFrequency? frequency,
    double? percentage,
    double? fixedAmount,
    bool? isActive,
    DateTime? lastTriggeredAt,
  }) {
    return SavingsRule(
      id: id ?? this.id,
      name: name ?? this.name,
      targetAccountId: targetAccountId ?? this.targetAccountId,
      sourceAccountId: sourceAccountId ?? this.sourceAccountId,
      frequency: frequency ?? this.frequency,
      percentage: percentage ?? this.percentage,
      fixedAmount: fixedAmount ?? this.fixedAmount,
      isActive: isActive ?? this.isActive,
      lastTriggeredAt: lastTriggeredAt ?? this.lastTriggeredAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'targetAccountId': targetAccountId,
        'sourceAccountId': sourceAccountId,
        'frequency': frequency.name,
        'percentage': percentage,
        'fixedAmount': fixedAmount,
        'isActive': isActive,
        'lastTriggeredAt': lastTriggeredAt?.toIso8601String(),
      };

  factory SavingsRule.fromJson(Map<String, dynamic> json) => SavingsRule(
        id: json['id'] as String,
        name: json['name'] as String,
        targetAccountId: json['targetAccountId'] as String,
        sourceAccountId: json['sourceAccountId'] as String?,
        frequency: RoutingFrequency.values.byName(json['frequency'] as String),
        percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
        fixedAmount: (json['fixedAmount'] as num?)?.toDouble() ?? 0.0,
        isActive: json['isActive'] as bool? ?? true,
        lastTriggeredAt: json['lastTriggeredAt'] != null
            ? DateTime.parse(json['lastTriggeredAt'] as String)
            : null,
      );
}

class PendingTransfer {
  final String id;
  final String ruleId;
  final String ruleName;
  final String sourceAccountId;
  final String targetAccountId;
  final double suggestedAmount;
  final String reason;
  final DateTime createdAt;
  final String? sourceTransactionId;

  const PendingTransfer({
    required this.id,
    required this.ruleId,
    required this.ruleName,
    required this.sourceAccountId,
    required this.targetAccountId,
    required this.suggestedAmount,
    required this.reason,
    required this.createdAt,
    this.sourceTransactionId,
  });

  PendingTransfer copyWith({
    double? suggestedAmount,
    String? reason,
  }) {
    return PendingTransfer(
      id: id,
      ruleId: ruleId,
      ruleName: ruleName,
      sourceAccountId: sourceAccountId,
      targetAccountId: targetAccountId,
      suggestedAmount: suggestedAmount ?? this.suggestedAmount,
      reason: reason ?? this.reason,
      createdAt: createdAt,
      sourceTransactionId: sourceTransactionId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ruleId': ruleId,
        'ruleName': ruleName,
        'sourceAccountId': sourceAccountId,
        'targetAccountId': targetAccountId,
        'suggestedAmount': suggestedAmount,
        'reason': reason,
        'createdAt': createdAt.toIso8601String(),
        'sourceTransactionId': sourceTransactionId,
      };

  factory PendingTransfer.fromJson(Map<String, dynamic> json) => PendingTransfer(
        id: json['id'] as String,
        ruleId: json['ruleId'] as String,
        ruleName: json['ruleName'] as String,
        sourceAccountId: json['sourceAccountId'] as String,
        targetAccountId: json['targetAccountId'] as String,
        suggestedAmount: (json['suggestedAmount'] as num).toDouble(),
        reason: json['reason'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        sourceTransactionId: json['sourceTransactionId'] as String?,
      );
}

