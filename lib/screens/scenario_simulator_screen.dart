import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/currency_format.dart';
import '../models/account.dart';
import '../models/budget_commitment.dart';
import '../models/credit_installment.dart';
import '../models/recurring_income.dart';
import '../models/transaction.dart';
import '../providers/finance_provider.dart';
import '../services/advisor_engine.dart';

enum _SimType { incomeBoost, purchase, payOffCard, fixedExpense }

class _SimAction {
  final String id;
  final _SimType type;
  final String title;
  final String subtitle;
  final double amount;
  final IncomeFrequency? frequency;
  final int? payDay;
  final String? accountId;
  final String? targetCardId;
  final int installmentMonths;
  final String? removedCommitmentId;
  bool enabled = true;

  _SimAction({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    this.amount = 0.0,
    this.frequency,
    this.payDay,
    this.accountId,
    this.targetCardId,
    this.installmentMonths = 1,
    this.removedCommitmentId,
  });
}

class ScenarioSimulatorScreen extends StatefulWidget {
  final FinanceProvider provider;

  const ScenarioSimulatorScreen({super.key, required this.provider});

  @override
  State<ScenarioSimulatorScreen> createState() =>
      _ScenarioSimulatorScreenState();
}

class _ScenarioSimulatorScreenState extends State<ScenarioSimulatorScreen> {
  final List<_SimAction> _actions = [];

  AdvisorAnalysis _runSimulation() {
    final p = widget.provider;
    final now = DateTime.now();

    final accounts = p.accounts.map((a) => a.copyWith()).toList();
    final transactions = List<Transaction>.from(p.transactions);
    final commitments = p.commitments.map((c) => c.copyWith()).toList();
    final installmentPlans = List<CreditInstallmentPlan>.from(p.installmentPlans);
    final recurringIncomes = List<RecurringIncome>.from(p.recurringIncomes);
    final occurrences = List<ScheduledPayOccurrence>.from(p.payOccurrences);

    for (final act in _actions.where((a) => a.enabled)) {
      switch (act.type) {
        case _SimType.incomeBoost:
          final destId = act.accountId ??
              accounts
                  .where((a) => a.type != AccountType.creditCard)
                  .firstOrNull
                  ?.id ??
              '';
          final incId = 'sim_inc_${act.id}';
          final freq = act.frequency ?? IncomeFrequency.monthly;
          final payDay = act.payDay ?? now.day;
          recurringIncomes.add(
            RecurringIncome(
              id: incId,
              name: act.title,
              amount: act.amount,
              frequency: freq,
              payDay: payDay,
              accountId: destId,
            ),
          );
          // Add upcoming occurrence(s) this month so current month buffer updates too
          final lastDay = DateTime(now.year, now.month + 1, 0).day;
          final d1 = DateTime(now.year, now.month, payDay.clamp(1, lastDay));
          if (!d1.isBefore(DateTime(now.year, now.month, now.day))) {
            occurrences.add(
              ScheduledPayOccurrence(
                id: 'sim_occ_${act.id}_1',
                incomeId: incId,
                date: d1,
                amount: act.amount,
                status: PayOccurrenceStatus.projected,
              ),
            );
          }
          if (freq == IncomeFrequency.biweekly) {
            final d2Day = payDay <= 15 ? (payDay + 15) : (payDay - 15);
            final d2 = DateTime(now.year, now.month, d2Day.clamp(1, lastDay));
            if (!d2.isBefore(DateTime(now.year, now.month, now.day))) {
              occurrences.add(
                ScheduledPayOccurrence(
                  id: 'sim_occ_${act.id}_2',
                  incomeId: incId,
                  date: d2,
                  amount: act.amount,
                  status: PayOccurrenceStatus.projected,
                ),
              );
            }
          }
          break;

        case _SimType.purchase:
          final idx = accounts.indexWhere((a) => a.id == act.accountId);
          if (idx == -1) break;
          final acc = accounts[idx];
          if (acc.type == AccountType.creditCard) {
            accounts[idx] = acc.copyWith(balance: acc.balance + act.amount);
            if (act.installmentMonths > 1) {
              installmentPlans.add(
                CreditInstallmentPlan(
                  id: 'sim_msi_${act.id}',
                  accountId: acc.id,
                  title: act.title,
                  principalAmount: act.amount,
                  totalMonths: act.installmentMonths,
                  startDate: now.add(const Duration(seconds: 5)),
                ),
              );
            } else {
              transactions.add(
                Transaction(
                  id: 'sim_tx_${act.id}',
                  title: act.title,
                  amount: act.amount,
                  type: MovementType.expense,
                  category: 'Simulación',
                  accountId: acc.id,
                  date: now.add(const Duration(seconds: 5)),
                ),
              );
            }
          } else {
            accounts[idx] = acc.copyWith(balance: acc.balance - act.amount);
            transactions.add(
              Transaction(
                id: 'sim_tx_${act.id}',
                title: act.title,
                amount: act.amount,
                type: MovementType.expense,
                category: 'Simulación',
                accountId: acc.id,
                date: now,
              ),
            );
          }
          break;

        case _SimType.payOffCard:
          final cardIdx = accounts.indexWhere((a) => a.id == act.targetCardId);
          if (cardIdx == -1) break;
          final card = accounts[cardIdx];
          final debtAmt = card.balance;
          accounts[cardIdx] = card.copyWith(
            balance: 0.0,
            clearManualMonthlyDue: true,
          );
          installmentPlans.removeWhere((pl) => pl.accountId == card.id);
          if (act.accountId != null && debtAmt > 0) {
            final srcIdx = accounts.indexWhere((a) => a.id == act.accountId);
            if (srcIdx != -1) {
              accounts[srcIdx] = accounts[srcIdx].copyWith(
                balance: accounts[srcIdx].balance - debtAmt,
              );
            }
          }
          break;

        case _SimType.fixedExpense:
          if (act.removedCommitmentId != null) {
            commitments.removeWhere((c) => c.id == act.removedCommitmentId);
          } else {
            final accId = act.accountId ??
                accounts
                    .where((a) => a.type != AccountType.creditCard)
                    .firstOrNull
                    ?.id ??
                '';
            commitments.add(
              BudgetCommitment(
                id: 'sim_com_${act.id}',
                name: act.title,
                amount: act.amount,
                dueDay: act.payDay ?? 15,
                category: 'Simulación',
                accountId: accId,
              ),
            );
          }
          break;
      }
    }

    return AdvisorEngine.analyze(
      accounts: accounts,
      transactions: transactions,
      commitments: commitments,
      installmentPlans: installmentPlans,
      recurringIncomes: recurringIncomes,
      scheduledOccurrences: occurrences,
      fundingPriorityIds: p.fundingPriorityIds,
      emergencyFundMonths: p.emergencyFundMonths,
      safetyCushion: p.safetyCushion,
    );
  }

  String _formatMonths(double? months) {
    if (months == null) return 'Sin excedente';
    if (months <= 0) return '¡Listo!';
    final rounded = months.ceil();
    if (rounded < 12) return '~$rounded ${rounded == 1 ? 'mes' : 'meses'}';
    final y = rounded ~/ 12;
    final m = rounded % 12;
    final yStr = '$y ${y == 1 ? 'año' : 'años'}';
    return m == 0 ? '~$yStr' : '~$yStr y $m ${m == 1 ? 'mes' : 'meses'}';
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.provider.analysis;
    final sim = _actions.any((a) => a.enabled) ? _runSimulation() : base;

    final emergencySaved = widget.provider.accounts
        .where((a) => a.type != AccountType.creditCard && a.isEmergencyFund)
        .fold<double>(0.0, (s, a) => s + a.balance)
        .clamp(0.0, double.infinity);

    final double baseBurn =
        base.totalMonthlyCommitments + base.monthlyDirectExpense;
    final double baseGoalRem =
        (baseBurn * widget.provider.emergencyFundMonths - emergencySaved)
            .clamp(0.0, double.infinity);
    final double simBurn =
        sim.totalMonthlyCommitments + sim.monthlyDirectExpense;
    final double simGoalRem =
        (simBurn * widget.provider.emergencyFundMonths - emergencySaved)
            .clamp(0.0, double.infinity);

    final baseEta = base.estimateTimelineForTarget(baseGoalRem);
    final simEta = sim.estimateTimelineForTarget(simGoalRem);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Simulador de Escenarios'),
        actions: [
          if (_actions.isNotEmpty)
            TextButton(
              onPressed: () => setState(() => _actions.clear()),
              child: const Text(
                'Reiniciar',
                style: TextStyle(color: AppTheme.alertCoral, fontSize: 13),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.electricCyan.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppTheme.electricCyan.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.science_outlined,
                    size: 18, color: AppTheme.electricCyan),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Modo prueba: nada de lo que agregues aquí modifica tus cuentas o movimientos reales.',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildComparisonCard(
            base: base,
            sim: sim,
            baseEtaMonths: baseEta.monthsToGoal,
            simEtaMonths: simEta.monthsToGoal,
          ),
          const SizedBox(height: 16),
          const Text(
            '¿Qué quieres simular?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _actionChip(
                icon: Icons.trending_up_rounded,
                label: 'Nuevo ingreso / aumento',
                color: AppTheme.emeraldGreen,
                onTap: _showAddIncomeDialog,
              ),
              _actionChip(
                icon: Icons.shopping_bag_outlined,
                label: 'Hacer una compra / MSI',
                color: AppTheme.electricCyan,
                onTap: _showAddPurchaseDialog,
              ),
              _actionChip(
                icon: Icons.credit_score_rounded,
                label: 'Liquidar una tarjeta',
                color: AppTheme.amberGold,
                onTap: _showPayOffCardDialog,
              ),
              _actionChip(
                icon: Icons.receipt_long_outlined,
                label: 'Cambiar gasto fijo',
                color: AppTheme.alertCoral,
                onTap: _showFixedExpenseDialog,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Cambios en tu simulación (${_actions.length})',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          if (_actions.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Text(
                'Elige una opción arriba para ver cómo cambiarían tus finanzas sin afectar tus datos reales.',
                style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
              ),
            )
          else
            ..._actions.map(
              (act) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: act.enabled
                        ? AppTheme.electricCyan.withOpacity(0.35)
                        : AppTheme.border,
                  ),
                ),
                child: Row(
                  children: [
                    Switch(
                      value: act.enabled,
                      activeColor: AppTheme.electricCyan,
                      onChanged: (v) => setState(() => act.enabled = v),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            act.title,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: act.enabled
                                  ? Colors.white
                                  : AppTheme.textMuted,
                            ),
                          ),
                          Text(
                            act.subtitle,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          size: 18, color: AppTheme.textMuted),
                      onPressed: () =>
                          setState(() => _actions.removeWhere((a) => a.id == act.id)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildComparisonCard({
    required AdvisorAnalysis base,
    required AdvisorAnalysis sim,
    required double? baseEtaMonths,
    required double? simEtaMonths,
  }) {
    final double baseDue = base.creditMonthlyDue + base.pendingCommitments;
    final double simDue = sim.creditMonthlyDue + sim.pendingCommitments;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'Indicador',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Hoy',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Simulado',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.electricCyan),
                ),
              ),
            ],
          ),
          const Divider(color: AppTheme.border, height: 18),
          _compareMoneyRow(
            'Balance del mes',
            base.projectedEndOfMonthBuffer,
            sim.projectedEndOfMonthBuffer,
            higherIsBetter: true,
          ),
          _compareMoneyRow(
            'Por pagar este mes',
            baseDue,
            simDue,
            higherIsBetter: false,
          ),
          _compareMoneyRow(
            'Deuda en tarjetas',
            base.totalDebt,
            sim.totalDebt,
            higherIsBetter: false,
          ),
          _compareMoneyRow(
            'Ahorro/mes est.',
            base.estimatedMonthlySavingsCapacity,
            sim.estimatedMonthlySavingsCapacity,
            higherIsBetter: true,
          ),
          const Divider(color: AppTheme.border, height: 16),
          Row(
            children: [
              const Expanded(
                flex: 3,
                child: Text(
                  'Meta emergencia',
                  style: TextStyle(fontSize: 12.5, color: Colors.white),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  _formatMonths(baseEtaMonths),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  _formatMonths(simEtaMonths),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.electricCyan,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _compareMoneyRow(
    String label,
    double baseVal,
    double simVal, {
    required bool higherIsBetter,
  }) {
    final diff = simVal - baseVal;
    Color simColor = Colors.white;
    if (diff.abs() >= 1) {
      final improved = higherIsBetter ? diff > 0 : diff < 0;
      simColor = improved ? AppTheme.emeraldGreen : AppTheme.alertCoral;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: Colors.white),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              CurrencyFormat.formatMXN(baseVal, includeDecimals: false),
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 12.5, color: AppTheme.textSecondary),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              CurrencyFormat.formatMXN(simVal, includeDecimals: false),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: simColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      onPressed: onTap,
      avatar: Icon(icon, size: 16, color: color),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, color: Colors.white),
      ),
      backgroundColor: AppTheme.card,
      side: BorderSide(color: color.withOpacity(0.4)),
    );
  }

  void _showAddIncomeDialog() {
    final nameCtrl = TextEditingController(text: 'Ingreso extra');
    final amtCtrl = TextEditingController();
    IncomeFrequency freq = IncomeFrequency.monthly;
    final dayCtrl = TextEditingController(text: '15');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
                  'Simular ingreso o aumento',
                  style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Concepto'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amtCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white),
                  decoration:
                      const InputDecoration(labelText: 'Monto por cobro (\$ MXN)'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<IncomeFrequency>(
                        value: freq,
                        dropdownColor: AppTheme.surface,
                        style: const TextStyle(color: Colors.white),
                        decoration:
                            const InputDecoration(labelText: 'Frecuencia'),
                        items: const [
                          DropdownMenuItem(
                            value: IncomeFrequency.monthly,
                            child: Text('Mensual'),
                          ),
                          DropdownMenuItem(
                            value: IncomeFrequency.biweekly,
                            child: Text('Quincenal'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setModal(() => freq = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: dayCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration:
                            const InputDecoration(labelText: 'Día (1-31)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final amt = double.tryParse(
                              amtCtrl.text.replaceAll(',', '').trim()) ??
                          0.0;
                      if (amt <= 0) return;
                      final day =
                          (int.tryParse(dayCtrl.text.trim()) ?? 15).clamp(1, 31);
                      final title = nameCtrl.text.trim().isEmpty
                          ? 'Ingreso simulado'
                          : nameCtrl.text.trim();
                      setState(() {
                        _actions.add(
                          _SimAction(
                            id: '${DateTime.now().microsecondsSinceEpoch}',
                            type: _SimType.incomeBoost,
                            title: title,
                            subtitle:
                                '+${CurrencyFormat.formatMXN(amt, includeDecimals: false)} ${freq == IncomeFrequency.biweekly ? 'quincenal' : 'mensual'} (día $day)',
                            amount: amt,
                            frequency: freq,
                            payDay: day,
                          ),
                        );
                      });
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.emeraldGreen,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Agregar a simulación'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddPurchaseDialog() {
    final accounts = widget.provider.accounts;
    if (accounts.isEmpty) return;
    final titleCtrl = TextEditingController(text: 'Compra planeada');
    final amtCtrl = TextEditingController();
    final msiCtrl = TextEditingController(text: '1');
    String selectedAccountId = accounts.first.id;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final acc =
              accounts.where((a) => a.id == selectedAccountId).firstOrNull ??
                  accounts.first;
          final isCard = acc.type == AccountType.creditCard;
          return Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
                    'Simular una compra',
                    style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: '¿Qué comprarías?'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amtCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration:
                        const InputDecoration(labelText: 'Precio total (\$ MXN)'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedAccountId,
                    dropdownColor: AppTheme.surface,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: '¿Con qué cuenta?'),
                    items: accounts
                        .map((a) => DropdownMenuItem(
                              value: a.id,
                              child: Text(a.name),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setModal(() => selectedAccountId = v);
                    },
                  ),
                  if (isCard) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: msiCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Meses (1 = contado, 3/6/12 = MSI)',
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final amt = double.tryParse(
                                amtCtrl.text.replaceAll(',', '').trim()) ??
                            0.0;
                        if (amt <= 0) return;
                        final months = isCard
                            ? (int.tryParse(msiCtrl.text.trim()) ?? 1)
                                .clamp(1, 48)
                            : 1;
                        final title = titleCtrl.text.trim().isEmpty
                            ? 'Compra simulada'
                            : titleCtrl.text.trim();
                        setState(() {
                          _actions.add(
                            _SimAction(
                              id: '${DateTime.now().microsecondsSinceEpoch}',
                              type: _SimType.purchase,
                              title: title,
                              subtitle: months > 1
                                  ? '${CurrencyFormat.formatMXN(amt, includeDecimals: false)} a $months MSI en ${acc.name}'
                                  : '${CurrencyFormat.formatMXN(amt, includeDecimals: false)} con ${acc.name}',
                              amount: amt,
                              accountId: acc.id,
                              installmentMonths: months,
                            ),
                          );
                        });
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.electricCyan,
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('Agregar a simulación'),
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

  void _showPayOffCardDialog() {
    final cards = widget.provider.accounts
        .where((a) => a.type == AccountType.creditCard && a.balance > 0)
        .toList();
    if (cards.isEmpty) return;
    final cashAccounts = widget.provider.accounts
        .where((a) => a.type != AccountType.creditCard && a.balance > 0)
        .toList();
    String selectedCardId = cards.first.id;
    String? sourceAccountId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
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
                'Simular liquidar una tarjeta',
                style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedCardId,
                dropdownColor: AppTheme.surface,
                style: const TextStyle(color: Colors.white),
                decoration:
                    const InputDecoration(labelText: 'Tarjeta a liquidar'),
                items: cards
                    .map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(
                              '${c.name} (${CurrencyFormat.formatMXN(c.balance, includeDecimals: false)})'),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setModal(() => selectedCardId = v);
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                value: sourceAccountId,
                dropdownColor: AppTheme.surface,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    labelText: '¿De dónde saldría el dinero?'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Solo ver efecto sin deuda (dinero externo)'),
                  ),
                  ...cashAccounts.map(
                    (a) => DropdownMenuItem<String?>(
                      value: a.id,
                      child: Text(
                          '${a.name} (${CurrencyFormat.formatMXN(a.balance, includeDecimals: false)})'),
                    ),
                  ),
                ],
                onChanged: (v) => setModal(() => sourceAccountId = v),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final card = cards.firstWhere((c) => c.id == selectedCardId);
                    final srcName = sourceAccountId != null
                        ? cashAccounts
                            .where((a) => a.id == sourceAccountId)
                            .firstOrNull
                            ?.name
                        : null;
                    setState(() {
                      _actions.add(
                        _SimAction(
                          id: '${DateTime.now().microsecondsSinceEpoch}',
                          type: _SimType.payOffCard,
                          title: 'Liquidar ${card.name}',
                          subtitle: srcName != null
                              ? 'Pagando ${CurrencyFormat.formatMXN(card.balance, includeDecimals: false)} desde $srcName'
                              : 'Sin deuda en ${card.name} (${CurrencyFormat.formatMXN(card.balance, includeDecimals: false)})',
                          targetCardId: card.id,
                          accountId: sourceAccountId,
                        ),
                      );
                    });
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.amberGold,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Agregar a simulación'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFixedExpenseDialog() {
    final commitments = widget.provider.commitments;
    final nameCtrl = TextEditingController(text: 'Nuevo gasto fijo');
    final amtCtrl = TextEditingController();
    bool isRemoving = commitments.isNotEmpty;
    String? removeId = commitments.isNotEmpty ? commitments.first.id : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
                  'Simular cambio en gastos fijos',
                  style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
                const SizedBox(height: 10),
                if (commitments.isNotEmpty)
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Quitar uno')),
                      ButtonSegment(value: false, label: Text('Agregar nuevo')),
                    ],
                    selected: {isRemoving},
                    onSelectionChanged: (s) =>
                        setModal(() => isRemoving = s.first),
                  ),
                const SizedBox(height: 12),
                if (isRemoving && commitments.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: removeId,
                    dropdownColor: AppTheme.surface,
                    style: const TextStyle(color: Colors.white),
                    decoration:
                        const InputDecoration(labelText: 'Gasto a quitar'),
                    items: commitments
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(
                                  '${c.name} (${CurrencyFormat.formatMXN(c.amount, includeDecimals: false)})'),
                            ))
                        .toList(),
                    onChanged: (v) => setModal(() => removeId = v),
                  )
                else ...[
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Nombre'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amtCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration:
                        const InputDecoration(labelText: 'Monto mensual (\$ MXN)'),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (isRemoving && removeId != null) {
                        final com =
                            commitments.firstWhere((c) => c.id == removeId);
                        setState(() {
                          _actions.add(
                            _SimAction(
                              id: '${DateTime.now().microsecondsSinceEpoch}',
                              type: _SimType.fixedExpense,
                              title: 'Quitar ${com.name}',
                              subtitle:
                                  'Ahorrarías ${CurrencyFormat.formatMXN(com.amount, includeDecimals: false)}/mes',
                              removedCommitmentId: com.id,
                            ),
                          );
                        });
                        Navigator.pop(ctx);
                      } else {
                        final amt = double.tryParse(
                                amtCtrl.text.replaceAll(',', '').trim()) ??
                            0.0;
                        if (amt <= 0) return;
                        final title = nameCtrl.text.trim().isEmpty
                            ? 'Gasto fijo simulado'
                            : nameCtrl.text.trim();
                        setState(() {
                          _actions.add(
                            _SimAction(
                              id: '${DateTime.now().microsecondsSinceEpoch}',
                              type: _SimType.fixedExpense,
                              title: title,
                              subtitle:
                                  '-${CurrencyFormat.formatMXN(amt, includeDecimals: false)}/mes',
                              amount: amt,
                            ),
                          );
                        });
                        Navigator.pop(ctx);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.electricCyan,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Agregar a simulación'),
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
