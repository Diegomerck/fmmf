import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/currency_format.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import '../providers/finance_provider.dart';
import '../services/advisor_engine.dart';
import 'widgets/cloud_sync_badge.dart';
import 'widgets/transaction_detail_dialog.dart';

class EmergencyFundScreen extends StatelessWidget {
  final FinanceProvider provider;

  const EmergencyFundScreen({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        final analysis = provider.analysis;
        final emergencyAccounts = provider.accounts
            .where((a) => a.type != AccountType.creditCard && a.isEmergencyFund)
            .toList()
          ..sort((a, b) => b.balance.compareTo(a.balance));
        final emergencyIds = emergencyAccounts.map((a) => a.id).toSet();

        final double totalSaved = emergencyAccounts
            .fold<double>(0.0, (s, a) => s + a.balance)
            .clamp(0.0, double.infinity);
        final double monthlyBurn =
            analysis.totalMonthlyCommitments + analysis.monthlyDirectExpense;
        final int goalMonths = provider.emergencyFundMonths;
        final double goalAmount = monthlyBurn * goalMonths;
        final double remaining =
            (goalAmount - totalSaved).clamp(0.0, double.infinity);
        final double progress =
            goalAmount > 0 ? (totalSaved / goalAmount).clamp(0.0, 1.0) : 0.0;
        final double coveredMonths =
            monthlyBurn > 0 ? (totalSaved / monthlyBurn) : 0.0;

        final GoalTimelineEstimate currentPace =
            analysis.estimateTimelineForTarget(remaining);
        final GoalTimelineEstimate focusedPace = analysis
            .estimateTimelineForTarget(remaining, includeVariableSpend: false);

        final accountById = {for (final a in provider.accounts) a.id: a};
        final history = provider.transactions
            .where((t) =>
                t.category == 'Fondo de Emergencia' ||
                (t.type == MovementType.transfer &&
                    (emergencyIds.contains(t.accountId) ||
                        (t.targetAccountId != null &&
                            emergencyIds.contains(t.targetAccountId)))))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

        final double suggestedSafe = analysis.projectedEndOfMonthBuffer > 0
            ? analysis.safeToSpend.clamp(0.0, analysis.projectedEndOfMonthBuffer)
            : 0.0;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Fondo de Emergencia'),
            actions: [
              CloudSyncBadge(provider: provider),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSummaryCard(
                totalSaved: totalSaved,
                goalAmount: goalAmount,
                remaining: remaining,
                progress: progress,
                coveredMonths: coveredMonths,
                goalMonths: goalMonths,
                currentPace: currentPace,
                focusedPace: focusedPace,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: emergencyAccounts.isEmpty
                          ? () => _showManageAccountsSheet(context)
                          : () => _openTransferSheet(
                                context,
                                isDeposit: true,
                                emergencyAccounts: emergencyAccounts,
                                suggestedAmount: suggestedSafe,
                              ),
                      icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                      label: const Text('Apartar al Fondo'),
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
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: emergencyAccounts.any((a) => a.balance > 0)
                          ? () => _openTransferSheet(
                                context,
                                isDeposit: false,
                                emergencyAccounts: emergencyAccounts,
                                suggestedAmount: 0.0,
                              )
                          : null,
                      icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                      label: const Text('Retirar / Devolver'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.amberGold,
                        side: BorderSide(
                          color: emergencyAccounts.any((a) => a.balance > 0)
                              ? AppTheme.amberGold.withOpacity(0.6)
                              : AppTheme.border,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      '¿Dónde está guardado?',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _showManageAccountsSheet(context),
                    icon: const Icon(Icons.tune_rounded,
                        size: 16, color: AppTheme.electricCyan),
                    label: const Text(
                      'Asignar cuentas',
                      style: TextStyle(
                          fontSize: 12.5, color: AppTheme.electricCyan),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (emergencyAccounts.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: const Text(
                    'Aún no tienes cuentas asignadas a tu Fondo de Emergencia. Toca "Asignar cuentas" para elegir en qué cuenta(s) guardas este respaldo.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppTheme.textSecondary,
                      height: 1.35,
                    ),
                  ),
                )
              else
                ...emergencyAccounts.map(
                  (acc) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppTheme.electricCyan.withOpacity(0.28),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: acc.color.withOpacity(0.18),
                          child: Icon(
                            Icons.shield_moon_outlined,
                            size: 18,
                            color: acc.color,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                acc.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  if (acc.institution.isNotEmpty)
                                    acc.institution,
                                  if (acc.annualYieldRate > 0)
                                    '${acc.annualYieldRate.toStringAsFixed(1)}% anual',
                                ].join(' • '),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          CurrencyFormat.formatMXN(acc.balance),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.emeraldGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              const Text(
                'Historial de aportes y retiros',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Toca cualquier movimiento para editarlo o revertirlo.',
                style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 10),
              if (history.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: const Text(
                    'Todavía no hay transferencias registradas hacia o desde tu Fondo de Emergencia.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                )
              else
                ...history.map((tx) {
                  final bool isIn = tx.targetAccountId != null &&
                      emergencyIds.contains(tx.targetAccountId);
                  final srcName = accountById[tx.accountId]?.name ?? 'Cuenta';
                  final dstName = tx.targetAccountId != null
                      ? (accountById[tx.targetAccountId]?.name ?? 'Cuenta')
                      : null;
                  final Color tone =
                      isIn ? AppTheme.emeraldGreen : AppTheme.amberGold;
                  return InkWell(
                    onTap: () => showTransactionDetailDialog(
                      context,
                      provider,
                      tx,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isIn
                                ? Icons.arrow_downward_rounded
                                : Icons.arrow_upward_rounded,
                            size: 18,
                            color: tone,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tx.title,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${tx.date.day}/${tx.date.month}/${tx.date.year}${dstName != null ? " • $srcName → $dstName" : ""}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${isIn ? '+' : '-'}${CurrencyFormat.formatMXN(tx.amount)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: tone,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard({
    required double totalSaved,
    required double goalAmount,
    required double remaining,
    required double progress,
    required double coveredMonths,
    required int goalMonths,
    required GoalTimelineEstimate currentPace,
    required GoalTimelineEstimate focusedPace,
  }) {
    final int pct = (progress * 100).round();
    String formatEta(GoalTimelineEstimate e) {
      if (e.expectedMonthlyIncome <= 0) return 'Sin ingresos recurrentes';
      if (e.monthsToGoal == null) return 'Sin excedente proyectado';
      final m = e.monthsToGoal!;
      if (m <= 0) return '¡Meta completada!';
      final rounded = m.ceil();
      if (rounded < 12) {
        return '~$rounded ${rounded == 1 ? 'mes' : 'meses'}';
      }
      final years = rounded ~/ 12;
      final rem = rounded % 12;
      final yText = '$years ${years == 1 ? 'año' : 'años'}';
      return rem == 0
          ? '~$yText'
          : '~$yText y $rem ${rem == 1 ? 'mes' : 'meses'}';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.electricCyan.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total apartado hoy',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.electricCyan.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${coveredMonths.toStringAsFixed(1)} de $goalMonths meses',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.electricCyan,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            CurrencyFormat.formatMXN(totalSaved),
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            remaining > 0
                ? 'Te faltan ${CurrencyFormat.formatMXN(remaining)} para tu meta de ${CurrencyFormat.formatMXN(goalAmount, includeDecimals: false)}.'
                : '¡Ya completaste tu meta de $goalMonths meses!',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: Colors.white.withOpacity(0.12),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppTheme.electricCyan),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$pct%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.electricCyan,
                ),
              ),
            ],
          ),
          if (remaining > 0) ...[
            const SizedBox(height: 12),
            Text(
              '• A tu ritmo actual: ${formatEta(currentPace)}',
              style: const TextStyle(fontSize: 11.5, color: Colors.white70),
            ),
            const SizedBox(height: 3),
            Text(
              '• Pagando solo fijos y MSI: ${formatEta(focusedPace)}',
              style: const TextStyle(
                  fontSize: 11.5, color: AppTheme.emeraldGreen),
            ),
          ],
        ],
      ),
    );
  }

  void _showManageAccountsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ListenableBuilder(
        listenable: provider,
        builder: (ctx, _) {
          final candidates = provider.accounts
              .where((a) => a.type != AccountType.creditCard)
              .toList();
          return Container(
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
                  'Cuentas del Fondo de Emergencia',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Activa las cuentas donde guardas dinero exclusivamente para tu Fondo de Emergencia.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 12),
                ...candidates.map(
                  (acc) => SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppTheme.electricCyan,
                    title: Text(
                      acc.name,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                    ),
                    subtitle: Text(
                      '${acc.institution.isNotEmpty ? "${acc.institution} • " : ""}${CurrencyFormat.formatMXN(acc.balance)}',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    value: acc.isEmergencyFund,
                    onChanged: (val) => provider.updateAccount(
                      acc.copyWith(isEmergencyFund: val),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openTransferSheet(
    BuildContext context, {
    required bool isDeposit,
    required List<Account> emergencyAccounts,
    required double suggestedAmount,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EmergencyTransferSheet(
        provider: provider,
        isDeposit: isDeposit,
        emergencyAccounts: emergencyAccounts,
        suggestedAmount: suggestedAmount,
      ),
    );
  }
}

class _EmergencyTransferSheet extends StatefulWidget {
  final FinanceProvider provider;
  final bool isDeposit;
  final List<Account> emergencyAccounts;
  final double suggestedAmount;

  const _EmergencyTransferSheet({
    required this.provider,
    required this.isDeposit,
    required this.emergencyAccounts,
    required this.suggestedAmount,
  });

  @override
  State<_EmergencyTransferSheet> createState() =>
      _EmergencyTransferSheetState();
}

class _EmergencyTransferSheetState extends State<_EmergencyTransferSheet> {
  late String _sourceId;
  late String _destId;
  late TextEditingController _amountCtrl;
  String? _errorText;

  List<Account> get _sourceCandidates {
    if (widget.isDeposit) {
      return widget.provider.accounts
          .where((a) =>
              a.type != AccountType.creditCard &&
              !a.isEmergencyFund &&
              a.balance > 0)
          .toList();
    }
    return widget.emergencyAccounts.where((a) => a.balance > 0).toList();
  }

  List<Account> get _destCandidates {
    if (widget.isDeposit) {
      return widget.emergencyAccounts
          .where((a) => a.id != _sourceId)
          .toList();
    }
    return widget.provider.accounts
        .where((a) =>
            a.type != AccountType.creditCard && a.id != _sourceId)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    final sources = _sourceCandidates;
    _sourceId = sources.isNotEmpty ? sources.first.id : '';
    final dests = _destCandidates;
    _destId = dests.isNotEmpty ? dests.first.id : '';
    final maxAvail = sources.isNotEmpty ? sources.first.balance : 0.0;
    final initialAmt = widget.isDeposit
        ? widget.suggestedAmount.clamp(0.0, maxAvail)
        : 0.0;
    _amountCtrl = TextEditingController(
      text: initialAmt > 0 ? initialAmt.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sources = _sourceCandidates;
    if (sources.isEmpty) {
      return Container(
        decoration: const BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sin saldo disponible',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              widget.isDeposit
                  ? 'No tienes otra cuenta de débito o efectivo con saldo positivo para transferir al Fondo.'
                  : 'Tus cuentas de Fondo de Emergencia tienen saldo \$0.',
              style:
                  const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendido',
                    style: TextStyle(color: AppTheme.electricCyan)),
              ),
            ),
          ],
        ),
      );
    }

    final selectedSource =
        sources.where((a) => a.id == _sourceId).firstOrNull ?? sources.first;
    final dests = _destCandidates;
    if (dests.isNotEmpty && !dests.any((a) => a.id == _destId)) {
      _destId = dests.first.id;
    }

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
            Text(
              widget.isDeposit
                  ? 'Apartar a tu Fondo de Emergencia'
                  : 'Retirar / Devolver del Fondo',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Haz primero el movimiento en tu banco o efectivo, y luego confírmalo aquí.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: selectedSource.id,
              dropdownColor: AppTheme.surface,
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
              decoration: InputDecoration(
                labelText: widget.isDeposit
                    ? 'Desde qué cuenta sale el dinero'
                    : 'Desde qué cuenta del Fondo sale',
              ),
              items: sources
                  .map((a) => DropdownMenuItem(
                        value: a.id,
                        child: Text(
                          '${a.name} (${CurrencyFormat.formatMXN(a.balance, includeDecimals: false)})',
                        ),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val == null) return;
                setState(() {
                  _sourceId = val;
                  _errorText = null;
                });
              },
            ),
            const SizedBox(height: 12),
            if (dests.isNotEmpty)
              DropdownButtonFormField<String>(
                value: _destId,
                dropdownColor: AppTheme.surface,
                style: const TextStyle(color: Colors.white, fontSize: 13.5),
                decoration: InputDecoration(
                  labelText: widget.isDeposit
                      ? 'Hacia tu cuenta de Fondo de Emergencia'
                      : 'Hacia qué cuenta regresa el dinero',
                ),
                items: dests
                    .map((a) => DropdownMenuItem(
                          value: a.id,
                          child: Text(
                            '${a.name} (${CurrencyFormat.formatMXN(a.balance, includeDecimals: false)})',
                          ),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val == null) return;
                  setState(() {
                    _destId = val;
                    _errorText = null;
                  });
                },
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                labelText: 'Monto (\$ MXN)',
                helperText:
                    'Disponible en ${selectedSource.name}: ${CurrencyFormat.formatMXN(selectedSource.balance)}',
                helperStyle: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary),
                errorText: _errorText,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: dests.isEmpty
                    ? null
                    : () async {
                        final amt = double.tryParse(
                                _amountCtrl.text.replaceAll(',', '').trim()) ??
                            0.0;
                        if (amt <= 0) {
                          setState(
                              () => _errorText = 'Ingresa un monto mayor a \$0.');
                          return;
                        }
                        if (amt > selectedSource.balance + 0.01) {
                          setState(() => _errorText =
                              'El monto supera el saldo real en ${selectedSource.name}.');
                          return;
                        }
                        await widget.provider.addTransaction(
                          title: widget.isDeposit
                              ? 'Aporte a Fondo de Emergencia'
                              : 'Retiro de Fondo de Emergencia',
                          amount: amt,
                          type: MovementType.transfer,
                          category: 'Fondo de Emergencia',
                          accountId: selectedSource.id,
                          targetAccountId: _destId,
                        );
                        if (context.mounted) Navigator.pop(context);
                      },
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Ya lo transferí • Registrar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.isDeposit
                      ? AppTheme.electricCyan
                      : AppTheme.amberGold,
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
  }
}
