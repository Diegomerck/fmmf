import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/currency_format.dart';
import '../models/account.dart';
import '../models/credit_installment.dart';
import '../models/imported_statement.dart';
import '../models/transaction.dart';
import '../providers/finance_provider.dart';
import '../services/pdf_statement_parser.dart';
import 'statement_import_screen.dart';
import 'widgets/account_form_sheet.dart';
import 'widgets/installment_plan_sheet.dart';
import 'widgets/quick_entry_sheet.dart';

class _BillingPeriod {
  final String key;
  final String label;
  final DateTime start;
  final DateTime end;

  const _BillingPeriod({
    required this.key,
    required this.label,
    required this.start,
    required this.end,
  });
}

class _CardPeriodEntry {
  final DateTime date;
  final String title;
  final String subtitle;
  final double amount;
  final bool isPositive;
  final String? badge;
  final CreditInstallmentPlan? linkedPlan;
  final Transaction? linkedTransaction;

  const _CardPeriodEntry({
    required this.date,
    required this.title,
    required this.subtitle,
    required this.amount,
    this.isPositive = false,
    this.badge,
    this.linkedPlan,
    this.linkedTransaction,
  });
}

class CreditCardDetailScreen extends StatefulWidget {
  final FinanceProvider provider;
  final String cardId;

  const CreditCardDetailScreen({
    super.key,
    required this.provider,
    required this.cardId,
  });

  @override
  State<CreditCardDetailScreen> createState() => _CreditCardDetailScreenState();
}

class _CreditCardDetailScreenState extends State<CreditCardDetailScreen> {
  String? _selectedPeriodKey;

  static const List<String> _months = [
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
  ];

  _BillingPeriod _periodForDate(DateTime date, int cutoffDay) {
    final safeCutoff = cutoffDay <= 0 ? 28 : cutoffDay;

    late DateTime endMonthDate;
    if (date.day <= safeCutoff) {
      endMonthDate = DateTime(date.year, date.month, 1);
    } else {
      endMonthDate = DateTime(date.year, date.month + 1, 1);
    }

    final endMaxDay = DateTime(endMonthDate.year, endMonthDate.month + 1, 0).day;
    final endDate = DateTime(endMonthDate.year, endMonthDate.month, safeCutoff.clamp(1, endMaxDay), 23, 59, 59);

    final prevMonthDate = DateTime(endMonthDate.year, endMonthDate.month - 1, 1);
    final prevMaxDay = DateTime(prevMonthDate.year, prevMonthDate.month + 1, 0).day;
    final prevCutoff = DateTime(prevMonthDate.year, prevMonthDate.month, safeCutoff.clamp(1, prevMaxDay));
    final startDate = prevCutoff.add(const Duration(days: 1));

    final key = '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}';
    final label = '${startDate.day} ${_months[startDate.month - 1]} – ${endDate.day} ${_months[endDate.month - 1]}';
    return _BillingPeriod(key: key, label: label, start: startDate, end: endDate);
  }

  void _showEditMonthlyDueDialog(BuildContext context, Account card, double currentMonthlyDue) {
    final ctrl = TextEditingController(text: currentMonthlyDue.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('Ajustar Pago del Mes', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Define el monto real a pagar este mes. Cualquier cargo o pago que registres después de este momento ajustará este monto automáticamente.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.3),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                prefixText: '\$ ',
                suffixText: 'MXN',
                labelText: 'Pago del Mes',
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          if (card.manualMonthlyDueOverride != null)
            TextButton(
              onPressed: () async {
                await widget.provider.setCardManualMonthlyDue(card.id, null);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Usar automático', style: TextStyle(color: AppTheme.electricCyan)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emeraldGreen, foregroundColor: Colors.white),
            onPressed: () async {
              final val = double.tryParse(ctrl.text.replaceAll(',', '').trim());
              if (val != null && val >= 0) {
                await widget.provider.setCardManualMonthlyDue(card.id, val);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showPayCardDialog(BuildContext context, Account card, double monthlyDue) {
    final payingAccounts = widget.provider.accounts.where((a) => a.type != AccountType.creditCard).toList();
    if (payingAccounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.amberGold,
          content: Text('Agrega una cuenta de débito o ahorros para poder registrar el pago.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    String fromAccId = payingAccounts.first.id;
    final ctrl = TextEditingController(text: monthlyDue.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: AppTheme.card,
          title: Text('Pagar ${card.name}', style: const TextStyle(color: Colors.white, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  prefixText: '\$ ',
                  suffixText: 'MXN',
                  labelText: 'Monto a pagar',
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Pagar desde:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: fromAccId,
                dropdownColor: AppTheme.surface,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: payingAccounts
                    .map((a) => DropdownMenuItem(
                          value: a.id,
                          child: Text(a.name, style: const TextStyle(color: Colors.white, fontSize: 13)),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDlgState(() => fromAccId = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emeraldGreen, foregroundColor: Colors.white),
              onPressed: () async {
                final amt = double.tryParse(ctrl.text.replaceAll(',', '').trim()) ?? 0.0;
                if (amt > 0) {
                  await widget.provider.payCreditCardMonthly(card.id, fromAccId, amt);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Registrar Pago'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.provider,
      builder: (context, _) {
        final card = widget.provider.accounts.where((a) => a.id == widget.cardId).firstOrNull;
        if (card == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Tarjeta')),
            body: const Center(child: Text('Tarjeta eliminada.', style: TextStyle(color: AppTheme.textMuted))),
          );
        }

        final plans = widget.provider.getPlansForCard(card.id);
        final activePlans = plans.where((p) => !p.isCompleted).toList();
        final revolving = widget.provider.getCardRevolvingBalance(card.id);
        final monthlyDue = widget.provider.getCardMonthlyPaymentDue(card.id);
        final availableCredit = (card.creditLimit - card.balance).clamp(0.0, double.infinity);
        final cardTxs = widget.provider.transactions
            .where((t) => t.accountId == card.id || t.targetAccountId == card.id)
            .toList();
        final statements = widget.provider.getStatementsForCard(card.id);

        // Group card transactions & MSI original purchases by billing period
        final currentPeriod = _periodForDate(DateTime.now(), card.cutoffDay);
        final Map<String, _BillingPeriod> periodMeta = {currentPeriod.key: currentPeriod};
        final Map<String, List<_CardPeriodEntry>> periodEntries = {currentPeriod.key: []};

        for (final tx in cardTxs) {
          var effectiveDate = tx.billingDate ?? tx.date;
          if (tx.billingDate == null) {
            final linkedStmt = statements
                .where((s) => s.importedTransactionIds.contains(tx.id))
                .firstOrNull;
            final stmtCutoff = linkedStmt?.cutoffDateStr != null
                ? PdfStatementParser.parseDate(linkedStmt!.cutoffDateStr!)
                : null;
            if (stmtCutoff != null) {
              final cycleStart = PdfStatementParser.subtractMonths(stmtCutoff, 1);
              if (!tx.date.isAfter(cycleStart) || tx.date.isAfter(stmtCutoff)) {
                effectiveDate = stmtCutoff;
              }
            }
          }
          final p = _periodForDate(effectiveDate, card.cutoffDay);
          final originPeriod = _periodForDate(tx.date, card.cutoffDay);
          periodMeta.putIfAbsent(p.key, () => p);
          final movedTag = p.key != originPeriod.key
              ? ' • Aplicado en ${p.label}'
              : '';
          final noteSuffix = (tx.note != null && tx.note!.trim().isNotEmpty)
              ? ' • ${tx.note!.trim()}'
              : '';
          periodEntries.putIfAbsent(p.key, () => []).add(_CardPeriodEntry(
            date: tx.date,
            title: tx.title,
            subtitle: '${tx.category} • ${tx.date.day}/${tx.date.month}/${tx.date.year}$movedTag$noteSuffix',
            amount: tx.amount,
            isPositive: tx.targetAccountId == card.id || tx.type == MovementType.income,
            linkedTransaction: tx,
          ));
        }

        for (final plan in plans) {
          // Back-project older statement-imported MSI plans that still carry the
          // statement cycle's stamped date instead of their original purchase month.
          var effectiveStartDate = plan.startDate;
          if (plan.paidMonths >= 1) {
            final linkedStmt = statements
                .where((s) => s.importedPlanIds.contains(plan.id))
                .firstOrNull;
            final stmtCutoff = linkedStmt?.cutoffDateStr != null
                ? PdfStatementParser.parseDate(linkedStmt!.cutoffDateStr!)
                : null;
            if (stmtCutoff != null) {
              final cycleStart = PdfStatementParser.subtractMonths(stmtCutoff, 1);
              final windowStart = cycleStart.subtract(const Duration(days: 5));
              if (plan.startDate.isAfter(windowStart) &&
                  !plan.startDate.isAfter(stmtCutoff)) {
                final anchor = !plan.startDate.isAfter(cycleStart)
                    ? cycleStart.add(const Duration(days: 1))
                    : plan.startDate;
                effectiveStartDate = plan.paidMonths > 1
                    ? PdfStatementParser.subtractMonths(anchor, plan.paidMonths - 1)
                    : anchor;
              }
            }
          }

          // Avoid duplicate on month 1 if already logged as a "Compras a Meses" transaction
          final hasMatchingOriginTx = cardTxs.any((tx) =>
              tx.category == 'Compras a Meses' &&
              (tx.amount - plan.totalFinancedAmount).abs() < 0.01 &&
              tx.date.year == effectiveStartDate.year &&
              tx.date.month == effectiveStartDate.month &&
              tx.date.day == effectiveStartDate.day);

          final maxInstallments = plan.totalMonths > 0 ? plan.totalMonths : 1;
          for (int inst = 1; inst <= maxInstallments; inst++) {
            final instDate = PdfStatementParser.addMonths(effectiveStartDate, inst - 1);
            final p = _periodForDate(instDate, card.cutoffDay);
            if (p.key.compareTo(currentPeriod.key) > 0) break;
            if (inst == 1 && hasMatchingOriginTx) continue;
            periodMeta.putIfAbsent(p.key, () => p);
            periodEntries.putIfAbsent(p.key, () => []).add(_CardPeriodEntry(
              date: instDate,
              title: plan.displayTitle,
              subtitle:
                  '${plan.isInterestFree ? "MSI" : "MCI"} ($inst/${plan.totalMonths} • Total: ${CurrencyFormat.formatMXN(plan.totalFinancedAmount)}) • ${instDate.day}/${instDate.month}/${instDate.year}',
              amount: plan.monthlyInstallment,
              badge: '${plan.totalMonths} ${plan.isInterestFree ? "MSI" : "MCI"}',
              linkedPlan: plan,
            ));
          }
        }

        for (final list in periodEntries.values) {
          list.sort((a, b) => b.date.compareTo(a.date));
        }

        final sortedPeriodKeys = periodMeta.keys
            .where((k) => k.compareTo(currentPeriod.key) <= 0)
            .toList()
          ..sort((a, b) => b.compareTo(a));
        final activePeriodKey =
            (_selectedPeriodKey != null && sortedPeriodKeys.contains(_selectedPeriodKey))
                ? _selectedPeriodKey!
                : currentPeriod.key;
        final activeEntries = periodEntries[activePeriodKey] ?? [];

        return Scaffold(
          appBar: AppBar(
            title: Text(card.name, style: const TextStyle(fontSize: 18)),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Editar tarjeta',
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => AccountFormSheet(provider: widget.provider, existingAccount: card),
                  );
                },
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                color: AppTheme.card,
                onSelected: (val) {
                  if (val == 'clear') {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppTheme.card,
                        title: Text('¿Limpiar datos importados de ${card.name}?',
                            style: const TextStyle(color: Colors.white, fontSize: 16)),
                        content: const Text(
                          'Se eliminarán los planes a meses (MSI/MCI), el historial de estados de cuenta y los cargos importados de esta tarjeta, conservando tu saldo actual.',
                          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.alertCoral, foregroundColor: Colors.white),
                            onPressed: () async {
                              await widget.provider.clearCardStatementData(card.id);
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                            child: const Text('Sí, limpiar'),
                          ),
                        ],
                      ),
                    );
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'clear',
                    child: Row(
                      children: [
                        Icon(Icons.cleaning_services_outlined, size: 18, color: AppTheme.alertCoral),
                        SizedBox(width: 8),
                        Text('Limpiar MSI y Edo. Cta.', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Hero Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2D1120), Color(0xFF1F1629)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppTheme.alertCoral.withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'PAGO DEL MES (NO GENERAR INTERESES)',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white70, letterSpacing: 0.7),
                          ),
                          InkWell(
                            onTap: () => _showEditMonthlyDueDialog(context, card, monthlyDue),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.edit_outlined, size: 14, color: AppTheme.electricCyan),
                                  SizedBox(width: 4),
                                  Text('Editar', style: TextStyle(fontSize: 11, color: AppTheme.electricCyan, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        CurrencyFormat.formatMXN(monthlyDue),
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      if (card.manualMonthlyDueOverride != null && card.manualMonthlyDueAt != null)
                        Text(
                          'Ajustado manualmente (${card.manualMonthlyDueAt!.day}/${card.manualMonthlyDueAt!.month} '
                          '${card.manualMonthlyDueAt!.hour.toString().padLeft(2, '0')}:${card.manualMonthlyDueAt!.minute.toString().padLeft(2, '0')}) + cargos posteriores',
                          style: const TextStyle(fontSize: 11, color: AppTheme.electricCyan),
                        )
                      else ...[
                        Text(
                          'Revolvente: ${CurrencyFormat.formatMXN(revolving)} + Mensualidades: ${CurrencyFormat.formatMXN(monthlyDue - revolving)}',
                          style: const TextStyle(fontSize: 11, color: Colors.white60),
                        ),
                        Builder(builder: (_) {
                          final msiRemaining = activePlans.fold<double>(0.0, (s, p) => s + p.remainingBalance);
                          if (activePlans.isNotEmpty && card.balance < msiRemaining) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Nota: Tu deuda capturada (${CurrencyFormat.formatMXN(card.balance)}) es menor al saldo MSI restante (${CurrencyFormat.formatMXN(msiRemaining)}), por eso Revolvente = \$0.00.',
                                style: const TextStyle(fontSize: 10, color: AppTheme.amberGold),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        }),
                      ],
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white12, height: 1),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Deuda Total', style: TextStyle(fontSize: 11, color: Colors.white60)),
                                Text(CurrencyFormat.formatMXN(card.balance),
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.alertCoral)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Disponible', style: TextStyle(fontSize: 11, color: Colors.white60)),
                                Text(CurrencyFormat.formatMXN(availableCredit, includeDecimals: false),
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.emeraldGreen)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Corte / Pago', style: TextStyle(fontSize: 11, color: Colors.white60)),
                                Text('Día ${card.cutoffDay} / ${card.paymentDueDay}',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.amberGold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Quick Card Actions
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.emeraldGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.payment, size: 16),
                        label: const Text('Pagar Tarjeta', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        onPressed: () => _showPayCardDialog(context, card, monthlyDue),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.electricCyan,
                          side: BorderSide(color: AppTheme.electricCyan.withOpacity(0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.upload_file, size: 16),
                        label: const Text('Importar Edo. Cta.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StatementImportScreen(provider: widget.provider, card: card),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // MSI / MCI Plans Collapsible Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Compras a Meses (MSI / MCI)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 16, color: AppTheme.emeraldGreen),
                      label: const Text('Agregar', style: TextStyle(color: AppTheme.emeraldGreen, fontSize: 13)),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => InstallmentPlanSheet(provider: widget.provider, card: card),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (activePlans.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'No tienes compras a meses registradas en esta tarjeta. Agrega tus MSI/MCI para que tu Pago del Mes y Safe-to-Spend sean exactos.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  )
                else
                  Builder(builder: (_) {
                    final totalMsiMonthly = activePlans.fold<double>(0.0, (s, p) => s + p.monthlyInstallment);
                    final totalMsiPaid = activePlans.fold<double>(0.0, (s, p) => s + (p.paidMonths * p.monthlyInstallment));
                    final totalMsiRemaining = activePlans.fold<double>(0.0, (s, p) => s + p.remainingBalance);

                    return Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          initiallyExpanded: false,
                          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                          iconColor: AppTheme.electricCyan,
                          collapsedIconColor: AppTheme.textSecondary,
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${activePlans.length} planes activos',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                              Text(
                                '${CurrencyFormat.formatMXN(totalMsiMonthly)}/mes',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.electricCyan),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Ya pagado: ${CurrencyFormat.formatMXN(totalMsiPaid)} • Resta: ${CurrencyFormat.formatMXN(totalMsiRemaining)}',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                          ),
                          children: activePlans.map((p) => _buildPlanCard(context, card, p)).toList(),
                        ),
                      ),
                    );
                  }),

                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Movimientos en esta Tarjeta',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 16, color: AppTheme.emeraldGreen),
                      label: const Text(
                        'Agregar',
                        style: TextStyle(color: AppTheme.emeraldGreen, fontSize: 13),
                      ),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => QuickEntrySheet(
                            provider: widget.provider,
                            initialAccountId: card.id,
                            lockAccount: true,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Billing Period Selector Tabs
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: sortedPeriodKeys.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, idx) {
                      final key = sortedPeriodKeys[idx];
                      final meta = periodMeta[key]!;
                      final count = periodEntries[key]?.length ?? 0;
                      final isSelected = key == activePeriodKey;
                      final isCurrent = key == currentPeriod.key;
                      final chipText = isCurrent
                          ? 'Período Actual (${meta.label})'
                          : '${meta.label} ($count)';

                      return DragTarget<Transaction>(
                        onWillAcceptWithDetails: (details) {
                          final currentKey = _periodForDate(
                            details.data.billingDate ?? details.data.date,
                            card.cutoffDay,
                          ).key;
                          return currentKey != key;
                        },
                        onAcceptWithDetails: (details) async {
                          final messenger = ScaffoldMessenger.of(context);
                          final tx = details.data;
                          final originKey = _periodForDate(tx.date, card.cutoffDay).key;
                          final updated = originKey == key
                              ? tx.copyWith(clearBillingDate: true)
                              : tx.copyWith(billingDate: meta.start);
                          await widget.provider.updateTransaction(updated);
                          if (mounted) {
                            setState(() => _selectedPeriodKey = key);
                            messenger.showSnackBar(
                              SnackBar(
                                backgroundColor: AppTheme.electricCyan,
                                content: Text('Movido a ${isCurrent ? "Período Actual (${meta.label})" : meta.label}',
                                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        builder: (context, candidateData, _) {
                          final isHovering = candidateData.isNotEmpty;
                          return ChoiceChip(
                            label: Text(chipText),
                            selected: isSelected,
                            selectedColor: AppTheme.electricCyan.withOpacity(0.25),
                            backgroundColor: isHovering
                                ? AppTheme.electricCyan.withOpacity(0.2)
                                : AppTheme.card,
                            side: isHovering
                                ? const BorderSide(color: AppTheme.electricCyan, width: 1.5)
                                : null,
                            labelStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: (isSelected || isHovering) ? FontWeight.w700 : FontWeight.normal,
                              color: (isSelected || isHovering) ? Colors.white : AppTheme.textSecondary,
                            ),
                            onSelected: (_) => setState(() => _selectedPeriodKey = key),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),

                if (activeEntries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      activePeriodKey == currentPeriod.key
                          ? 'Sin movimientos registrados en el período actual (${currentPeriod.label}).'
                          : 'Sin movimientos en este período.',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  )
                else
                  ...activeEntries.map((entry) {
                    final cardWidget = InkWell(
                      onTap: entry.linkedPlan != null
                          ? () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => InstallmentPlanSheet(
                                  provider: widget.provider,
                                  card: card,
                                  existingPlan: entry.linkedPlan,
                                ),
                              );
                            }
                          : (entry.linkedTransaction != null
                              ? () => _showEditTransactionSheet(
                                    context,
                                    card,
                                    entry.linkedTransaction!,
                                    periodMeta,
                                    sortedPeriodKeys,
                                    currentPeriod.key,
                                  )
                              : null),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (entry.linkedTransaction != null)
                              const Padding(
                                padding: EdgeInsets.only(right: 8),
                                child: Icon(Icons.drag_indicator, size: 16, color: AppTheme.textMuted),
                              ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          entry.title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (entry.badge != null) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: AppTheme.electricCyan.withOpacity(0.18),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            entry.badge!,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.electricCyan,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    entry.subtitle,
                                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              CurrencyFormat.formatMXN(entry.amount),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: entry.isPositive ? AppTheme.emeraldGreen : AppTheme.alertCoral,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );

                    final tx = entry.linkedTransaction;
                    if (tx == null) return cardWidget;

                    return Draggable<Transaction>(
                      data: tx,
                      feedback: Material(
                        color: Colors.transparent,
                        child: Container(
                          width: 260,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.electricCyan, width: 1.5),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  entry.title,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                CurrencyFormat.formatMXN(entry.amount),
                                style: const TextStyle(color: AppTheme.electricCyan, fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                      childWhenDragging: Opacity(opacity: 0.35, child: cardWidget),
                      child: cardWidget,
                    );
                  }),

                const SizedBox(height: 22),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: false,
                      tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                      iconColor: AppTheme.electricCyan,
                      collapsedIconColor: AppTheme.textSecondary,
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Estados de Cuenta Importados',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                          Text(
                            statements.isEmpty
                                ? 'Ninguno'
                                : '${statements.length} ${statements.length == 1 ? "importado" : "importados"}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.electricCyan,
                            ),
                          ),
                        ],
                      ),
                      children: statements.isEmpty
                          ? const [
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                child: Text(
                                  'No has importado estados de cuenta en esta tarjeta aún.',
                                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                ),
                              ),
                            ]
                          : statements.map((stmt) => _buildStatementCard(context, stmt)).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlanCard(BuildContext context, Account card, CreditInstallmentPlan p) {
    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => InstallmentPlanSheet(provider: widget.provider, card: card, existingPlan: p),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.displayTitle,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      if (p.customName != null && p.customName!.isNotEmpty)
                        Text(
                          p.title,
                          style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                        ),
                    ],
                  ),
                ),
                Text(
                  '${CurrencyFormat.formatMXN(p.monthlyInstallment)}/mes',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.electricCyan),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${p.isInterestFree ? "MSI" : "MCI (Interés: ${CurrencyFormat.formatMXN(p.interestAmount, includeDecimals: false)})"} • Cuota ${p.paidMonths} de ${p.totalMonths} • Resta ${CurrencyFormat.formatMXN(p.remainingBalance)}',
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: p.progress,
                minHeight: 5,
                backgroundColor: AppTheme.surface,
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.electricCyan),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatementCard(BuildContext context, ImportedStatement stmt) {
    return InkWell(
      onTap: () => _showStatementDetailModal(context, stmt),
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
            const Icon(Icons.picture_as_pdf, color: AppTheme.electricCyan, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stmt.fileName,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${stmt.cutoffDateStr != null ? "Corte: ${stmt.cutoffDateStr} • " : ""}${stmt.importedPlanIds.length} MSI • ${stmt.importedTransactionIds.length} cargos',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.alertCoral, size: 20),
              tooltip: 'Eliminar estado de cuenta',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppTheme.card,
                    title: const Text('¿Eliminar Estado de Cuenta?', style: TextStyle(color: Colors.white, fontSize: 16)),
                    content: Text(
                      'Se eliminará "${stmt.fileName}" junto con los ${stmt.importedPlanIds.length} planes MSI y ${stmt.importedTransactionIds.length} cargos importados de este documento.',
                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.alertCoral, foregroundColor: Colors.white),
                        onPressed: () async {
                          await widget.provider.deleteImportedStatement(stmt.id);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text('Eliminar'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showStatementDetailModal(BuildContext context, ImportedStatement stmt) {
    final linkedPlans = widget.provider.installmentPlans.where((p) => stmt.importedPlanIds.contains(p.id)).toList();
    final linkedTxs = widget.provider.transactions.where((t) => stmt.importedTransactionIds.contains(t.id)).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
        decoration: const BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(stmt.fileName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 4),
              Text(
                'Importado: ${stmt.importedAt.day}/${stmt.importedAt.month}/${stmt.importedAt.year}${stmt.cutoffDateStr != null ? " • Corte: ${stmt.cutoffDateStr}" : ""}',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 14),
              if (stmt.totalDebt != null || stmt.paymentNoInterest != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      if (stmt.paymentNoInterest != null)
                        _stmtRow('Pago para no generar intereses', CurrencyFormat.formatMXN(stmt.paymentNoInterest!)),
                      if (stmt.regularBalance != null)
                        _stmtRow('Saldo cargos regulares', CurrencyFormat.formatMXN(stmt.regularBalance!)),
                      if (stmt.msiBalance != null)
                        _stmtRow('Saldo cargos a meses', CurrencyFormat.formatMXN(stmt.msiBalance!)),
                      if (stmt.totalDebt != null)
                        _stmtRow('Saldo deudor total', CurrencyFormat.formatMXN(stmt.totalDebt!)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (linkedPlans.isNotEmpty) ...[
                Text('Planes MSI importados (${linkedPlans.length})',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.electricCyan)),
                const SizedBox(height: 6),
                ...linkedPlans.map((p) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(p.displayTitle, style: const TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                          Text(
                            '${CurrencyFormat.formatMXN(p.monthlyInstallment)}/m (${p.paidMonths}/${p.totalMonths})',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 14),
              ],
              if (linkedTxs.isNotEmpty) ...[
                Text('Cargos regulares importados (${linkedTxs.length})',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.amberGold)),
                const SizedBox(height: 6),
                ...linkedTxs.map((t) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(t.title, style: const TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                          Text(
                            CurrencyFormat.formatMXN(t.amount),
                            style: const TextStyle(color: AppTheme.alertCoral, fontSize: 12),
                          ),
                        ],
                      ),
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showEditTransactionSheet(
    BuildContext context,
    Account card,
    Transaction tx,
    Map<String, _BillingPeriod> periodMeta,
    List<String> sortedPeriodKeys,
    String currentPeriodKey,
  ) {
    final titleCtrl = TextEditingController(text: tx.title);
    final amountCtrl = TextEditingController(text: tx.amount.toStringAsFixed(2));
    final noteCtrl = TextEditingController(text: tx.note ?? '');
    var selectedDate = tx.date;
    var selectedPeriodKey = _periodForDate(tx.billingDate ?? tx.date, card.cutoffDay).key;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Editar Cargo',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppTheme.alertCoral),
                      tooltip: 'Eliminar cargo',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: ctx,
                          builder: (dCtx) => AlertDialog(
                            backgroundColor: AppTheme.card,
                            title: const Text('Eliminar cargo', style: TextStyle(color: Colors.white)),
                            content: Text(
                              '¿Eliminar "${tx.title}" (${CurrencyFormat.formatMXN(tx.amount)})?',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dCtx, false),
                                child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.alertCoral),
                                onPressed: () => Navigator.pop(dCtx, true),
                                child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await widget.provider.deleteTransaction(tx.id);
                          if (ctx.mounted) Navigator.pop(ctx);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Concepto / Nombre',
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    prefixText: '\$ ',
                    labelText: 'Monto',
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (picked != null) {
                      setModalState(() => selectedDate = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Fecha real de compra:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        Text(
                          '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.electricCyan),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: periodMeta.containsKey(selectedPeriodKey) ? selectedPeriodKey : currentPeriodKey,
                  dropdownColor: AppTheme.surface,
                  decoration: InputDecoration(
                    labelText: 'Período donde aplica',
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: sortedPeriodKeys.map((k) {
                    final m = periodMeta[k]!;
                    final label = k == currentPeriodKey ? 'Período Actual (${m.label})' : m.label;
                    return DropdownMenuItem(
                      value: k,
                      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setModalState(() => selectedPeriodKey = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Nota / Descripción del banco (opcional)',
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.emeraldGreen,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () async {
                      final newTitle = titleCtrl.text.trim();
                      final newAmount = double.tryParse(amountCtrl.text.replaceAll(',', '').trim());
                      if (newTitle.isEmpty || newAmount == null || newAmount <= 0) return;
                      final originKey = _periodForDate(selectedDate, card.cutoffDay).key;
                      final targetMeta = periodMeta[selectedPeriodKey];
                      final updated = tx.copyWith(
                        title: newTitle,
                        amount: newAmount,
                        date: selectedDate,
                        note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                        clearBillingDate: originKey == selectedPeriodKey || targetMeta == null,
                        billingDate: (originKey != selectedPeriodKey && targetMeta != null)
                            ? targetMeta.start
                            : null,
                      );
                      await widget.provider.updateTransaction(updated);
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }
                      if (mounted) {
                        setState(() => _selectedPeriodKey = selectedPeriodKey);
                      }
                    },
                    child: const Text('Guardar Cambios', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stmtRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
        ],
      ),
    );
  }
}
