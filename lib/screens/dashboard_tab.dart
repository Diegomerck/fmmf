import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_format.dart';
import '../../models/account.dart';
import '../../models/transaction.dart';
import '../../models/financial_insight.dart';
import '../../providers/finance_provider.dart';
import 'widgets/safe_to_spend_card.dart';
import 'widgets/quick_entry_sheet.dart';
import 'widgets/pending_transfers_section.dart';
import 'widgets/pending_incomes_section.dart';
import 'widgets/expandable_breakdown_row.dart';

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
    final topInsight = analysis.insights.isNotEmpty ? analysis.insights.first : null;

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
            onQuickAdd: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => QuickEntrySheet(provider: provider),
              );
            },
          ),
          const SizedBox(height: 16),

          // Pending Incomes & Savings Transfers to Confirm
          PendingIncomesSection(provider: provider),
          PendingTransfersSection(provider: provider),

          // Super Advisor Proactive Banner
          if (topInsight != null) ...[
            _buildAdvisorBanner(context, topInsight),
            const SizedBox(height: 16),
          ],

          // Quick Financial Metrics Grid
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  title: analysis.monthlyIncomeProjectedRemaining > 0
                      ? 'Ingresos (+Por recibir)'
                      : 'Ingresos Mes',
                  amount: CurrencyFormat.formatMXN(
                    analysis.monthlyIncomeExpectedTotal,
                    includeDecimals: false,
                  ),
                  icon: Icons.arrow_downward_rounded,
                  accentColor: AppTheme.emeraldGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  title: 'Oblig. / Gasto Mes',
                  amount: CurrencyFormat.formatMXN(analysis.monthlyExpenseTotal, includeDecimals: false),
                  icon: Icons.arrow_upward_rounded,
                  accentColor: AppTheme.alertCoral,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  title: 'Ahorro / Flujo',
                  amount: '${analysis.savingsRate.toStringAsFixed(0)}%',
                  icon: Icons.trending_up_rounded,
                  accentColor: AppTheme.electricCyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildMonthlyCashflowCard(analysis),
          const SizedBox(height: 22),

          // Where is the Money at (Accounts preview)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '¿Dónde está tu dinero?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
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
              const Text(
                'Últimos Movimientos',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
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
            ...provider.transactions.take(5).map((tx) => _buildTransactionItem(tx)),
        ],
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
                  children: [
                    Text(
                      insight.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: cardColor,
                      ),
                    ),
                    if (insight.highlightMetric != null)
                      Text(
                        insight.highlightMetric!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
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
              const Text(
                'Liquidez y Pendientes del Mes',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
              ),
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

  Widget _buildMetricTile({
    required String title,
    required String amount,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.card,
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
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
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
        ],
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

  Widget _buildTransactionItem(Transaction tx) {
    final bool isPositive = tx.type == MovementType.income || tx.type == MovementType.yieldAccrual;

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
          CircleAvatar(
            radius: 16,
            backgroundColor: isPositive
                ? AppTheme.emeraldGreen.withOpacity(0.15)
                : AppTheme.surface,
            child: Icon(
              isPositive ? Icons.add : Icons.remove,
              size: 16,
              color: isPositive ? AppTheme.emeraldGreen : AppTheme.textSecondary,
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
    );
  }
}

