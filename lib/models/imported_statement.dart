class ImportedStatement {
  final String id;
  final String accountId;
  final String fileName;
  final DateTime importedAt;
  final String? cutoffDateStr;
  final String? dueDateStr;
  final double? paymentNoInterest;
  final double? regularBalance;
  final double? msiBalance;
  final double? totalDebt;
  final double? creditLimit;
  final List<String> importedPlanIds;
  final List<String> importedTransactionIds;

  const ImportedStatement({
    required this.id,
    required this.accountId,
    required this.fileName,
    required this.importedAt,
    this.cutoffDateStr,
    this.dueDateStr,
    this.paymentNoInterest,
    this.regularBalance,
    this.msiBalance,
    this.totalDebt,
    this.creditLimit,
    this.importedPlanIds = const [],
    this.importedTransactionIds = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'accountId': accountId,
        'fileName': fileName,
        'importedAt': importedAt.toIso8601String(),
        'cutoffDateStr': cutoffDateStr,
        'dueDateStr': dueDateStr,
        'paymentNoInterest': paymentNoInterest,
        'regularBalance': regularBalance,
        'msiBalance': msiBalance,
        'totalDebt': totalDebt,
        'creditLimit': creditLimit,
        'importedPlanIds': importedPlanIds,
        'importedTransactionIds': importedTransactionIds,
      };

  factory ImportedStatement.fromJson(Map<String, dynamic> json) => ImportedStatement(
        id: json['id'] as String,
        accountId: json['accountId'] as String,
        fileName: json['fileName'] as String,
        importedAt: DateTime.parse(json['importedAt'] as String),
        cutoffDateStr: json['cutoffDateStr'] as String?,
        dueDateStr: json['dueDateStr'] as String?,
        paymentNoInterest: (json['paymentNoInterest'] as num?)?.toDouble(),
        regularBalance: (json['regularBalance'] as num?)?.toDouble(),
        msiBalance: (json['msiBalance'] as num?)?.toDouble(),
        totalDebt: (json['totalDebt'] as num?)?.toDouble(),
        creditLimit: (json['creditLimit'] as num?)?.toDouble(),
        importedPlanIds: (json['importedPlanIds'] as List? ?? []).cast<String>(),
        importedTransactionIds: (json['importedTransactionIds'] as List? ?? []).cast<String>(),
      );
}

