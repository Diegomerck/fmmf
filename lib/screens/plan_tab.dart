import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/currency_format.dart';
import '../models/account.dart';
import '../models/budget_commitment.dart';
import '../models/financial_insight.dart';
import '../models/mini_goal.dart';
import '../models/recurring_income.dart';
import '../models/savings_rule.dart';
import '../providers/finance_provider.dart';
import '../services/advisor_engine.dart';
import 'pay_schedule_screen.dart';
import 'widgets/commitment_form_sheet.dart';
import 'widgets/expandable_breakdown_row.dart';
import 'widgets/mini_goal_sheet.dart';
import 'widgets/mini_goal_transfer_sheet.dart';
import 'widgets/pending_incomes_section.dart';
import 'widgets/pending_transfers_section.dart';
import 'widgets/recurring_income_sheet.dart';
import 'widgets/savings_rule_sheet.dart';

class PlanTab extends StatelessWidget {
  final FinanceProvider provider;

  const PlanTab({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final analysis = provider.analysis;

    int score = 65;
    if (analysis.savingsRate >= 20) score += 15;
    if (analysis.runwayMonths >= 3) score += 10;
    if (analysis.monthlyPassiveYield >= 500) score += 10;
    if (analysis.totalDebt > analysis.totalLiquidCash) score -= 20;
    score = score.clamp(10, 100);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pending items first
          PendingIncomesSection(provider: provider),
          PendingTransfersSection(provider: provider),

          // 1. Ingresos Recurrentes y Calendario
          _buildSectionRow(
            title: 'Ingresos y Calendario',
            icon: Icons.payments_outlined,
            color: AppTheme.electricCyan,
            actionLabel: 'Agregar',
            onAction: () {
              if (provider.accounts.where((a) => a.type != AccountType.creditCard).isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppTheme.amberGold,
                    content: Text('Primero agrega una cuenta de débito o ahorros en "Cuentas".'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => RecurringIncomeSheet(provider: provider),
              );
            },
          ),
          const SizedBox(height: 8),
          if (provider.recurringIncomes.isEmpty)
            _emptyNote('Configura tu sueldo o ingresos (diario, semanal, quincenal, mensual o personalizado).')
          else
            ...provider.recurringIncomes.map((inc) => _buildIncomeCard(context, inc)),

          const SizedBox(height: 20),
          const Divider(color: AppTheme.border),
          const SizedBox(height: 16),

          // 1b. Mini-Metas (Gastos Periódicos)
          _buildSectionRow(
            title: 'Mini-Metas Periódicas',
            icon: Icons.flag_outlined,
            color: AppTheme.amberGold,
            actionLabel: 'Agregar',
            onAction: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => MiniGoalSheet(provider: provider),
            ),
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final activeGoals = provider.miniGoals
                  .where((g) => g.isVisibleInActiveSection())
                  .toList();
              final archivedGoals = provider.miniGoals
                  .where((g) => !g.isVisibleInActiveSection())
                  .toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (activeGoals.isEmpty)
                    _emptyNote(
                        'Agrega pagos que haces cada varios meses (teléfono, seguro, predial) para saber si apartar o si tu ingreso los cubre.')
                  else
                    ...activeGoals
                        .map((g) => _buildMiniGoalCard(context, g, analysis)),
                  if (archivedGoals.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.card.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Theme(
                        data: Theme.of(context)
                            .copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 0),
                          childrenPadding:
                              const EdgeInsets.fromLTRB(10, 0, 10, 10),
                          iconColor: AppTheme.emeraldGreen,
                          collapsedIconColor: AppTheme.textSecondary,
                          title: Text(
                            'Mini-Metas Completadas (${archivedGoals.length})',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.emeraldGreen,
                            ),
                          ),
                          children: archivedGoals
                              .map((g) =>
                                  _buildMiniGoalCard(context, g, analysis))
                              .toList(),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),

          const SizedBox(height: 20),
          const Divider(color: AppTheme.border),
          const SizedBox(height: 14),

          // 2. Reglas de Ahorro Automático
          _buildSectionRow(
            title: 'Reglas de Ahorro',
            icon: Icons.autorenew_rounded,
            color: AppTheme.emeraldGreen,
            actionLabel: 'Nueva Regla',
            onAction: () {
              if (provider.accounts.length < 2) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppTheme.amberGold,
                    content: Text('Necesitas al menos 2 cuentas para crear una regla de ahorro.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => SavingsRuleSheet(provider: provider),
              );
            },
          ),
          const SizedBox(height: 8),
          if (provider.savingsRules.isEmpty)
            _emptyNote('Aparta un % de cada ingreso o un monto periódico hacia tus Ahorros (siempre con tu confirmación).')
          else
            ...provider.savingsRules.map((r) => _buildRuleCard(context, r)),

          const SizedBox(height: 20),
          const Divider(color: AppTheme.border),
          const SizedBox(height: 14),

          // 3. Gastos Fijos Mensuales
          _buildSectionRow(
            title: 'Gastos Fijos Mensuales',
            icon: Icons.calendar_month_outlined,
            color: AppTheme.amberGold,
            actionLabel: 'Agregar',
            onAction: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => CommitmentFormSheet(provider: provider),
              );
            },
          ),
          const SizedBox(height: 8),
          if (provider.commitments.isEmpty)
            _emptyNote('Agrega renta, internet o suscripciones para reservarlos en tu Safe-to-Spend.')
          else
            ...provider.commitments.map((c) => _buildCommitmentCard(context, c)),

          const SizedBox(height: 24),
          const Divider(color: AppTheme.border),
          const SizedBox(height: 16),

          // 4. Proyección Mensual (12 Meses: Ingresos vs MSI + Gastos Fijos)
          _buildMonthlyForecastSection(analysis.monthlyProjections),

          const SizedBox(height: 24),
          const Divider(color: AppTheme.border),
          const SizedBox(height: 16),

          // 5. Super Asesor Diagnostics
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF064E3B), Color(0xFF047857)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white.withOpacity(0.15),
                  child: Text(
                    '$score',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SUPER ASESOR • DIAGNÓSTICO',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white70, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Runway: ${analysis.runwayMonths.toStringAsFixed(1)} meses • Ahorro: ${analysis.savingsRate.toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...analysis.insights.map((i) => _buildInsightCard(i)),
        ],
      ),
    );
  }

  Widget _buildSectionRow({
    required String title,
    required IconData icon,
    required Color color,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          icon: Icon(Icons.add, size: 16, color: color),
          label: Text(actionLabel, style: TextStyle(color: color, fontSize: 13)),
          onPressed: onAction,
        ),
      ],
    );
  }

  Widget _emptyNote(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
    );
  }

  Widget _buildIncomeCard(BuildContext context, RecurringIncome inc) {
    final accName = provider.accounts.where((a) => a.id == inc.accountId).map((a) => a.name).firstOrNull ?? 'Cuenta';
    final freqText = switch (inc.frequency) {
      IncomeFrequency.daily => 'Diario',
      IncomeFrequency.weekly => 'Semanal',
      IncomeFrequency.biweekly => 'Quincenal',
      IncomeFrequency.monthly => 'Mensual (Día ${inc.payDay})',
      IncomeFrequency.yearly => 'Anual',
      IncomeFrequency.custom => 'Calendario Personalizado',
    };

    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => RecurringIncomeSheet(provider: provider, existingIncome: inc),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(inc.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text('$freqText • $accName', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            Text(
              '+${CurrencyFormat.formatMXN(inc.amount, includeDecimals: false)}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.emeraldGreen),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.electricCyan.withOpacity(0.15),
                foregroundColor: AppTheme.electricCyan,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: AppTheme.electricCyan.withOpacity(0.4)),
                ),
              ),
              icon: const Icon(Icons.calendar_month, size: 14),
              label: const Text('Calendario', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PayScheduleScreen(provider: provider, income: inc)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleCard(BuildContext context, SavingsRule r) {
    final targetName = provider.accounts.where((a) => a.id == r.targetAccountId).map((a) => a.name).firstOrNull ?? 'Ahorros';
    final detailText = switch (r.frequency) {
      RoutingFrequency.onIncome => '${r.percentage.toStringAsFixed(0)}% de cada ingreso → $targetName',
      RoutingFrequency.daily => '${CurrencyFormat.formatMXN(r.fixedAmount, includeDecimals: false)} diarios → $targetName',
      RoutingFrequency.weekly => '${CurrencyFormat.formatMXN(r.fixedAmount, includeDecimals: false)} semanales → $targetName',
      RoutingFrequency.monthly => '${CurrencyFormat.formatMXN(r.fixedAmount, includeDecimals: false)} mensuales → $targetName',
      RoutingFrequency.yearly => '${CurrencyFormat.formatMXN(r.fixedAmount, includeDecimals: false)} anuales → $targetName',
    };

    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => SavingsRuleSheet(provider: provider, existingRule: r),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                  Text(detailText, style: const TextStyle(fontSize: 12, color: AppTheme.emeraldGreen)),
                ],
              ),
            ),
            Switch(
              value: r.isActive,
              activeColor: AppTheme.emeraldGreen,
              onChanged: (val) => provider.updateSavingsRule(r.copyWith(isActive: val)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommitmentCard(BuildContext context, BudgetCommitment c) {
    final linkedAcc = provider.accounts.where((a) => a.id == c.accountId).firstOrNull;
    final accLabel = linkedAcc != null
        ? '${linkedAcc.name}${c.isAutopay ? " • Domiciliado" : ""}'
        : (c.isAutopay ? 'Domiciliado' : null);

    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => CommitmentFormSheet(provider: provider, existingCommitment: c),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Checkbox(
              value: c.isPaidThisMonth,
              activeColor: AppTheme.emeraldGreen,
              onChanged: (_) => provider.toggleCommitmentPaid(c.id),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.isPaidThisMonth ? AppTheme.textMuted : Colors.white,
                      decoration: c.isPaidThisMonth ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  Text(
                    'Día ${c.dueDay}${accLabel != null ? " • $accLabel" : ""} • ${c.isPaidThisMonth ? "Pagado" : "Pendiente"}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            Text(
              CurrencyFormat.formatMXN(c.amount, includeDecimals: false),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: c.isPaidThisMonth ? AppTheme.textMuted : AppTheme.amberGold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyForecastSection(List<dynamic> projections) {
    if (projections.isEmpty) return const SizedBox.shrink();
    const monthNames = [
      '',
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    final coveredCount = projections.where((p) => p.isCovered as bool).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Row(
                children: [
                  Icon(Icons.timeline_rounded, size: 18, color: AppTheme.electricCyan),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Proyección Mensual (12 Meses)',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (coveredCount == projections.length
                        ? AppTheme.emeraldGreen
                        : AppTheme.amberGold)
                    .withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$coveredCount/${projections.length} cubiertos',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: coveredCount == projections.length
                      ? AppTheme.emeraldGreen
                      : AppTheme.amberGold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Compara tus ingresos programados contra tus cuotas MSI y gastos fijos mes a mes.',
          style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 10),
        ...projections.map((p) {
          final isCurrent = p.isCurrentMonth as bool;
          final label = '${monthNames[p.month as int]} ${p.year}${isCurrent ? ' (Resto actual)' : ''}';
          final net = p.netMonthlyAvailable as double;
          final cum = p.cumulativeBalance as double;
          final isOk = net >= 0;
          final statusColor = isOk ? AppTheme.emeraldGreen : AppTheme.alertCoral;
          final msi = p.cardOrMsiDue as double;
          final fCash = p.fixedCashDue as double;
          final fCard = p.fixedCardDue as double;
          final inc = p.expectedIncome as double;
          final startLiq = p.startingLiquidity as double;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isCurrent
                    ? AppTheme.electricCyan.withOpacity(0.5)
                    : AppTheme.border,
              ),
            ),
            child: Theme(
              data: ThemeData.dark().copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                title: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isCurrent
                                ? 'Disp. + Ingresos: ${CurrencyFormat.formatMXN(startLiq + inc, includeDecimals: false)} • Oblig.: ${CurrencyFormat.formatMXN(msi + fCash, includeDecimals: false)}'
                                : 'Ingresos: ${CurrencyFormat.formatMXN(inc, includeDecimals: false)} • Oblig.: ${CurrencyFormat.formatMXN(msi + fCash + fCard, includeDecimals: false)}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${isOk ? '+' : ''}${CurrencyFormat.formatMXN(net, includeDecimals: false)}',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                        Text(
                          'Acum: ${CurrencyFormat.formatMXN(cum, includeDecimals: false)}',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: cum >= 0 ? AppTheme.textMuted : AppTheme.amberGold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                children: [
                  const Divider(color: AppTheme.border, height: 12),
                  if (isCurrent)
                    ExpandableBreakdownRow(
                      label: 'Liquidez actual',
                      amount: startLiq,
                      color: AppTheme.emeraldGreen,
                      items: p.liquidityItems,
                    ),
                  ExpandableBreakdownRow(
                    label: isCurrent ? '+ Ingresos por recibir' : 'Ingresos programados',
                    amount: inc,
                    color: AppTheme.electricCyan,
                    items: p.incomeItems,
                  ),
                  if (msi > 0)
                    ExpandableBreakdownRow(
                      label: isCurrent
                          ? '− Tarjetas (pago del mes)'
                          : '− Cuotas MSI (${p.activeMsiCount} planes)',
                      amount: -msi,
                      color: AppTheme.alertCoral,
                      items: p.cardOrMsiItems,
                      negateItems: true,
                    ),
                  if (fCash > 0)
                    ExpandableBreakdownRow(
                      label: '− Gastos Fijos y Mini-Metas',
                      amount: -fCash,
                      color: AppTheme.amberGold,
                      items: p.fixedCashItems,
                      negateItems: true,
                    ),
                  if (fCard > 0)
                    ExpandableBreakdownRow(
                      label: isCurrent
                          ? 'ⓘ Domiciliados por cargar a TDC'
                          : '− Gastos Fijos domiciliados a TDC',
                      amount: isCurrent ? fCard : -fCard,
                      color: isCurrent ? AppTheme.textMuted : AppTheme.amberGold,
                      items: p.fixedCardItems,
                      negateItems: !isCurrent,
                    ),
                  if (isCurrent && (p.paidFixedItems as List).isNotEmpty)
                    ExpandableBreakdownRow(
                      label: '✓ Gastos Fijos ya pagados este mes',
                      amount: (p.paidFixedItems as List).fold<double>(0.0, (s, e) => s + (e.amount as double)),
                      color: AppTheme.textMuted,
                      items: p.paidFixedItems,
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildInsightCard(FinancialInsight insight) {
    Color cardColor = AppTheme.electricCyan;
    IconData icon = Icons.info_outline;
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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardColor.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: cardColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(insight.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cardColor)),
              ),
              if (insight.highlightMetric != null)
                Text(insight.highlightMetric!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 6),
          Text(insight.message, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.35)),
        ],
      ),
    );
  }

  Widget _buildMiniGoalCard(
    BuildContext context,
    MiniGoal goal,
    AdvisorAnalysis analysis,
  ) {
    final double monthlyNeed = goal.recommendedMonthlySave();
    final matchingProj = analysis.monthlyProjections
        .where((p) => p.year == goal.dueDate.year && p.month == goal.dueDate.month)
        .firstOrNull;
    final linkedAccount = goal.accountId != null
        ? provider.accounts.where((a) => a.id == goal.accountId).firstOrNull
        : null;
    final double totalEarmarkedInAcc = linkedAccount != null
        ? provider.earmarkedMiniGoalsForAccount(linkedAccount.id)
        : 0.0;
    final bool accountShortForEarmark = !goal.isCompleted &&
        linkedAccount != null &&
        goal.savedAmount > 0 &&
        linkedAccount.balance + 0.01 < totalEarmarkedInAcc;

    final String repeatLabel = goal.repeatLabel;
    final String endLabel = goal.endDate != null
        ? ' • Fin: ${goal.endDate!.day}/${goal.endDate!.month}/${goal.endDate!.year}'
        : '';

    final String projectionMsg;
    final Color projectionColor;
    if (goal.isCompleted) {
      final doneDate = goal.completedAt;
      projectionMsg = doneDate != null
          ? 'Meta completada el ${doneDate.day}/${doneDate.month}/${doneDate.year}. Puedes editarla o reactivarla si la vuelves a necesitar.'
          : 'Meta completada. Puedes editarla o reactivarla si la vuelves a necesitar.';
      projectionColor = AppTheme.emeraldGreen;
    } else if (goal.remainingToSave <= 0) {
      projectionMsg = '¡Ya tienes completo este pago!';
      projectionColor = AppTheme.emeraldGreen;
    } else if (matchingProj != null) {
      if (matchingProj.cumulativeBalance >= 0) {
        projectionMsg =
            'Sin apartar antes, con tu ingreso y saldo proyectado sí te alcanza ese mes (+${CurrencyFormat.formatMXN(matchingProj.cumulativeBalance, includeDecimals: false)}).';
        projectionColor = AppTheme.emeraldGreen;
      } else {
        projectionMsg =
            'Sin apartar antes, ese mes te faltarían ${CurrencyFormat.formatMXN(-matchingProj.cumulativeBalance, includeDecimals: false)}. Conviene apartar ~${CurrencyFormat.formatMXN(monthlyNeed, includeDecimals: false)}/mes.';
        projectionColor = AppTheme.amberGold;
      }
    } else {
      final months = goal.monthsUntilDue();
      final estCap = analysis.estimatedMonthlySavingsCapacity *
          (months > 0 ? months : 1);
      if (estCap >= goal.remainingToSave) {
        projectionMsg =
            'Tu capacidad de ahorro proyectada cubre este pago; si prefieres apartarlo antes, son ~${CurrencyFormat.formatMXN(monthlyNeed, includeDecimals: false)}/mes.';
        projectionColor = AppTheme.emeraldGreen;
      } else {
        projectionMsg =
            'Conviene apartar ~${CurrencyFormat.formatMXN(monthlyNeed, includeDecimals: false)}/mes para llegar cómodo a la fecha.';
        projectionColor = AppTheme.amberGold;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_outlined,
                  size: 18, color: AppTheme.amberGold),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      goal.isCompleted
                          ? 'Completada • $repeatLabel'
                          : 'Fecha: ${goal.dueDate.day}/${goal.dueDate.month}/${goal.dueDate.year} • $repeatLabel$endLabel',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (goal.isCompleted)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.emeraldGreen.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Completada',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.emeraldGreen,
                    ),
                  ),
                ),
              Text(
                CurrencyFormat.formatMXN(goal.targetAmount,
                    includeDecimals: false),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert,
                    size: 18, color: AppTheme.textSecondary),
                color: AppTheme.surface,
                onSelected: (val) {
                  if (val == 'edit') {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) =>
                          MiniGoalSheet(provider: provider, existingGoal: goal),
                    );
                  } else if (val == 'undo') {
                    provider.undoLastMiniGoalPayment(goal);
                  } else if (val == 'reactivate') {
                    provider.reactivateMiniGoal(goal);
                  } else if (val == 'delete') {
                    provider.deleteMiniGoal(goal.id);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child:
                        Text('Editar', style: TextStyle(color: Colors.white)),
                  ),
                  if (goal.paymentHistory.isNotEmpty)
                    const PopupMenuItem(
                      value: 'undo',
                      child: Text('Deshacer último pago',
                          style: TextStyle(color: AppTheme.amberGold)),
                    ),
                  if (goal.isCompleted)
                    const PopupMenuItem(
                      value: 'reactivate',
                      child: Text('Reactivar meta',
                          style: TextStyle(color: AppTheme.electricCyan)),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Eliminar',
                        style: TextStyle(color: AppTheme.alertCoral)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: goal.progress,
                    minHeight: 5,
                    backgroundColor: AppTheme.surface,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppTheme.amberGold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Apartado: ${CurrencyFormat.formatMXN(goal.savedAmount, includeDecimals: false)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.amberGold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (linkedAccount != null && !goal.isCompleted) ...[
            Text(
              'Guardado en: ${linkedAccount.name} (${CurrencyFormat.formatMXN(linkedAccount.balance, includeDecimals: false)})',
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 4),
          ],
          if (accountShortForEarmark) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.alertCoral.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.alertCoral.withOpacity(0.35)),
              ),
              child: Text(
                'Ojo: el saldo real de ${linkedAccount.name} (${CurrencyFormat.formatMXN(linkedAccount.balance, includeDecimals: false)}) ya no alcanza para cubrir todo lo apartado (${CurrencyFormat.formatMXN(totalEarmarkedInAcc, includeDecimals: false)}).',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.alertCoral,
                  height: 1.3,
                ),
              ),
            ),
          ],
          Text(
            projectionMsg,
            style: TextStyle(
              fontSize: 11.5,
              color: projectionColor,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          if (!goal.isCompleted)
            Row(
              children: [
                if (goal.remainingToSave > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        final addAmt = monthlyNeed > 0
                            ? monthlyNeed
                            : goal.remainingToSave;
                        if (goal.accountId == null) {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => MiniGoalSheet(
                                provider: provider, existingGoal: goal),
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
                            suggestedAmount: addAmt,
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.amberGold,
                        side: BorderSide(
                            color: AppTheme.amberGold.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: Text(
                        '+ Apartar ${CurrencyFormat.formatMXN(monthlyNeed > 0 ? monthlyNeed : goal.remainingToSave, includeDecimals: false)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                if (goal.remainingToSave > 0) const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _confirmMarkMiniGoalPaid(context, goal),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.emeraldGreen.withOpacity(0.2),
                      foregroundColor: AppTheme.emeraldGreen,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text(
                      'Marcar pagado en este periodo',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _confirmMarkMiniGoalPaid(BuildContext context, MiniGoal goal) {
    final bool hasNext = goal.hasNextCycleBeforeEnd;
    final nextDate = goal.nextCycleDate();
    bool completeEarly = !hasNext;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.card,
          title: Text(
            'Confirmar pago • ${goal.name}',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Confirmas que ya pagaste ${CurrencyFormat.formatMXN(goal.targetAmount)}?',
                style: const TextStyle(color: Colors.white, fontSize: 13.5),
              ),
              const SizedBox(height: 8),
              Text(
                completeEarly
                    ? 'Se marcará como Completada y quedará visible este mes antes de pasar a tu historial de Mini-Metas Completadas.'
                    : 'La próxima fecha se actualizará al ${nextDate.day}/${nextDate.month}/${nextDate.year}. (Siempre puedes deshacerlo en el menú ⋮).',
                style:
                    const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              if (hasNext) ...[
                const SizedBox(height: 10),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeColor: AppTheme.emeraldGreen,
                  title: const Text(
                    'Ya no haré este pago (completar meta)',
                    style: TextStyle(color: Colors.white, fontSize: 12.5),
                  ),
                  value: completeEarly,
                  onChanged: (v) =>
                      setDialogState(() => completeEarly = v ?? false),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                provider.markMiniGoalPaid(goal, completeGoal: completeEarly);
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.emeraldGreen,
                foregroundColor: Colors.black,
              ),
              child: const Text('Sí, confirmar pago'),
            ),
          ],
        ),
      ),
    );
  }
}

