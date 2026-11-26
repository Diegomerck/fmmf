import '../models/account.dart';
import '../models/transaction.dart';
import '../models/budget_commitment.dart';
import '../models/financial_insight.dart';
import '../models/credit_installment.dart';
import '../models/recurring_income.dart';

class FundingSuggestion {
  final String accountId;
  final String accountName;
  final String institution;
  final AccountType accountType;
  final double suggestedAmount;
  final double remainingBalanceAfter;

  const FundingSuggestion({
    required this.accountId,
    required this.accountName,
    required this.institution,
    required this.accountType,
    required this.suggestedAmount,
    required this.remainingBalanceAfter,
  });
}

class ProjectionLineItem {
  final String title;
  final String? subtitle;
  final double amount;

  const ProjectionLineItem({
    required this.title,
    this.subtitle,
    required this.amount,
  });
}

class MonthlyProjection {
  final int year;
  final int month;
  final bool isCurrentMonth;
  final double startingLiquidity;
  final double expectedIncome;
  final double cardOrMsiDue;
  final double fixedCashDue;
  final double fixedCardDue;
  final int activeMsiCount;
  final double netMonthlyAvailable;
  final double cumulativeBalance;
  final List<ProjectionLineItem> liquidityItems;
  final List<ProjectionLineItem> incomeItems;
  final List<ProjectionLineItem> cardOrMsiItems;
  final List<ProjectionLineItem> fixedCashItems;
  final List<ProjectionLineItem> fixedCardItems;
  final List<ProjectionLineItem> paidFixedItems;

  const MonthlyProjection({
    required this.year,
    required this.month,
    required this.isCurrentMonth,
    required this.startingLiquidity,
    required this.expectedIncome,
    required this.cardOrMsiDue,
    required this.fixedCashDue,
    required this.fixedCardDue,
    required this.activeMsiCount,
    required this.netMonthlyAvailable,
    required this.cumulativeBalance,
    this.liquidityItems = const [],
    this.incomeItems = const [],
    this.cardOrMsiItems = const [],
    this.fixedCashItems = const [],
    this.fixedCardItems = const [],
    this.paidFixedItems = const [],
  });

  double get totalObligations => cardOrMsiDue + fixedCashDue + fixedCardDue;
  bool get isCovered => netMonthlyAvailable >= 0;
  bool get isCumulativeCovered => cumulativeBalance >= 0;
}

class AdvisorAnalysis {
  final double netWorth;
  final double totalAssets;
  final double totalDebt;
  final double creditMonthlyDue;
  final double totalLiquidCash;
  final double dedicatedDebtFunds;
  final double dedicatedFixedFunds;
  final double safeToSpend;
  final double monthlyPassiveYield;
  final double annualPassiveRunRate;
  final double lazyMoneyAmount;
  final double lazyMoneyAnnualLostYield;
  final double monthlyIncomeTotal;
  final double monthlyIncomeProjectedRemaining;
  final double monthlyIncomeExpectedTotal;
  final double monthlyDirectExpense;
  final double totalMonthlyCommitments;
  final double pendingCommitments;
  final double pendingCardCommitments;
  final double paidCommitmentsThisMonth;
  final double monthlyExpenseTotal;
  final double monthlyCashFlowSurplus;
  final double projectedEndOfMonthBuffer;
  final double safetyCushion;
  final double savingsRate;
  final double runwayMonths;
  final List<FundingSuggestion> fundingSuggestions;
  final List<MonthlyProjection> monthlyProjections;
  final List<FinancialInsight> insights;

  const AdvisorAnalysis({
    required this.netWorth,
    required this.totalAssets,
    required this.totalDebt,
    required this.creditMonthlyDue,
    required this.totalLiquidCash,
    this.dedicatedDebtFunds = 0.0,
    this.dedicatedFixedFunds = 0.0,
    required this.safeToSpend,
    required this.monthlyPassiveYield,
    required this.annualPassiveRunRate,
    required this.lazyMoneyAmount,
    required this.lazyMoneyAnnualLostYield,
    required this.monthlyIncomeTotal,
    this.monthlyIncomeProjectedRemaining = 0.0,
    this.monthlyIncomeExpectedTotal = 0.0,
    this.monthlyDirectExpense = 0.0,
    this.totalMonthlyCommitments = 0.0,
    this.pendingCommitments = 0.0,
    this.pendingCardCommitments = 0.0,
    this.paidCommitmentsThisMonth = 0.0,
    required this.monthlyExpenseTotal,
    required this.monthlyCashFlowSurplus,
    this.projectedEndOfMonthBuffer = 0.0,
    this.safetyCushion = 0.0,
    required this.savingsRate,
    required this.runwayMonths,
    this.fundingSuggestions = const [],
    this.monthlyProjections = const [],
    required this.insights,
  });
}

class AdvisorEngine {
  static AdvisorAnalysis analyze({
    required List<Account> accounts,
    required List<Transaction> transactions,
    required List<BudgetCommitment> commitments,
    List<CreditInstallmentPlan> installmentPlans = const [],
    List<RecurringIncome> recurringIncomes = const [],
    List<ScheduledPayOccurrence> scheduledOccurrences = const [],
    double safetyCushion = 0.0, // Optional reserve cushion in MXN (0 by default)
  }) {
    final Map<String, Account> accountById = {
      for (final acc in accounts) acc.id: acc,
    };
    // 1. Asset & Debt breakdown
    double totalAssets = 0.0;
    double totalDebt = 0.0;
    double totalLiquidCash = 0.0;
    double dedicatedDebtFunds = 0.0;
    double dedicatedFixedFunds = 0.0;
    double totalSavingsAndReserves = 0.0;
    double monthlyPassiveYield = 0.0;
    double checkingZeroYieldBalance = 0.0;
    final List<ProjectionLineItem> liquidityItems = [];

    for (final acc in accounts) {
      if (acc.type == AccountType.creditCard) {
        totalDebt += acc.balance;
      } else {
        totalAssets += acc.balance;
        if (acc.purpose == AccountPurpose.debtPayment) {
          dedicatedDebtFunds += acc.balance;
        } else if (acc.purpose == AccountPurpose.fixedExpenses) {
          dedicatedFixedFunds += acc.balance;
        }
        // Any non-protected account (or account explicitly tagged for cards/fixed/general)
        // is part of operational liquidity.
        if (acc.purpose != AccountPurpose.protectedGoal) {
          totalLiquidCash += acc.balance;
          if (acc.balance > 0) {
            final purposeLabel = switch (acc.purpose) {
              AccountPurpose.debtPayment => 'Para tarjetas',
              AccountPurpose.fixedExpenses => 'Para gastos fijos',
              AccountPurpose.general => 'Liquidez general',
              AccountPurpose.protectedGoal => 'Protegido',
            };
            liquidityItems.add(
              ProjectionLineItem(
                title: acc.name,
                subtitle: '${acc.institution} • $purposeLabel',
                amount: acc.balance,
              ),
            );
          }
        }
        if (acc.type == AccountType.checking ||
            acc.type == AccountType.yieldVault ||
            acc.type == AccountType.cash ||
            acc.type == AccountType.savings) {
          totalSavingsAndReserves += acc.balance;
        }

        // Yield calculation
        if (acc.annualYieldRate > 0 && acc.balance > 0) {
          monthlyPassiveYield += acc.monthlyYieldGenerated;
        } else if (acc.type == AccountType.checking && acc.balance > 0) {
          checkingZeroYieldBalance += acc.balance;
        }
      }
    }

    final double netWorth = totalAssets - totalDebt;
    final double annualPassiveRunRate = monthlyPassiveYield * 12.0;

    // 2. Commitments (split into paid, pending cash/debit, and pending credit-card autopay)
    double pendingCashCommitments = 0.0;
    double pendingCardCommitments = 0.0;
    double paidCommitmentsThisMonth = 0.0;
    double totalMonthlyCommitments = 0.0;
    final List<ProjectionLineItem> pendingCashCommitmentItems = [];
    final List<ProjectionLineItem> pendingCardCommitmentItems = [];
    final List<ProjectionLineItem> paidCommitmentItems = [];
    for (final c in commitments) {
      totalMonthlyCommitments += c.amount;
      final linkedAcc = accountById[c.accountId];
      final item = ProjectionLineItem(
        title: c.name,
        subtitle: 'Día ${c.dueDay}${linkedAcc != null ? " • ${linkedAcc.name}" : ""}',
        amount: c.amount,
      );
      if (c.isPaidThisMonth) {
        paidCommitmentsThisMonth += c.amount;
        paidCommitmentItems.add(item);
      } else {
        if (linkedAcc != null && linkedAcc.type == AccountType.creditCard) {
          pendingCardCommitments += c.amount;
          pendingCardCommitmentItems.add(item);
        } else {
          pendingCashCommitments += c.amount;
          pendingCashCommitmentItems.add(item);
        }
      }
    }
    final double pendingCommitments = pendingCashCommitments;

    // 2b. Credit Card Monthly Due (Revolving + this month's MSI/MCI installments, or manual override + deltas)
    double creditMonthlyDue = 0.0;
    final List<ProjectionLineItem> currentMonthCardItems = [];
    for (final card in accounts.where((a) => a.type == AccountType.creditCard)) {
      double cardDue = 0.0;
      if (card.manualMonthlyDueOverride != null && card.manualMonthlyDueAt != null) {
        final overrideAt = card.manualMonthlyDueAt!;
        double delta = 0.0;
        for (final t in transactions) {
          if (!t.date.isAfter(overrideAt)) continue;
          if (t.type == MovementType.expense &&
              t.accountId == card.id &&
              t.category != 'Estado de Cuenta' &&
              t.category != 'Compras a Meses') {
            delta += t.amount;
          } else if ((t.type == MovementType.transfer && t.targetAccountId == card.id) ||
              (t.type == MovementType.income && t.accountId == card.id)) {
            delta -= t.amount;
          }
        }
        for (final p in installmentPlans) {
          if (p.accountId == card.id && !p.isCompleted && p.startDate.isAfter(overrideAt)) {
            delta += p.monthlyInstallment;
          }
        }
        cardDue = (card.manualMonthlyDueOverride! + delta).clamp(0.0, double.infinity);
      } else {
        final activePlans = installmentPlans.where((p) => p.accountId == card.id && !p.isCompleted).toList();
        final msiRemaining = activePlans.fold<double>(0.0, (sum, p) => sum + p.remainingBalance);
        final msiMonthly = activePlans.fold<double>(0.0, (sum, p) => sum + p.monthlyInstallment);
        final revolving = (card.balance - msiRemaining).clamp(0.0, card.balance);
        cardDue = (revolving + msiMonthly).clamp(0.0, card.balance);
      }
      creditMonthlyDue += cardDue;
      if (cardDue > 0) {
        currentMonthCardItems.add(
          ProjectionLineItem(
            title: card.name,
            subtitle: card.cutoffDay > 0 ? 'Corte día ${card.cutoffDay} • Pago día ${card.paymentDueDay}' : 'Pago del mes',
            amount: cardDue,
          ),
        );
      }
    }

    // 3. Safe to Spend: Liquid cash minus monthly credit due, pending fixed bills, and cushion
    final double safeToSpendRaw = totalLiquidCash - creditMonthlyDue - pendingCommitments - safetyCushion;
    final double safeToSpend = safeToSpendRaw < 0 ? 0.0 : safeToSpendRaw;

    // 4. Current Month Cashflow (Received + Projected Remaining Income vs. Obligations without double-counting)
    final now = DateTime.now();
    final Map<String, RecurringIncome> incomeById = {
      for (final inc in recurringIncomes) inc.id: inc,
    };

    double monthlyIncomeReceived = 0.0;
    double monthlyDirectExpense = 0.0;

    for (final t in transactions) {
      if (t.date.year == now.year && t.date.month == now.month) {
        if ((t.type == MovementType.income || t.type == MovementType.yieldAccrual) &&
            t.category != 'Pago Tarjeta') {
          monthlyIncomeReceived += t.amount;
        } else if (t.type == MovementType.expense) {
          final acc = accountById[t.accountId];
          // Exclude credit card purchases here because they are already accounted for in creditMonthlyDue.
          if (acc == null || acc.type != AccountType.creditCard) {
            monthlyDirectExpense += t.amount;
          }
        }
      }
    }

    double monthlyIncomeProjectedRemaining = 0.0;
    for (final occ in scheduledOccurrences) {
      if (occ.date.year == now.year &&
          occ.date.month == now.month &&
          occ.status == PayOccurrenceStatus.projected) {
        final parent = incomeById[occ.incomeId];
        if (parent == null || parent.isActive) {
          monthlyIncomeProjectedRemaining += occ.amount;
        }
      }
    }

    final double monthlyIncomeExpectedTotal =
        monthlyIncomeReceived + monthlyIncomeProjectedRemaining;
    // Pending obligations that still need to be paid this month (excluding already-paid fixed bills)
    final double monthlyExpense =
        creditMonthlyDue + pendingCommitments + monthlyDirectExpense;
    final double monthlySurplus = monthlyIncomeExpectedTotal - monthlyExpense;
    final double savingsRate = monthlyIncomeExpectedTotal > 0
        ? ((monthlySurplus / monthlyIncomeExpectedTotal) * 100.0).clamp(0.0, 100.0)
        : 0.0;

    // Liquidity + upcoming income vs pending obligations + safety cushion
    final double cashPlusUpcomingIncome = totalLiquidCash + monthlyIncomeProjectedRemaining;
    final double pendingObligationsAndCushion =
        creditMonthlyDue + pendingCommitments + safetyCushion;
    final double projectedEndOfMonthBuffer =
        cashPlusUpcomingIncome - pendingObligationsAndCushion;

    // 5. Runway Calculation (months of survival if active income stops)
    final double averageMonthlyBurn =
        (totalMonthlyCommitments + monthlyDirectExpense + creditMonthlyDue) > 0
            ? (totalMonthlyCommitments + monthlyDirectExpense + creditMonthlyDue)
            : 0.0;
    final double runwayMonths = averageMonthlyBurn > 0
        ? (totalSavingsAndReserves / averageMonthlyBurn)
        : 0.0;

    // 6. Lazy Money Detector
    // Keep max 1 month of expenses in 0% checking; the rest is "lazy" and could yield ~12.5% in liquid vaults
    const double targetYieldRate = 12.5; // Average current Mexican liquid vault APY (Nu/Cetes)
    double lazyMoneyAmount = 0.0;
    if (averageMonthlyBurn > 0 && checkingZeroYieldBalance > averageMonthlyBurn) {
      lazyMoneyAmount = checkingZeroYieldBalance - averageMonthlyBurn;
    }
    final double lazyMoneyAnnualLost = lazyMoneyAmount * (targetYieldRate / 100.0);

    // 7. Proactive Insights & Smart Funding Suggestions
    final List<FundingSuggestion> fundingSuggestions = [];
    if (projectedEndOfMonthBuffer < 0) {
      double remainingGap = -projectedEndOfMonthBuffer;
      final protectedCandidates = accounts
          .where((a) =>
              a.type != AccountType.creditCard &&
              a.purpose == AccountPurpose.protectedGoal &&
              a.balance > 0)
          .toList()
        ..sort((a, b) {
          // Prefer liquid savings/yieldVault before investments, then largest balance first
          final aInv = a.type == AccountType.investment ? 1 : 0;
          final bInv = b.type == AccountType.investment ? 1 : 0;
          if (aInv != bInv) return aInv.compareTo(bInv);
          return b.balance.compareTo(a.balance);
        });

      for (final acc in protectedCandidates) {
        if (remainingGap <= 0.01) break;
        final take = acc.balance >= remainingGap ? remainingGap : acc.balance;
        fundingSuggestions.add(
          FundingSuggestion(
            accountId: acc.id,
            accountName: acc.name,
            institution: acc.institution,
            accountType: acc.type,
            suggestedAmount: take,
            remainingBalanceAfter: (acc.balance - take).clamp(0.0, double.infinity),
          ),
        );
        remainingGap -= take;
      }
    }

    final List<FinancialInsight> insights = [];

    // Insight: Income vs. Monthly Obligations (Credit Cards + Fixed Expenses + Direct Spend)
    if (monthlyIncomeExpectedTotal > 0 || creditMonthlyDue > 0 || totalMonthlyCommitments > 0) {
      if (projectedEndOfMonthBuffer < 0) {
        final shortfall = -projectedEndOfMonthBuffer;
        final cushionText = safetyCushion > 0
            ? ' y tu colchón de \$${safetyCushion.toStringAsFixed(0)}'
            : '';
        final suggestionText = fundingSuggestions.isNotEmpty
            ? ' Sugerencia: toma ${fundingSuggestions.map((s) => '\$${s.suggestedAmount.toStringAsFixed(0)} de ${s.accountName}').join(' + ')} para cubrir el mes.'
            : '';
        insights.add(
          FinancialInsight(
            id: 'income_vs_obligations',
            title: 'Cobertura de Obligaciones del Mes',
            message:
                'Entre tu liquidez disponible (\$${totalLiquidCash.toStringAsFixed(0)}) e ingresos por recibir (\$${monthlyIncomeProjectedRemaining.toStringAsFixed(0)}), te faltan \$${shortfall.toStringAsFixed(0)} MXN para cubrir tarjetas (\$${creditMonthlyDue.toStringAsFixed(0)}) y fijos pendientes (\$${pendingCommitments.toStringAsFixed(0)})$cushionText.$suggestionText',
            type: InsightType.warning,
            highlightMetric: '-\$${shortfall.toStringAsFixed(0)} MXN',
          ),
        );
      } else if (monthlySurplus < 0) {
        final deficit = -monthlySurplus;
        insights.add(
          FinancialInsight(
            id: 'income_vs_obligations',
            title: 'Flujo Mensual Ajustado',
            message:
                'Tus obligaciones del mes (\$${monthlyExpense.toStringAsFixed(0)}) superan tus ingresos esperados (\$${monthlyIncomeExpectedTotal.toStringAsFixed(0)}) por \$${deficit.toStringAsFixed(0)} MXN, aunque tu liquidez actual sí logra cubrirlas.',
            type: InsightType.warning,
            highlightMetric: '-\$${deficit.toStringAsFixed(0)} MXN',
          ),
        );
      } else {
        insights.add(
          FinancialInsight(
            id: 'income_vs_obligations',
            title: 'Ingresos Cubren tus Pendientes',
            message:
                'Con tu liquidez (\$${totalLiquidCash.toStringAsFixed(0)}) e ingresos por recibir (\$${monthlyIncomeProjectedRemaining.toStringAsFixed(0)}) cubres tarjetas (\$${creditMonthlyDue.toStringAsFixed(0)}) y fijos pendientes (\$${pendingCommitments.toStringAsFixed(0)}), quedando +\$${projectedEndOfMonthBuffer.toStringAsFixed(0)} MXN libres.',
            type: InsightType.praise,
            highlightMetric: '+\$${projectedEndOfMonthBuffer.toStringAsFixed(0)} MXN',
          ),
        );
      }
    }

    // Insight: Lazy Money Opportunity
    if (lazyMoneyAmount > 1500.0) {
      insights.add(
        FinancialInsight(
          id: 'lazy_money',
          title: 'Dinero Trabajando Poco (Costo de Oportunidad)',
          message:
              'Tienes \$${lazyMoneyAmount.toStringAsFixed(0)} MXN en cuentas que no generan interés. Al moverlo a una cajita de rendimiento (~12.5% anual), generarías aproximadamente \$${(lazyMoneyAnnualLost / 12).toStringAsFixed(0)} MXN extra al mes sin riesgo.',
          type: InsightType.opportunity,
          actionableButtonText: 'Ver Cuentas de Rendimiento',
          highlightMetric: '+\$${(lazyMoneyAnnualLost / 12).toStringAsFixed(0)} MXN/mes',
        ),
      );
    }

    // Insight: Yield Milestone
    if (monthlyPassiveYield > 0) {
      final double fixedCoverage = pendingCommitments > 0
          ? ((monthlyPassiveYield / (monthlyExpense > 0 ? monthlyExpense : pendingCommitments)) * 100).clamp(0.0, 100.0)
          : 0.0;

      insights.add(
        FinancialInsight(
          id: 'yield_growth',
          title: 'Tu Dinero Generando Dinero',
          message:
              'Tus activos generan actualmente \$${monthlyPassiveYield.toStringAsFixed(0)} MXN al mes de manera pasiva ($annualPassiveRunRate MXN al año). ${fixedCoverage > 0 ? "Esto ya cubre el ${fixedCoverage.toStringAsFixed(0)}% de tus gastos mensuales." : ""}',
          type: InsightType.praise,
          highlightMetric: '\$${monthlyPassiveYield.toStringAsFixed(0)} MXN/mes',
        ),
      );
    }

    // Insight: Credit Card Cutoff or High Utilization Warning
    for (final acc in accounts.where((a) => a.type == AccountType.creditCard && a.balance > 0)) {
      final daysToCutoff = acc.cutoffDay > now.day ? (acc.cutoffDay - now.day) : (30 - now.day + acc.cutoffDay);
      if (daysToCutoff <= 5) {
        insights.add(
          FinancialInsight(
            id: 'cc_cutoff_${acc.id}',
            title: 'Corte Próximo: ${acc.name}',
            message:
                'Tu tarjeta corta en $daysToCutoff días con un saldo acumulado de \$${acc.balance.toStringAsFixed(0)} MXN. El asesor FMMF ya apartó este monto en tu Safe-to-Spend.',
            type: InsightType.warning,
            highlightMetric: 'Corte en $daysToCutoff días',
          ),
        );
      }
    }

    // Insight: Runway Health
    if (averageMonthlyBurn <= 0) {
      insights.add(
        FinancialInsight(
          id: 'runway',
          title: 'Respaldo Financiero (Sin datos de gasto aún)',
          message:
              'Tienes \$${totalSavingsAndReserves.toStringAsFixed(0)} MXN en reservas líquidas y ahorros. Registra tus gastos del mes o gastos fijos para calcular cuántos meses cubren.',
          type: InsightType.projection,
          highlightMetric: 'Sin gastos aún',
        ),
      );
    } else {
      insights.add(
        FinancialInsight(
          id: 'runway',
          title: 'Fondo de Emergencia y Respaldo',
          message: runwayMonths >= 6
              ? 'Tus ahorros y liquidez (\$${totalSavingsAndReserves.toStringAsFixed(0)}) cubren ${runwayMonths.toStringAsFixed(1)} meses de tu gasto mensual (\$${averageMonthlyBurn.toStringAsFixed(0)}/mes).'
              : 'Tus ahorros y liquidez (\$${totalSavingsAndReserves.toStringAsFixed(0)}) cubren ${runwayMonths.toStringAsFixed(1)} meses de tu gasto mensual (\$${averageMonthlyBurn.toStringAsFixed(0)}/mes). Referencia estándar: 3 a 6 meses (\$${(averageMonthlyBurn * 3).toStringAsFixed(0)} MXN).',
          type: runwayMonths >= 3 ? InsightType.praise : InsightType.projection,
          highlightMetric: '${runwayMonths.toStringAsFixed(1)} meses',
        ),
      );
    }

    // 8. 12-Month Cashflow & MSI Forecast
    final List<MonthlyProjection> monthlyProjections = [];
    double totalAllFixedCash = 0.0;
    double totalAllFixedCard = 0.0;
    final List<ProjectionLineItem> allFixedCashItems = [];
    final List<ProjectionLineItem> allFixedCardItems = [];
    for (final c in commitments) {
      final linkedAcc = accountById[c.accountId];
      final item = ProjectionLineItem(
        title: c.name,
        subtitle: 'Día ${c.dueDay}${linkedAcc != null ? " • ${linkedAcc.name}" : ""}',
        amount: c.amount,
      );
      if (linkedAcc != null && linkedAcc.type == AccountType.creditCard) {
        totalAllFixedCard += c.amount;
        allFixedCardItems.add(item);
      } else {
        totalAllFixedCash += c.amount;
        allFixedCashItems.add(item);
      }
    }

    final currentMonthIncomeOccurrences = scheduledOccurrences
        .where((occ) =>
            occ.date.year == now.year &&
            occ.date.month == now.month &&
            occ.status == PayOccurrenceStatus.projected &&
            (incomeById[occ.incomeId]?.isActive ?? true))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final currentMonthIncomeItems = currentMonthIncomeOccurrences.map((occ) {
      final inc = incomeById[occ.incomeId];
      final accName = inc != null ? accountById[inc.accountId]?.name : null;
      return ProjectionLineItem(
        title: inc?.name ?? 'Ingreso programado',
        subtitle: '${occ.date.day}/${occ.date.month}${accName != null ? " → $accName" : ""}',
        amount: occ.amount,
      );
    }).toList();

    final activePlansList = installmentPlans.where((p) => !p.isCompleted).toList();
    double runningCumulative = projectedEndOfMonthBuffer;

    // Month 0: remaining obligations vs current liquidity + remaining scheduled income
    monthlyProjections.add(
      MonthlyProjection(
        year: now.year,
        month: now.month,
        isCurrentMonth: true,
        startingLiquidity: totalLiquidCash,
        expectedIncome: monthlyIncomeProjectedRemaining,
        cardOrMsiDue: creditMonthlyDue,
        fixedCashDue: pendingCommitments,
        fixedCardDue: pendingCardCommitments,
        activeMsiCount: activePlansList.length,
        netMonthlyAvailable: projectedEndOfMonthBuffer,
        cumulativeBalance: runningCumulative,
        liquidityItems: liquidityItems,
        incomeItems: currentMonthIncomeItems,
        cardOrMsiItems: currentMonthCardItems,
        fixedCashItems: pendingCashCommitmentItems,
        fixedCardItems: pendingCardCommitmentItems,
        paidFixedItems: paidCommitmentItems,
      ),
    );

    // Months 1..11: future months
    for (int m = 1; m <= 11; m++) {
      final target = DateTime(now.year, now.month + m, 1);
      double monthIncome = 0.0;
      final List<ProjectionLineItem> monthIncomeItems = [];

      // Sum scheduled occurrences per income; fallback to frequency if schedule doesn't reach month m
      final Set<String> incomesWithOccurrences = {};
      final monthOccs = scheduledOccurrences
          .where((occ) => occ.date.year == target.year && occ.date.month == target.month)
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      for (final occ in monthOccs) {
        incomesWithOccurrences.add(occ.incomeId);
        if (occ.status != PayOccurrenceStatus.skipped) {
          final parent = incomeById[occ.incomeId];
          if (parent == null || parent.isActive) {
            monthIncome += occ.amount;
            final accName = parent != null ? accountById[parent.accountId]?.name : null;
            monthIncomeItems.add(
              ProjectionLineItem(
                title: parent?.name ?? 'Ingreso programado',
                subtitle: '${occ.date.day}/${occ.date.month}${accName != null ? " → $accName" : ""}',
                amount: occ.amount,
              ),
            );
          }
        }
      }
      for (final inc in recurringIncomes) {
        if (!inc.isActive || incomesWithOccurrences.contains(inc.id)) continue;
        double est = 0.0;
        switch (inc.frequency) {
          case IncomeFrequency.monthly:
            est = inc.amount;
            break;
          case IncomeFrequency.biweekly:
            est = inc.amount * 2;
            break;
          case IncomeFrequency.weekly:
            est = inc.amount * 4;
            break;
          case IncomeFrequency.daily:
            est = inc.amount * 30;
            break;
          case IncomeFrequency.yearly:
          case IncomeFrequency.custom:
            break;
        }
        if (est > 0) {
          monthIncome += est;
          final accName = accountById[inc.accountId]?.name;
          monthIncomeItems.add(
            ProjectionLineItem(
              title: inc.name,
              subtitle: 'Estimado mensual${accName != null ? " → $accName" : ""}',
              amount: est,
            ),
          );
        }
      }

      double msiDue = 0.0;
      int msiCount = 0;
      final List<ProjectionLineItem> monthMsiItems = [];
      for (final p in activePlansList) {
        final futureInstallments = p.paidMonths == 0 ? (p.remainingMonths - 1) : p.remainingMonths;
        if (m <= futureInstallments) {
          msiDue += p.monthlyInstallment;
          msiCount++;
          final cardName = accountById[p.accountId]?.name ?? 'Tarjeta';
          final quotaNum = (p.paidMonths == 0 ? 1 : p.paidMonths) + m;
          monthMsiItems.add(
            ProjectionLineItem(
              title: p.displayTitle,
              subtitle: '$cardName • Cuota $quotaNum/${p.totalMonths}',
              amount: p.monthlyInstallment,
            ),
          );
        }
      }
      monthMsiItems.sort((a, b) => b.amount.compareTo(a.amount));

      final double totalOblig = msiDue + totalAllFixedCash + totalAllFixedCard;
      final double netMonth = monthIncome - totalOblig;
      runningCumulative += netMonth;

      monthlyProjections.add(
        MonthlyProjection(
          year: target.year,
          month: target.month,
          isCurrentMonth: false,
          startingLiquidity: 0.0,
          expectedIncome: monthIncome,
          cardOrMsiDue: msiDue,
          fixedCashDue: totalAllFixedCash,
          fixedCardDue: totalAllFixedCard,
          activeMsiCount: msiCount,
          netMonthlyAvailable: netMonth,
          cumulativeBalance: runningCumulative,
          incomeItems: monthIncomeItems,
          cardOrMsiItems: monthMsiItems,
          fixedCashItems: allFixedCashItems,
          fixedCardItems: allFixedCardItems,
        ),
      );
    }

    return AdvisorAnalysis(
      netWorth: netWorth,
      totalAssets: totalAssets,
      totalDebt: totalDebt,
      creditMonthlyDue: creditMonthlyDue,
      totalLiquidCash: totalLiquidCash,
      dedicatedDebtFunds: dedicatedDebtFunds,
      dedicatedFixedFunds: dedicatedFixedFunds,
      safeToSpend: safeToSpend,
      monthlyPassiveYield: monthlyPassiveYield,
      annualPassiveRunRate: annualPassiveRunRate,
      lazyMoneyAmount: lazyMoneyAmount,
      lazyMoneyAnnualLostYield: lazyMoneyAnnualLost,
      monthlyIncomeTotal: monthlyIncomeReceived,
      monthlyIncomeProjectedRemaining: monthlyIncomeProjectedRemaining,
      monthlyIncomeExpectedTotal: monthlyIncomeExpectedTotal,
      monthlyDirectExpense: monthlyDirectExpense,
      totalMonthlyCommitments: totalMonthlyCommitments,
      pendingCommitments: pendingCommitments,
      pendingCardCommitments: pendingCardCommitments,
      paidCommitmentsThisMonth: paidCommitmentsThisMonth,
      monthlyExpenseTotal: monthlyExpense,
      monthlyCashFlowSurplus: monthlySurplus,
      projectedEndOfMonthBuffer: projectedEndOfMonthBuffer,
      safetyCushion: safetyCushion,
      savingsRate: savingsRate,
      runwayMonths: runwayMonths,
      fundingSuggestions: fundingSuggestions,
      monthlyProjections: monthlyProjections,
      insights: insights,
    );
  }
}

