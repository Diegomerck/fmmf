import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_format.dart';
import '../../models/account.dart';
import '../../models/transaction.dart';
import '../../models/financial_insight.dart';
import '../../providers/finance_provider.dart';
import '../../services/advisor_engine.dart';
import 'widgets/safe_to_spend_card.dart';
import 'widgets/quick_entry_sheet.dart';
import 'widgets/pending_transfers_section.dart';
import 'widgets/pending_incomes_section.dart';
import 'widgets/expandable_breakdown_row.dart';
import 'widgets/transaction_detail_dialog.dart';
import 'widgets/mini_goal_sheet.dart';
import 'widgets/mini_goal_transfer_sheet.dart';
import 'emergency_fund_screen.dart';

class DashboardTab extends StatelessWidget {
  final FinanceProvider provider;
  final Function(int) onNavigateToTab;

  const DashboardTab({
    super.key,
    required this.provider,
    required this.onNavigateToTab,
  });

  @override
  Widget build(BuildContext context) {
    final analysis = provider.analysis;
    final secondaryInsights = analysis.insights
        .where((i) => i.id != 'income_vs_obligations')
        .toList();
    final topInsight =
        secondaryInsights.isNotEmpty ? secondaryInsights.first : null;
    final suggestedTotal = analysis.fundingSuggestions
        .fold<double>(0.0, (sum, s) => sum + s.suggestedAmount);
    final canCoverWithReserves = analysis.projectedEndOfMonthBuffer < 0 &&
        suggestedTotal >= (-analysis.projectedEndOfMonthBuffer - 0.5);
    final creditCards = provider.accounts
        .where((a) => a.type == AccountType.creditCard && a.balance > 0)
        .toList()
      ..sort((a, b) => b.balance.compareTo(a.balance));
    final highestDebtCardName =
        creditCards.isNotEmpty ? creditCards.first.name : null;
    final emergencyAccounts = provider.accounts
        .where((a) => a.type != AccountType.creditCard && a.isEmergencyFund)
        .toList();
    final netEmergencyReserves = emergencyAccounts
        .fold<double>(0.0, (sum, a) => sum + a.balance)
        .clamp(0.0, double.infinity);
    final emergencyAccountNames = emergencyAccounts
        .map((a) =>
            '${a.name} (${CurrencyFormat.formatMXN(a.balance, includeDecimals: false)})')
        .toList();
    final monthlySurvivalBurn =
        analysis.totalMonthlyCommitments + analysis.monthlyDirectExpense;
    final emergencyGoalAmount =
        monthlySurvivalBurn * provider.emergencyFundMonths;
    final emergencyRemaining =
        (emergencyGoalAmount - netEmergencyReserves).clamp(0.0, double.infinity);
    final emergencyGoalEstimate =
        analysis.estimateTimelineForTarget(emergencyRemaining);
    final emergencyGoalFocusedEstimate = analysis.estimateTimelineForTarget(
      emergencyRemaining,
      includeVariableSpend: false,
    );
    final debtGoalEstimate =
        analysis.estimateTimelineForTarget(analysis.totalDebt);
    final debtGoalFocusedEstimate = analysis.estimateTimelineForTarget(
      analysis.totalDebt,
      includeVariableSpend: false,
    );

    if (provider.simpleMode) {
      return _buildSimpleDashboard(
        context,
        analysis: analysis,
        canCoverWithReserves: canCoverWithReserves,
        netEmergencyReserves: netEmergencyReserves,
        emergencyGoalAmount: emergencyGoalAmount,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Safe To Spend Flagship Card
          SafeToSpendCard(
            safeToSpend: analysis.safeToSpend,
            netWorth: analysis.netWorth,
            monthlyPassiveYield: analysis.monthlyPassiveYield,
            totalLiquidCash: analysis.totalLiquidCash,
            totalDebt: analysis.creditMonthlyDue,
            pendingCommitments: analysis.pendingCommitments,
            safetyCushion: analysis.safetyCushion,
            upcomingIncome: analysis.monthlyIncomeProjectedRemaining,
            projectedEndOfMonthBuffer: analysis.projectedEndOfMonthBuffer,
            canCoverWithReserves: canCoverWithReserves,
            nextPaydayDate: analysis.nextPaydayDate,
            obligationsBeforeNextPayday: analysis.obligationsBeforeNextPayday,
            lowestTimelineBalance: analysis.lowestTimelineBalance,
            lowestTimelineDate: analysis.lowestTimelineDate,
            totalAllDebt: analysis.totalDebt,
            emergencyFundEnabled: provider.emergencyFundEnabled,
            emergencyFundMonths: provider.emergencyFundMonths,
            runwayMonths: analysis.runwayMonths,
            highestDebtCardName: highestDebtCardName,
            netEmergencyReserves: netEmergencyReserves,
            emergencyGoalAmount: emergencyGoalAmount,
            surplusGoalOrder: provider.surplusGoalOrder,
            includeExtraDebtGoal: provider.includeExtraDebtGoal,
            emergencyGoalEstimate: emergencyGoalEstimate,
            emergencyGoalFocusedEstimate: emergencyGoalFocusedEstimate,
            debtGoalEstimate: debtGoalEstimate,
            debtGoalFocusedEstimate: debtGoalFocusedEstimate,
            simpleMode: provider.simpleMode,
            hasEmergencyAccountLinked: emergencyAccounts.isNotEmpty,
            emergencyAccountNames: emergencyAccountNames,
            onTransferToEmergencyFund: emergencyAccounts.isNotEmpty
                ? (suggested) => _showEmergencyTransferSheet(
                      context,
                      suggestedAmount: suggested,
                      emergencyAccounts: emergencyAccounts,
                    )
                : null,
            onOpenAccountsTab: () => onNavigateToTab(2),
            onOpenEmergencyFund: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EmergencyFundScreen(provider: provider),
              ),
            ),
            onQuickAdd: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => QuickEntrySheet(provider: provider),
              );
            },
          ),
          const SizedBox(height: 14),

          // Pending Incomes & Savings Transfers to Confirm
          PendingIncomesSection(provider: provider),
          PendingTransfersSection(provider: provider),
          _buildMiniGoalReminders(context),
          _buildCategoryAccountTips(),

          if (!provider.simpleMode) ...[
            // Monthly Cashflow & Date-by-Date Timeline Card
            _CashflowCardToggle(
              analysis: analysis,
              monthlyContentBuilder: (ctx) => _buildMonthlyCashflowCard(analysis),
            ),
            const SizedBox(height: 14),

            // Quick Financial Metrics Grid
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      title: 'Ingresos',
                      subtitle: 'Recibido + por cobrar',
                      amount: CurrencyFormat.formatMXN(
                        analysis.monthlyIncomeExpectedTotal,
                        includeDecimals: false,
                      ),
                      icon: Icons.arrow_downward_rounded,
                      accentColor: AppTheme.emeraldGreen,
                      onTap: () => _showMetricExplanationDialog(
                        context,
                        kind: 'income',
                        analysis: analysis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricTile(
                      title: 'Gastos',
                      subtitle: 'Tarjetas, fijos y gastos',
                      amount: CurrencyFormat.formatMXN(
                          analysis.monthlyExpenseTotal,
                          includeDecimals: false),
                      icon: Icons.arrow_upward_rounded,
                      accentColor: AppTheme.alertCoral,
                      onTap: () => _showMetricExplanationDialog(
                        context,
                        kind: 'expense',
                        analysis: analysis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricTile(
                      title: 'Libre',
                      subtitle: '% libre de ingresos',
                      amount: '${analysis.savingsRate.toStringAsFixed(0)}%',
                      icon: Icons.trending_up_rounded,
                      accentColor: AppTheme.electricCyan,
                      onTap: () => _showMetricExplanationDialog(
                        context,
                        kind: 'savings',
                        analysis: analysis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Secondary Advisor Banner (structured card for runway, or standard banner)
            if (topInsight != null) ...[
              if (topInsight.id == 'runway')
                _buildEmergencyRunwayCard(context, analysis)
              else
                _buildAdvisorBanner(context, topInsight),
              const SizedBox(height: 14),
            ],
            const SizedBox(height: 8),
          ],

          // Where is the Money at (Accounts preview)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¿Dónde está tu dinero?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Tus cuentas, ahorros y tarjetas activas.',
                      style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => onNavigateToTab(2), // Go to Accounts Tab
                child: const Text('Ver todas', style: TextStyle(color: AppTheme.electricCyan, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...provider.accounts.take(3).map((acc) => _buildAccountItem(acc)),

          const SizedBox(height: 24),

          // Recent movements preview
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Últimos Movimientos',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Toca cualquiera para ver detalle, editar o eliminar.',
                      style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => onNavigateToTab(1), // Go to Transactions Tab
                child: const Text('Historial', style: TextStyle(color: AppTheme.electricCyan, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (provider.transactions.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No hay movimientos registrados', style: TextStyle(color: AppTheme.textMuted)),
              ),
            )
          else
            ...([...provider.transactions]
                  ..sort((a, b) => b.date.compareTo(a.date)))
                .take(5)
                .map((tx) => _buildTransactionItem(context, tx)),
        ],
      ),
    );
  }

  Widget _buildSimpleDashboard(
    BuildContext context, {
    required AdvisorAnalysis analysis,
    required bool canCoverWithReserves,
    required double netEmergencyReserves,
    required double emergencyGoalAmount,
  }) {
    final bool hasMidMonthDip =
        analysis.lowestTimelineBalance < -0.5 && analysis.lowestTimelineDate != null;
    final bool isCovered = !hasMidMonthDip && analysis.projectedEndOfMonthBuffer >= 0;
    final double true45DayFree = analysis.projectedEndOfMonthBuffer > 0
        ? analysis.safeToSpend.clamp(0.0, analysis.projectedEndOfMonthBuffer)
        : 0.0;
    final double totalToPay =
        analysis.creditMonthlyDue + analysis.pendingCommitments;

    final Color statusColor;
    final IconData statusIcon;
    final String statusLabel;
    final String yesNoTitle;
    final String yesNoDetail;

    if (isCovered) {
      statusColor = AppTheme.emeraldGreen;
      statusIcon = Icons.check_circle_rounded;
      statusLabel = 'Vas bien';
      yesNoTitle = '¿Te alcanza este mes? Sí';
      if (true45DayFree + 1 < analysis.projectedEndOfMonthBuffer &&
          true45DayFree > 0) {
        yesNoDetail =
            'Te quedan ${CurrencyFormat.formatMXN(true45DayFree, includeDecimals: false)} libres (el resto es para inicios del próximo mes).';
      } else if (analysis.projectedEndOfMonthBuffer > 0) {
        yesNoDetail =
            'Te sobran +${CurrencyFormat.formatMXN(analysis.projectedEndOfMonthBuffer, includeDecimals: false)} después de tus pagos.';
      } else {
        yesNoDetail = 'Cubres exactamente tus pagos de este mes.';
      }
    } else if (hasMidMonthDip || canCoverWithReserves) {
      statusColor = AppTheme.amberGold;
      statusIcon = Icons.warning_amber_rounded;
      statusLabel = 'Ojo, vas justo';
      yesNoTitle = '¿Te alcanza este mes? Justo';
      if (hasMidMonthDip) {
        yesNoDetail =
            'Un pago cae antes de tu próximo cobro (${analysis.lowestTimelineDate!.day}/${analysis.lowestTimelineDate!.month}).';
      } else {
        yesNoDetail =
            'Faltan ${CurrencyFormat.formatMXN(-analysis.projectedEndOfMonthBuffer, includeDecimals: false)} con tus ingresos, pero tus reservas lo cubren.';
      }
    } else {
      statusColor = AppTheme.alertCoral;
      statusIcon = Icons.error_outline_rounded;
      statusLabel = 'Te falta dinero';
      yesNoTitle = '¿Te alcanza este mes? No';
      yesNoDetail =
          'Te faltan ${CurrencyFormat.formatMXN(-analysis.projectedEndOfMonthBuffer, includeDecimals: false)} para cubrir tus pagos del mes.';
    }

    // Simple Next Step
    final String goalTitle;
    final String goalAction;
    if (provider.emergencyFundEnabled &&
        emergencyGoalAmount > 0 &&
        netEmergencyReserves < emergencyGoalAmount) {
      goalTitle = 'Tu meta: Fondo de Emergencia';
      goalAction = isCovered && true45DayFree > 0
          ? 'Guarda +${CurrencyFormat.formatMXN(true45DayFree, includeDecimals: false)} libres para seguir avanzando hacia tu meta.'
          : 'Enfócate primero en cubrir tus pagos del mes antes de apartar dinero.';
    } else if (provider.includeExtraDebtGoal && analysis.totalDebt > 0) {
      goalTitle = 'Tu meta: Liquidar Deuda';
      goalAction = isCovered && true45DayFree > 0
          ? 'Puedes abonar +${CurrencyFormat.formatMXN(true45DayFree, includeDecimals: false)} extra a tus tarjetas este mes.'
          : 'Cubre tus pagos mínimos y fijos del mes antes de adelantar deuda.';
    } else {
      goalTitle = 'Tu meta: Invertir y Crecer';
      goalAction = isCovered && true45DayFree > 0
          ? 'Tus pagos están cubiertos. Tienes +${CurrencyFormat.formatMXN(true45DayFree, includeDecimals: false)} libres para invertir.'
          : 'Mantén tus pagos al día este mes.';
    }

    Widget simpleRow(String label, double amount, Color color) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            Text(
              CurrencyFormat.formatMXN(amount, includeDecimals: false),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withOpacity(0.45), width: 1.4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  yesNoTitle,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  yesNoDetail,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: AppTheme.textSecondary,
                    height: 1.35,
                  ),
                ),
                const Divider(color: AppTheme.border, height: 28),
                simpleRow('Tienes hoy', analysis.totalLiquidCash, Colors.white),
                if (analysis.monthlyIncomeProjectedRemaining > 0)
                  simpleRow(
                    'Por cobrar este mes',
                    analysis.monthlyIncomeProjectedRemaining,
                    AppTheme.emeraldGreen,
                  ),
                simpleRow(
                  'Por pagar este mes',
                  totalToPay,
                  AppTheme.alertCoral,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          PendingIncomesSection(provider: provider),
          PendingTransfersSection(provider: provider),
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EmergencyFundScreen(provider: provider),
              ),
            ),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(18),
                border:
                    Border.all(color: AppTheme.electricCyan.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 20,
                    color: AppTheme.electricCyan,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goalTitle,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          goalAction,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyRunwayCard(
      BuildContext context, AdvisorAnalysis analysis) {
    final emergencyAccounts = provider.accounts
        .where((a) => a.type != AccountType.creditCard && a.isEmergencyFund)
        .toList();
    final double dedicatedEmergency = emergencyAccounts
        .fold<double>(0.0, (sum, a) => sum + a.balance)
        .clamp(0.0, double.infinity);
    final double netReserves =
        (analysis.totalAssets - analysis.totalDebt).clamp(0.0, double.infinity);
    final double monthlyBurn =
        analysis.totalMonthlyCommitments + analysis.monthlyDirectExpense;
    final int goalMonths = provider.emergencyFundMonths;
    final double goalAmount = monthlyBurn * goalMonths;
    final double months =
        monthlyBurn > 0 ? (dedicatedEmergency / monthlyBurn) : 0.0;
    final double progress = goalAmount > 0
        ? (dedicatedEmergency / goalAmount).clamp(0.0, 1.0)
        : 0.0;
    final int pct = (progress * 100).round();
    final Color accent = months >= goalMonths
        ? AppTheme.emeraldGreen
        : (dedicatedEmergency > 0 ? AppTheme.electricCyan : AppTheme.amberGold);

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EmergencyFundScreen(provider: provider),
        ),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withOpacity(0.3)),
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_moon_outlined, size: 18, color: accent),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Fondo de Emergencia y Respaldo',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${months.toStringAsFixed(1)} meses',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            emergencyAccounts.isEmpty
                ? 'Solo cuenta el dinero apartado en cuentas marcadas como "Fondo de Emergencia" en Cuentas.'
                : 'Cuentas asignadas: ${emergencyAccounts.map((a) => a.name).join(', ')}',
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          for (final entry in [
            ('Fondo de Emergencia apartado', dedicatedEmergency, accent, true),
            ('Respaldo neto general (saldos − deudas)', netReserves, AppTheme.textSecondary, false),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.$1,
                      style: TextStyle(
                          fontSize: entry.$4 ? 12.5 : 11.5,
                          fontWeight:
                              entry.$4 ? FontWeight.w700 : FontWeight.normal,
                          color: entry.$4
                              ? Colors.white
                              : AppTheme.textSecondary),
                    ),
                  ),
                  Text(
                    CurrencyFormat.formatMXN(entry.$2, includeDecimals: false),
                    style: TextStyle(
                      fontSize: entry.$4 ? 13.5 : 12,
                      fontWeight: FontWeight.w700,
                      color: entry.$3,
                    ),
                  ),
                ],
              ),
            ),
          if (monthlyBurn > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Gasto fijo mensual',
                  style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                ),
                Text(
                  '${CurrencyFormat.formatMXN(monthlyBurn, includeDecimals: false)}/mes',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Meta ($goalMonths ${goalMonths == 1 ? 'mes' : 'meses'})',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  '${CurrencyFormat.formatMXN(dedicatedEmergency, includeDecimals: false)} / ${CurrencyFormat.formatMXN(goalAmount, includeDecimals: false)} ($pct%)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                backgroundColor: AppTheme.surface,
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }

  void _showEmergencyTransferSheet(
    BuildContext context, {
    required double suggestedAmount,
    required List<Account> emergencyAccounts,
  }) {
    final destAccountInitial = emergencyAccounts.first;
    final sourceCandidates = provider.accounts
        .where((a) =>
            a.type != AccountType.creditCard &&
            a.id != destAccountInitial.id &&
            a.balance > 0)
        .toList();

    if (sourceCandidates.isEmpty) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.card,
          title: const Text('Sin saldo disponible para transferir',
              style: TextStyle(color: Colors.white, fontSize: 16)),
          content: const Text(
            'No tienes cuentas de débito o efectivo con saldo positivo para transferir en este momento.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido',
                  style: TextStyle(color: AppTheme.electricCyan)),
            ),
          ],
        ),
      );
      return;
    }

    String sourceId = sourceCandidates.first.id;
    String destId = destAccountInitial.id;
    final initialAmount =
        suggestedAmount.clamp(0.0, sourceCandidates.first.balance);
    final amountCtrl = TextEditingController(
      text: initialAmount > 0 ? initialAmount.toStringAsFixed(0) : '',
    );
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final selectedSource = sourceCandidates
              .where((a) => a.id == sourceId)
              .firstOrNull ??
              sourceCandidates.first;
          final availableDest = emergencyAccounts
              .where((a) => a.id != selectedSource.id)
              .toList();
          if (availableDest.isEmpty) {
            availableDest.add(destAccountInitial);
          }
          if (!availableDest.any((a) => a.id == destId)) {
            destId = availableDest.first.id;
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Apartar a tu Fondo de Emergencia',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Haz la transferencia primero en tu app bancaria (o aparta el efectivo) y luego regístrala aquí.',
                    style:
                        TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: sourceId,
                    dropdownColor: AppTheme.surface,
                    style: const TextStyle(color: Colors.white, fontSize: 13.5),
                    decoration: const InputDecoration(
                      labelText: 'Desde qué cuenta sale el dinero',
                    ),
                    items: sourceCandidates
                        .map((a) => DropdownMenuItem(
                              value: a.id,
                              child: Text(
                                '${a.name} (${CurrencyFormat.formatMXN(a.balance, includeDecimals: false)})',
                              ),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      setModalState(() {
                        sourceId = val;
                        errorText = null;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: destId,
                    dropdownColor: AppTheme.surface,
                    style: const TextStyle(color: Colors.white, fontSize: 13.5),
                    decoration: const InputDecoration(
                      labelText: 'Hacia tu cuenta de Fondo de Emergencia',
                    ),
                    items: availableDest
                        .map((a) => DropdownMenuItem(
                              value: a.id,
                              child: Text(
                                '${a.name} (${CurrencyFormat.formatMXN(a.balance, includeDecimals: false)})',
                              ),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      setModalState(() {
                        destId = val;
                        errorText = null;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      labelText: 'Monto transferido (\$ MXN)',
                      helperText:
                          'Disponible en ${selectedSource.name}: ${CurrencyFormat.formatMXN(selectedSource.balance)}',
                      helperStyle: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary),
                      errorText: errorText,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final amt = double.tryParse(
                                amountCtrl.text.replaceAll(',', '').trim()) ??
                            0.0;
                        if (amt <= 0) {
                          setModalState(
                              () => errorText = 'Ingresa un monto mayor a \$0.');
                          return;
                        }
                        if (amt > selectedSource.balance + 0.01) {
                          setModalState(() => errorText =
                              'El monto supera el saldo real en ${selectedSource.name}.');
                          return;
                        }
                        await provider.addTransaction(
                          title: 'Aporte a Fondo de Emergencia',
                          amount: amt,
                          type: MovementType.transfer,
                          category: 'Fondo de Emergencia',
                          accountId: sourceId,
                          targetAccountId: destId,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Ya lo transferí • Registrar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.electricCyan,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAdvisorBanner(BuildContext context, FinancialInsight insight) {
    Color cardColor = AppTheme.electricCyan;
    IconData icon = Icons.lightbulb_outline;

    if (insight.type == InsightType.opportunity) {
      cardColor = AppTheme.amberGold;
      icon = Icons.auto_awesome;
    } else if (insight.type == InsightType.warning) {
      cardColor = AppTheme.alertCoral;
      icon = Icons.warning_amber_rounded;
    } else if (insight.type == InsightType.praise) {
      cardColor = AppTheme.emeraldGreen;
      icon = Icons.check_circle_outline;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardColor.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cardColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: cardColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        insight.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: cardColor,
                        ),
                      ),
                    ),
                    if (insight.highlightMetric != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        insight.highlightMetric!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  insight.message,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyCashflowCard(dynamic analysis) {
    final buffer = analysis.projectedEndOfMonthBuffer as double;
    final isBufferCovered = buffer >= 0;
    final pendingCash = analysis.pendingCommitments as double;
    final pendingCard = analysis.pendingCardCommitments as double;
    final paidFixed = analysis.paidCommitmentsThisMonth as double;
    final projections = analysis.monthlyProjections as List;
    final currentProj = projections.isNotEmpty ? projections.first : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Liquidez y Pendientes del Mes',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Proyección al cierre de mes sumando lo que falta por cobrar y pagar.',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isBufferCovered ? AppTheme.emeraldGreen : AppTheme.amberGold).withOpacity(0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isBufferCovered ? 'Cubierto con liquidez' : 'Faltan ${CurrencyFormat.formatMXN(-buffer, includeDecimals: false)}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isBufferCovered ? AppTheme.emeraldGreen : AppTheme.amberGold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ExpandableBreakdownRow(
            label: 'Liquidez disponible actual',
            amount: analysis.totalLiquidCash as double,
            color: AppTheme.emeraldGreen,
            items: currentProj?.liquidityItems ?? const [],
          ),
          if ((analysis.monthlyIncomeProjectedRemaining as double) > 0)
            ExpandableBreakdownRow(
              label: '+ Ingresos por recibir (Calendario)',
              amount: analysis.monthlyIncomeProjectedRemaining as double,
              color: AppTheme.electricCyan,
              items: currentProj?.incomeItems ?? const [],
            ),
          if ((analysis.creditMonthlyDue as double) > 0)
            ExpandableBreakdownRow(
              label: '− Tarjetas de Crédito (pago del mes)',
              amount: -(analysis.creditMonthlyDue as double),
              color: AppTheme.alertCoral,
              items: currentProj?.cardOrMsiItems ?? const [],
              negateItems: true,
            ),
          if (pendingCash > 0)
            ExpandableBreakdownRow(
              label: '− Gastos Fijos pendientes (Débito)',
              amount: -pendingCash,
              color: AppTheme.amberGold,
              items: currentProj?.fixedCashItems ?? const [],
              negateItems: true,
            ),
          if (pendingCard > 0)
            ExpandableBreakdownRow(
              label: 'ⓘ Domiciliados por cargar a TDC',
              amount: pendingCard,
              color: AppTheme.textMuted,
              items: currentProj?.fixedCardItems ?? const [],
            ),
          if (paidFixed > 0)
            ExpandableBreakdownRow(
              label: '✓ Gastos Fijos ya pagados este mes',
              amount: paidFixed,
              color: AppTheme.textMuted,
              items: currentProj?.paidFixedItems ?? const [],
            ),
          const Divider(color: AppTheme.border, height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '= Saldo proyectado al cierre de mes',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              Text(
                '${isBufferCovered ? '+' : ''}${CurrencyFormat.formatMXN(buffer, includeDecimals: false)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isBufferCovered ? AppTheme.emeraldGreen : AppTheme.alertCoral,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => onNavigateToTab(3),
              child: const Text(
                'Ver proyección 12 meses →',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.electricCyan,
                ),
              ),
            ),
          ),
          if (analysis.fundingSuggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.amberGold.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.amberGold.withOpacity(0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.tips_and_updates_outlined, size: 14, color: AppTheme.amberGold),
                      SizedBox(width: 6),
                      Text(
                        'Sugerencia para cubrir el mes',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.amberGold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...analysis.fundingSuggestions.map<Widget>(
                    (s) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '• Tomar de ${s.accountName} (${s.institution})',
                              style: const TextStyle(fontSize: 11.5, color: Colors.white),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            CurrencyFormat.formatMXN(s.suggestedAmount, includeDecimals: false),
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.amberGold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showMetricExplanationDialog(
    BuildContext context, {
    required String kind,
    required AdvisorAnalysis analysis,
  }) {
    final now = DateTime.now();
    final projections = analysis.monthlyProjections;
    final currentProj = projections.isNotEmpty ? projections.first : null;

    final String title;
    final String description;
    final Color accent;
    final List<({String label, String amount, Color color})> rows = [];

    if (kind == 'income') {
      title = 'Ingresos del Mes';
      description =
          'Suma el dinero que ya recibiste este mes más los ingresos que todavía esperas cobrar antes de que termine el mes.';
      accent = AppTheme.emeraldGreen;

      final received = provider.transactions.where((t) =>
          t.date.year == now.year &&
          t.date.month == now.month &&
          (t.type == MovementType.income ||
              t.type == MovementType.yieldAccrual) &&
          t.category != 'Pago Tarjeta');
      for (final t in received) {
        rows.add((
          label: '${t.title} (Recibido)',
          amount: CurrencyFormat.formatMXN(t.amount, includeDecimals: false),
          color: AppTheme.emeraldGreen,
        ));
      }
      if (currentProj != null) {
        for (final item in currentProj.incomeItems) {
          rows.add((
            label: '${item.title} (Por cobrar)',
            amount: CurrencyFormat.formatMXN(item.amount, includeDecimals: false),
            color: AppTheme.electricCyan,
          ));
        }
      }
      rows.add((
        label: 'Total del mes',
        amount: CurrencyFormat.formatMXN(
            analysis.monthlyIncomeExpectedTotal,
            includeDecimals: false),
        color: Colors.white,
      ));
    } else if (kind == 'expense') {
      title = 'Gastos y Obligaciones del Mes';
      description =
          'Incluye tus pagos de tarjetas de crédito del mes, gastos fijos pendientes en efectivo/débito y compras directas en débito o efectivo.';
      accent = AppTheme.alertCoral;

      if (currentProj != null) {
        for (final item in currentProj.cardOrMsiItems) {
          rows.add((
            label: '${item.title} (Tarjeta)',
            amount: CurrencyFormat.formatMXN(item.amount, includeDecimals: false),
            color: AppTheme.alertCoral,
          ));
        }
        for (final item in currentProj.fixedCashItems) {
          rows.add((
            label: '${item.title} (Fijo pendiente)',
            amount: CurrencyFormat.formatMXN(item.amount, includeDecimals: false),
            color: AppTheme.amberGold,
          ));
        }
      }
      if (analysis.monthlyDirectExpense > 0) {
        rows.add((
          label: 'Gastos directos (Débito / Efectivo)',
          amount: CurrencyFormat.formatMXN(
              analysis.monthlyDirectExpense,
              includeDecimals: false),
          color: AppTheme.textSecondary,
        ));
      }
      rows.add((
        label: 'Total del mes',
        amount: CurrencyFormat.formatMXN(
            analysis.monthlyExpenseTotal,
            includeDecimals: false),
        color: Colors.white,
      ));
    } else {
      title = 'Porcentaje Libre del Mes';
      description =
          'Es el porcentaje de tus ingresos del mes que no se va en tarjetas, fijos ni gastos. Entre más alto, mayor margen tienes para ahorrar o metas.';
      accent = AppTheme.electricCyan;

      rows.add((
        label: 'Ingresos totales del mes',
        amount: CurrencyFormat.formatMXN(
            analysis.monthlyIncomeExpectedTotal,
            includeDecimals: false),
        color: AppTheme.emeraldGreen,
      ));
      rows.add((
        label: 'Gastos y obligaciones del mes',
        amount:
            '-${CurrencyFormat.formatMXN(analysis.monthlyExpenseTotal, includeDecimals: false)}',
        color: AppTheme.alertCoral,
      ));
      rows.add((
        label: 'Excedente del mes',
        amount: CurrencyFormat.formatMXN(
            analysis.monthlyCashFlowSurplus,
            includeDecimals: false),
        color: AppTheme.electricCyan,
      ));
      rows.add((
        label: 'Porcentaje libre',
        amount: '${analysis.savingsRate.toStringAsFixed(0)}%',
        color: Colors.white,
      ));
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: accent.withOpacity(0.35)),
        ),
        title: Text(
          title,
          style: TextStyle(
              color: accent, fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12.5,
                      height: 1.35),
                ),
                const SizedBox(height: 14),
                const Divider(color: AppTheme.border, height: 1),
                const SizedBox(height: 10),
                ...rows.asMap().entries.map((entry) {
                  final isTotal = entry.key == rows.length - 1;
                  final r = entry.value;
                  return Padding(
                    padding: EdgeInsets.only(top: isTotal ? 6 : 0, bottom: 7),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.label,
                            style: TextStyle(
                              fontSize: isTotal ? 13 : 12,
                              fontWeight:
                                  isTotal ? FontWeight.w700 : FontWeight.normal,
                              color: isTotal
                                  ? Colors.white
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          r.amount,
                          style: TextStyle(
                            fontSize: isTotal ? 14 : 12.5,
                            fontWeight: FontWeight.w700,
                            color: r.color,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido',
                style: TextStyle(color: AppTheme.electricCyan)),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniGoalReminders(BuildContext context) {
    final activeGoals = provider.miniGoals
        .where((g) => !g.isCompleted && g.remainingToSave > 0)
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    if (activeGoals.isEmpty) return const SizedBox.shrink();

    return Column(
      children: activeGoals.map((goal) {
        final monthlyNeed = goal.recommendedMonthlySave();
        final destAcc = goal.accountId != null
            ? provider.accounts
                .where((a) => a.id == goal.accountId)
                .firstOrNull
            : null;
        final destLabel =
            destAcc != null ? ' en ${destAcc.name}' : '';
        final monthlyLabel = monthlyNeed > 0
            ? ' (sugerido: ~${CurrencyFormat.formatMXN(monthlyNeed, includeDecimals: false)}/mes)'
            : '';

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.amberGold.withOpacity(0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.amberGold.withOpacity(0.35)),
          ),
          child: Row(
            children: [
              const Icon(Icons.flag_outlined,
                  size: 18, color: AppTheme.amberGold),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mini-Meta: ${goal.name}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Faltan ${CurrencyFormat.formatMXN(goal.remainingToSave, includeDecimals: false)}$monthlyLabel para el ${goal.dueDate.day}/${goal.dueDate.month}/${goal.dueDate.year}$destLabel.',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Colors.white70,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  if (goal.accountId == null) {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) =>
                          MiniGoalSheet(provider: provider, existingGoal: goal),
                    );
                    return;
                  }
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => MiniGoalTransferSheet(
                      provider: provider,
                      goal: goal,
                      suggestedAmount:
                          monthlyNeed > 0 ? monthlyNeed : goal.remainingToSave,
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  backgroundColor: AppTheme.amberGold.withOpacity(0.2),
                  foregroundColor: AppTheme.amberGold,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Apartar',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCategoryAccountTips() {
    final linked = provider.accounts
        .where((a) => a.allowedCategories.isNotEmpty && a.balance > 0)
        .toList();
    if (linked.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        ...linked.map((acc) {
          final catsLabel = acc.allowedCategories.join(', ');
          final totalAvg = acc.allowedCategories.fold<double>(
            0.0,
            (s, c) => s + provider.averageMonthlySpendForCategory(c),
          );
          final storeSuffix = acc.restrictionNote.isNotEmpty
              ? ' (${acc.restrictionNote})'
              : '';
          final msg = totalAvg > 0
              ? 'Tienes ${CurrencyFormat.formatMXN(acc.balance)} en ${acc.name}$storeSuffix. Normalmente gastas ~${CurrencyFormat.formatMXN(totalAvg, includeDecimals: false)}/mes en $catsLabel — úsalos ahí para cuidar tu efectivo.'
              : 'Tienes ${CurrencyFormat.formatMXN(acc.balance)} en ${acc.name}$storeSuffix disponibles para cubrir gastos de $catsLabel.';

          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.amberGold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.amberGold.withOpacity(0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(Icons.confirmation_number_outlined,
                      size: 18, color: AppTheme.amberGold),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    msg,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String subtitle,
    required String amount,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 14, color: accentColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textMuted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                amount,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                    fontSize: 10, color: AppTheme.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountItem(Account acc) {
    final bool isCredit = acc.type == AccountType.creditCard;
    final bool hasYield = acc.annualYieldRate > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isCredit
                  ? AppTheme.alertCoral.withOpacity(0.12)
                  : hasYield
                      ? AppTheme.purpleGlow.withOpacity(0.12)
                      : AppTheme.electricCyan.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isCredit
                  ? Icons.credit_card
                  : hasYield
                      ? Icons.savings_outlined
                      : Icons.account_balance_wallet_outlined,
              color: isCredit
                  ? AppTheme.alertCoral
                  : hasYield
                      ? AppTheme.purpleGlow
                      : AppTheme.electricCyan,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  acc.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                Text(
                  hasYield
                      ? '${acc.institution} • Rinde ${CurrencyFormat.formatRate(acc.annualYieldRate)}'
                      : acc.institution,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormat.formatMXN(acc.balance),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isCredit ? AppTheme.alertCoral : Colors.white,
                ),
              ),
              if (hasYield)
                Text(
                  '+${CurrencyFormat.formatMXN(acc.monthlyYieldGenerated, includeDecimals: false)}/mes',
                  style: const TextStyle(fontSize: 10, color: AppTheme.emeraldGreen, fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(BuildContext context, Transaction tx) {
    final bool isPositive = tx.type == MovementType.income || tx.type == MovementType.yieldAccrual;
    final cat = provider.categoryByName(tx.category, isIncome: isPositive);
    final Color iconColor = cat?.color ??
        (isPositive ? AppTheme.emeraldGreen : AppTheme.textSecondary);
    final IconData iconData =
        cat?.iconData ?? (isPositive ? Icons.add : Icons.remove);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => showTransactionDetailDialog(context, provider, tx),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: cat != null
                ? iconColor.withOpacity(0.16)
                : (isPositive
                    ? AppTheme.emeraldGreen.withOpacity(0.15)
                    : AppTheme.surface),
            child: Icon(
              iconData,
              size: 16,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                Text(
                  '${tx.category} • ${tx.date.day}/${tx.date.month}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            '${isPositive ? "+" : "-"}${CurrencyFormat.formatMXN(tx.amount)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isPositive ? AppTheme.emeraldGreen : Colors.white,
            ),
          ),
        ],
      ),
          ),
        ),
      ),
    );
  }
}

class _CashflowCardToggle extends StatefulWidget {
  final AdvisorAnalysis analysis;
  final WidgetBuilder monthlyContentBuilder;

  const _CashflowCardToggle({
    required this.analysis,
    required this.monthlyContentBuilder,
  });

  @override
  State<_CashflowCardToggle> createState() => _CashflowCardToggleState();
}

class _CashflowCardToggleState extends State<_CashflowCardToggle> {
  bool _byDates = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Center(child: Text('Vista Mensual')),
                selected: !_byDates,
                selectedColor: AppTheme.electricCyan.withOpacity(0.22),
                backgroundColor: AppTheme.card,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: !_byDates ? Colors.white : AppTheme.textSecondary,
                ),
                onSelected: (_) => setState(() => _byDates = false),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                label: Center(
                  child: Text(
                    'Por Fechas (${widget.analysis.cashflowTimeline.length})',
                  ),
                ),
                selected: _byDates,
                selectedColor: AppTheme.electricCyan.withOpacity(0.22),
                backgroundColor: AppTheme.card,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _byDates ? Colors.white : AppTheme.textSecondary,
                ),
                onSelected: (_) => setState(() => _byDates = true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (!_byDates)
          widget.monthlyContentBuilder(context)
        else
          _buildTimelineCard(widget.analysis),
      ],
    );
  }

  Widget _buildTimelineCard(AdvisorAnalysis analysis) {
    final events = analysis.cashflowTimeline;
    final hasDip = analysis.lowestTimelineBalance < -0.5 &&
        analysis.lowestTimelineDate != null;
    final lowestDate = analysis.lowestTimelineDate;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasDip
              ? AppTheme.alertCoral.withOpacity(0.45)
              : AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Próximos Pagos y Cobros (45 días)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Ordenado por fecha exacta para detectar si algún día te falta liquidez.',
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (hasDip ? AppTheme.alertCoral : AppTheme.emeraldGreen)
                      .withOpacity(0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  hasDip ? 'Bache temporal' : 'Sin baches',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color:
                        hasDip ? AppTheme.alertCoral : AppTheme.emeraldGreen,
                  ),
                ),
              ),
            ],
          ),
          if (hasDip && lowestDate != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.alertCoral.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppTheme.alertCoral.withOpacity(0.3)),
              ),
              child: Text(
                'Punto más bajo el ${lowestDate.day}/${lowestDate.month}: te faltarían ${CurrencyFormat.formatMXN(-analysis.lowestTimelineBalance, includeDecimals: false)} antes del siguiente cobro.',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Colors.white,
                  height: 1.3,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Saldo inicial hoy',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              Text(
                CurrencyFormat.formatMXN(
                    analysis.totalLiquidCash, includeDecimals: false),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.emeraldGreen,
                ),
              ),
            ],
          ),
          const Divider(color: AppTheme.border, height: 14),
          if (events.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No hay pagos ni cobros programados en los próximos 45 días.',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            )
          else
            ...events.map((ev) {
              final isIncome = ev.delta >= 0;
              final balPositive = ev.runningBalance >= 0;
              final dateStr =
                  '${ev.date.day.toString().padLeft(2, '0')}/${ev.date.month.toString().padLeft(2, '0')}';
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ev.title,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            ev.subtitle,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${isIncome ? "+" : "-"}${CurrencyFormat.formatMXN(ev.delta.abs(), includeDecimals: false)}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isIncome
                                ? AppTheme.emeraldGreen
                                : AppTheme.alertCoral,
                          ),
                        ),
                        Text(
                          'Saldo: ${CurrencyFormat.formatMXN(ev.runningBalance, includeDecimals: false)}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: balPositive
                                ? AppTheme.textSecondary
                                : AppTheme.alertCoral,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

