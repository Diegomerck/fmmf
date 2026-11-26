import 'package:flutter/material.dart';

enum AccountType {
  checking,      // Debit / traditional checking (BBVA, Banamex, etc.)
  savings,       // Personal savings accounts / goals (Ahorros)
  yieldVault,    // Liquid high-yield savings (Nu Cajita, Cetesdirecto, Mercado Pago)
  investment,    // Stocks, ETFs, Crypto, Real Estate (GBM, Fintual, Bitso)
  creditCard,    // Credit lines (with cutoff and payment dates)
  cash,          // Physical cash
}

enum AccountPurpose {
  general,       // Uso general / liquidez operativa
  debtPayment,   // Destinada a pagar tarjetas de crédito / deudas
  fixedExpenses, // Destinada a gastos fijos mensuales
  protectedGoal, // Meta o reserva protegida (no usar salvo emergencia)
}

class Account {
  final String id;
  final String name;
  final AccountType type;
  final double balance; // For credit card, this is current utilized debt (positive)
  final double creditLimit; // For credit card
  final double annualYieldRate; // e.g., 13.5 for 13.5% APY (for yieldVaults & investments)
  final double savingsGoal; // Optional target goal in MXN (for savings accounts)
  final int cutoffDay; // Día de corte (1-31) for credit cards
  final int paymentDueDay; // Día límite de pago (1-31) for credit cards
  final double? manualMonthlyDueOverride; // Manual "Pago del mes" baseline set via pencil icon
  final DateTime? manualMonthlyDueAt; // Timestamp when manual override was set
  final String institution; // e.g., "Nu", "BBVA", "Cetesdirecto"
  final String colorHex;
  final String iconCode;
  final AccountPurpose purpose;

  static AccountPurpose defaultPurposeForType(AccountType type) {
    switch (type) {
      case AccountType.savings:
      case AccountType.investment:
        return AccountPurpose.protectedGoal;
      case AccountType.checking:
      case AccountType.yieldVault:
      case AccountType.cash:
      case AccountType.creditCard:
        return AccountPurpose.general;
    }
  }

  static const List<String> colorPaletteHex = [
    '#10B981', // Emerald
    '#00E5FF', // Electric Cyan
    '#8B5CF6', // Violet
    '#F59E0B', // Amber Gold
    '#EF4444', // Coral Red
    '#3B82F6', // Royal Blue
    '#EC4899', // Pink
    '#14B8A6', // Teal
    '#F97316', // Orange
    '#A855F7', // Purple
  ];

  static Color parseColorHex(String hex) {
    final cleaned = hex.replaceAll('#', '').trim();
    if (cleaned.length == 6) {
      final parsed = int.tryParse('FF$cleaned', radix: 16);
      if (parsed != null) return Color(parsed);
    } else if (cleaned.length == 8) {
      final parsed = int.tryParse(cleaned, radix: 16);
      if (parsed != null) return Color(parsed);
    }
    return const Color(0xFF10B981);
  }

  Color get color => parseColorHex(colorHex);

  Account({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    this.creditLimit = 0.0,
    this.annualYieldRate = 0.0,
    this.savingsGoal = 0.0,
    this.cutoffDay = 0,
    this.paymentDueDay = 0,
    this.manualMonthlyDueOverride,
    this.manualMonthlyDueAt,
    required this.institution,
    this.colorHex = '#10B981',
    this.iconCode = 'account_balance_wallet',
    AccountPurpose? purpose,
  }) : purpose = purpose ?? defaultPurposeForType(type);

  /// Progress toward savings goal (0.0 to 1.0)
  double get goalProgress {
    if (savingsGoal <= 0 || balance <= 0) return 0.0;
    return (balance / savingsGoal).clamp(0.0, 1.0);
  }

  /// Monthly passive yield generated in MXN based on annualYieldRate
  double get monthlyYieldGenerated {
    if (annualYieldRate <= 0 || balance <= 0) return 0.0;
    return balance * (annualYieldRate / 100.0) / 12.0;
  }

  /// Daily passive yield generated in MXN
  double get dailyYieldGenerated {
    if (annualYieldRate <= 0 || balance <= 0) return 0.0;
    return balance * (annualYieldRate / 100.0) / 365.0;
  }

  Account copyWith({
    String? id,
    String? name,
    AccountType? type,
    double? balance,
    double? creditLimit,
    double? annualYieldRate,
    double? savingsGoal,
    int? cutoffDay,
    int? paymentDueDay,
    double? manualMonthlyDueOverride,
    DateTime? manualMonthlyDueAt,
    bool clearManualMonthlyDue = false,
    String? institution,
    String? colorHex,
    String? iconCode,
    AccountPurpose? purpose,
  }) {
    final nextType = type ?? this.type;
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: nextType,
      balance: balance ?? this.balance,
      creditLimit: creditLimit ?? this.creditLimit,
      annualYieldRate: annualYieldRate ?? this.annualYieldRate,
      savingsGoal: savingsGoal ?? this.savingsGoal,
      cutoffDay: cutoffDay ?? this.cutoffDay,
      paymentDueDay: paymentDueDay ?? this.paymentDueDay,
      manualMonthlyDueOverride: clearManualMonthlyDue ? null : (manualMonthlyDueOverride ?? this.manualMonthlyDueOverride),
      manualMonthlyDueAt: clearManualMonthlyDue ? null : (manualMonthlyDueAt ?? this.manualMonthlyDueAt),
      institution: institution ?? this.institution,
      colorHex: colorHex ?? this.colorHex,
      iconCode: iconCode ?? this.iconCode,
      purpose: purpose ?? this.purpose,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'balance': balance,
    'creditLimit': creditLimit,
    'annualYieldRate': annualYieldRate,
    'savingsGoal': savingsGoal,
    'cutoffDay': cutoffDay,
    'paymentDueDay': paymentDueDay,
    'manualMonthlyDueOverride': manualMonthlyDueOverride,
    'manualMonthlyDueAt': manualMonthlyDueAt?.toIso8601String(),
    'institution': institution,
    'colorHex': colorHex,
    'iconCode': iconCode,
    'purpose': purpose.name,
  };

  factory Account.fromJson(Map<String, dynamic> json) {
    final type = AccountType.values.byName(json['type'] as String);
    final rawPurpose = json['purpose'] as String?;
    final parsedPurpose = rawPurpose != null
        ? AccountPurpose.values.where((p) => p.name == rawPurpose).firstOrNull
        : null;
    return Account(
      id: json['id'] as String,
      name: json['name'] as String,
      type: type,
      balance: (json['balance'] as num).toDouble(),
      creditLimit: (json['creditLimit'] as num?)?.toDouble() ?? 0.0,
      annualYieldRate: (json['annualYieldRate'] as num?)?.toDouble() ?? 0.0,
      savingsGoal: (json['savingsGoal'] as num?)?.toDouble() ?? 0.0,
      cutoffDay: (json['cutoffDay'] as int?) ?? 0,
      paymentDueDay: (json['paymentDueDay'] as int?) ?? 0,
      manualMonthlyDueOverride: (json['manualMonthlyDueOverride'] as num?)?.toDouble(),
      manualMonthlyDueAt: json['manualMonthlyDueAt'] != null
          ? DateTime.parse(json['manualMonthlyDueAt'] as String)
          : null,
      institution: (json['institution'] as String?) ?? '',
      colorHex: (json['colorHex'] as String?) ?? '#10B981',
      iconCode: (json['iconCode'] as String?) ?? 'account_balance_wallet',
      purpose: parsedPurpose ?? defaultPurposeForType(type),
    );
  }
}

