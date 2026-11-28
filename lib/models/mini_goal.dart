class MiniGoalCycleRecord {
  final DateTime paidAt;
  final DateTime previousDueDate;
  final double previousSavedAmount;

  const MiniGoalCycleRecord({
    required this.paidAt,
    required this.previousDueDate,
    required this.previousSavedAmount,
  });

  Map<String, dynamic> toJson() => {
        'paidAt': paidAt.toIso8601String(),
        'previousDueDate': previousDueDate.toIso8601String(),
        'previousSavedAmount': previousSavedAmount,
      };

  factory MiniGoalCycleRecord.fromJson(Map<String, dynamic> json) =>
      MiniGoalCycleRecord(
        paidAt: DateTime.parse(json['paidAt'] as String),
        previousDueDate: DateTime.parse(json['previousDueDate'] as String),
        previousSavedAmount:
            (json['previousSavedAmount'] as num?)?.toDouble() ?? 0.0,
      );
}

class MiniGoal {
  final String id;
  final String name;
  final double targetAmount;
  final double savedAmount;
  final DateTime dueDate;
  final DateTime? endDate;
  final int repeatMonths; // 0 if one-time or day-based
  final int repeatDays; // > 0 for custom day intervals (e.g. every 23 days)
  final String? accountId;
  final bool isCompleted;
  final DateTime? completedAt;
  final List<MiniGoalCycleRecord> paymentHistory;

  const MiniGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    this.savedAmount = 0.0,
    required this.dueDate,
    this.endDate,
    this.repeatMonths = 0,
    this.repeatDays = 0,
    this.accountId,
    this.isCompleted = false,
    this.completedAt,
    this.paymentHistory = const [],
  });

  bool get isRepeating => repeatDays > 0 || repeatMonths > 0;

  String get repeatLabel {
    if (repeatDays > 0) {
      return 'Cada $repeatDays ${repeatDays == 1 ? 'día' : 'días'}';
    }
    if (repeatMonths > 0) {
      return 'Cada $repeatMonths ${repeatMonths == 1 ? 'mes' : 'meses'}';
    }
    return 'Una sola vez';
  }

  double get remainingToSave => isCompleted
      ? 0.0
      : (targetAmount - savedAmount).clamp(0.0, double.infinity);

  double get progress => isCompleted
      ? 1.0
      : (targetAmount > 0 ? (savedAmount / targetAmount).clamp(0.0, 1.0) : 0.0);

  bool isVisibleInActiveSection([DateTime? reference]) {
    if (!isCompleted) return true;
    if (completedAt == null) return false;
    final now = reference ?? DateTime.now();
    return completedAt!.year == now.year && completedAt!.month == now.month;
  }

  int monthsUntilDue([DateTime? reference]) {
    final now = reference ?? DateTime.now();
    final months =
        (dueDate.year - now.year) * 12 + (dueDate.month - now.month);
    return months < 0 ? 0 : months;
  }

  double recommendedMonthlySave([DateTime? reference]) {
    if (isCompleted || remainingToSave <= 0) return 0.0;
    final m = monthsUntilDue(reference);
    if (m <= 1) return remainingToSave;
    return remainingToSave / m;
  }

  /// Returns how much is due in a given [year]/[month], or 0.0 if not due then.
  double amountDueInMonth(int year, int month) {
    if (isCompleted) return 0.0;
    if (endDate != null) {
      final endTotalMonths = endDate!.year * 12 + endDate!.month;
      final targetTotalMonths = year * 12 + month;
      if (targetTotalMonths > endTotalMonths) return 0.0;
    }

    if (repeatDays > 0) {
      final monthStart = DateTime(year, month, 1);
      final monthEnd = DateTime(year, month + 1, 0);
      final limitEnd = endDate != null &&
              DateTime(endDate!.year, endDate!.month, endDate!.day)
                  .isBefore(monthEnd)
          ? DateTime(endDate!.year, endDate!.month, endDate!.day)
          : monthEnd;
      DateTime cursor = DateTime(dueDate.year, dueDate.month, dueDate.day);
      double total = 0.0;
      bool first = true;
      int guard = 0;
      while (!cursor.isAfter(limitEnd) && guard < 400) {
        if (!cursor.isBefore(monthStart)) {
          total += first ? remainingToSave : targetAmount;
        }
        first = false;
        cursor = cursor.add(Duration(days: repeatDays));
        guard++;
      }
      return total;
    }

    final dueTotalMonths = dueDate.year * 12 + dueDate.month;
    final targetTotalMonths = year * 12 + month;
    if (targetTotalMonths < dueTotalMonths) return 0.0;
    if (targetTotalMonths == dueTotalMonths) return remainingToSave;
    if (repeatMonths <= 0) return 0.0;
    final diff = targetTotalMonths - dueTotalMonths;
    if (diff % repeatMonths == 0) return targetAmount;
    return 0.0;
  }

  DateTime nextCycleDate() {
    if (repeatDays > 0) {
      return dueDate.add(Duration(days: repeatDays));
    }
    if (repeatMonths <= 0) return dueDate;
    final targetMonth = dueDate.month + repeatMonths;
    final y = dueDate.year + ((targetMonth - 1) ~/ 12);
    final m = ((targetMonth - 1) % 12) + 1;
    final lastDay = DateTime(y, m + 1, 0).day;
    return DateTime(y, m, dueDate.day.clamp(1, lastDay));
  }

  bool get hasNextCycleBeforeEnd {
    if (!isRepeating) return false;
    if (endDate == null) return true;
    final next = nextCycleDate();
    final endDay = DateTime(endDate!.year, endDate!.month, endDate!.day);
    final nextDay = DateTime(next.year, next.month, next.day);
    return !nextDay.isAfter(endDay);
  }

  MiniGoal copyWith({
    String? id,
    String? name,
    double? targetAmount,
    double? savedAmount,
    DateTime? dueDate,
    DateTime? endDate,
    bool clearEndDate = false,
    int? repeatMonths,
    int? repeatDays,
    String? accountId,
    bool clearAccountId = false,
    bool? isCompleted,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    List<MiniGoalCycleRecord>? paymentHistory,
  }) {
    return MiniGoal(
      id: id ?? this.id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      savedAmount: savedAmount ?? this.savedAmount,
      dueDate: dueDate ?? this.dueDate,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      repeatMonths: repeatMonths ?? this.repeatMonths,
      repeatDays: repeatDays ?? this.repeatDays,
      accountId: clearAccountId ? null : (accountId ?? this.accountId),
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt:
          clearCompletedAt ? null : (completedAt ?? this.completedAt),
      paymentHistory: paymentHistory ?? this.paymentHistory,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'targetAmount': targetAmount,
        'savedAmount': savedAmount,
        'dueDate': dueDate.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'repeatMonths': repeatMonths,
        'repeatDays': repeatDays,
        'accountId': accountId,
        'isCompleted': isCompleted,
        'completedAt': completedAt?.toIso8601String(),
        'paymentHistory': paymentHistory.map((e) => e.toJson()).toList(),
      };

  factory MiniGoal.fromJson(Map<String, dynamic> json) => MiniGoal(
        id: json['id'] as String,
        name: json['name'] as String,
        targetAmount: (json['targetAmount'] as num).toDouble(),
        savedAmount: (json['savedAmount'] as num?)?.toDouble() ?? 0.0,
        dueDate: DateTime.parse(json['dueDate'] as String),
        endDate: json['endDate'] != null
            ? DateTime.parse(json['endDate'] as String)
            : null,
        repeatMonths: (json['repeatMonths'] as int?) ?? 0,
        repeatDays: (json['repeatDays'] as int?) ?? 0,
        accountId: json['accountId'] as String?,
        isCompleted: (json['isCompleted'] as bool?) ?? false,
        completedAt: json['completedAt'] != null
            ? DateTime.parse(json['completedAt'] as String)
            : null,
        paymentHistory: ((json['paymentHistory'] as List?) ?? const [])
            .map((e) =>
                MiniGoalCycleRecord.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
