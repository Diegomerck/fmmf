class CreditInstallmentPlan {
  final String id;
  final String accountId; // Credit card account ID
  final String title; // Bank merchant description
  final String? customName; // User-friendly label (e.g., "Monitor LG")
  final double principalAmount; // Original item price
  final double interestAmount; // 0.0 for MSI; > 0 for MCI
  final int totalMonths;
  final int paidMonths;
  final DateTime startDate;

  const CreditInstallmentPlan({
    required this.id,
    required this.accountId,
    required this.title,
    this.customName,
    required this.principalAmount,
    this.interestAmount = 0.0,
    required this.totalMonths,
    this.paidMonths = 0,
    required this.startDate,
  });

  String get displayTitle =>
      (customName != null && customName!.trim().isNotEmpty) ? customName!.trim() : title;

  bool get isInterestFree => interestAmount <= 0;

  double get totalFinancedAmount => principalAmount + interestAmount;

  double get monthlyInstallment {
    if (totalMonths <= 0) return totalFinancedAmount;
    return totalFinancedAmount / totalMonths;
  }

  int get remainingMonths {
    final rem = totalMonths - paidMonths;
    return rem < 0 ? 0 : rem;
  }

  double get remainingBalance => monthlyInstallment * remainingMonths;

  bool get isCompleted => remainingMonths <= 0;

  double get progress {
    if (totalMonths <= 0) return 1.0;
    return (paidMonths / totalMonths).clamp(0.0, 1.0);
  }

  CreditInstallmentPlan copyWith({
    String? id,
    String? accountId,
    String? title,
    String? customName,
    double? principalAmount,
    double? interestAmount,
    int? totalMonths,
    int? paidMonths,
    DateTime? startDate,
  }) {
    return CreditInstallmentPlan(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      title: title ?? this.title,
      customName: customName ?? this.customName,
      principalAmount: principalAmount ?? this.principalAmount,
      interestAmount: interestAmount ?? this.interestAmount,
      totalMonths: totalMonths ?? this.totalMonths,
      paidMonths: paidMonths ?? this.paidMonths,
      startDate: startDate ?? this.startDate,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'accountId': accountId,
        'title': title,
        'customName': customName,
        'principalAmount': principalAmount,
        'interestAmount': interestAmount,
        'totalMonths': totalMonths,
        'paidMonths': paidMonths,
        'startDate': startDate.toIso8601String(),
      };

  factory CreditInstallmentPlan.fromJson(Map<String, dynamic> json) => CreditInstallmentPlan(
        id: json['id'] as String,
        accountId: json['accountId'] as String,
        title: json['title'] as String,
        customName: json['customName'] as String?,
        principalAmount: (json['principalAmount'] as num).toDouble(),
        interestAmount: (json['interestAmount'] as num?)?.toDouble() ?? 0.0,
        totalMonths: json['totalMonths'] as int,
        paidMonths: (json['paidMonths'] as int?) ?? 0,
        startDate: DateTime.parse(json['startDate'] as String),
      );
}

