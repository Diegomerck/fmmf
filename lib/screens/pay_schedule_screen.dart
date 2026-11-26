import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_format.dart';
import '../../models/recurring_income.dart';
import '../../providers/finance_provider.dart';

class PayScheduleScreen extends StatelessWidget {
  final FinanceProvider provider;
  final RecurringIncome income;

  const PayScheduleScreen({
    super.key,
    required this.provider,
    required this.income,
  });

  static const List<String> _months = [
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
  ];

  String _formatDate(DateTime d) {
    return '${d.day} ${_months[d.month - 1]} ${d.year}';
  }

  void _openEditOccurrence(BuildContext context, ScheduledPayOccurrence occ) {
    final amountCtrl = TextEditingController(text: occ.amount.toStringAsFixed(2));
    final noteCtrl = TextEditingController(text: occ.note ?? '');
    DateTime selectedDate = occ.date;
    final nowInit = DateTime.now();
    bool alreadyInBalance = occ.date.isBefore(DateTime(nowInit.year, nowInit.month, nowInit.day));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Editar Pago: ${income.name}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Ajusta la fecha real de depósito o el monto (ej. horas extras, bonos o faltas).',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),

                // Date Picker Row
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime(selectedDate.year - 1),
                      lastDate: DateTime(selectedDate.year + 2),
                    );
                    if (picked != null) {
                      setModalState(() => selectedDate = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Fecha de depósito:', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                        Row(
                          children: [
                            Text(
                              _formatDate(selectedDate),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.electricCyan),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.calendar_today, size: 16, color: AppTheme.electricCyan),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                  decoration: InputDecoration(
                    prefixText: '\$ ',
                    suffixText: 'MXN',
                    labelText: 'Monto real o proyectado',
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: noteCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Nota (ej. +8 hrs extras, falta 2 días)',
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 18),

                Builder(builder: (_) {
                  final now = DateTime.now();
                  final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
                  final isFutureDate = selectedDate.isAfter(endOfToday);

                  if (occ.status == PayOccurrenceStatus.confirmed) {
                    return Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.emeraldGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.sync, size: 16),
                            label: const Text('Actualizar Cobro y Movimientos', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            onPressed: () async {
                              final amt = double.tryParse(amountCtrl.text.replaceAll(',', '').trim()) ?? occ.amount;
                              await provider.updatePayOccurrence(
                                occ.copyWith(
                                  date: selectedDate,
                                  amount: amt < 0 ? 0 : amt,
                                  note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                                ),
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () async {
                            await provider.unconfirmPayOccurrence(occ.id);
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          child: const Text(
                            'Deshacer Confirmación (Volver a Proyectado)',
                            style: TextStyle(color: AppTheme.alertCoral, fontSize: 12),
                          ),
                        ),
                      ],
                    );
                  }

                  if (isFutureDate) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Fecha futura: se guardará solo como proyección hasta que llegue el día del depósito.',
                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.emeraldGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Guardar Proyección', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            onPressed: () async {
                              final amt = double.tryParse(amountCtrl.text.replaceAll(',', '').trim()) ?? occ.amount;
                              await provider.updatePayOccurrence(
                                occ.copyWith(
                                  date: selectedDate,
                                  amount: amt < 0 ? 0 : amt,
                                  note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                                ),
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                          ),
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('¿Ya está en tu saldo actual?', style: TextStyle(fontSize: 13, color: Colors.white)),
                        subtitle: Text(
                          alreadyInBalance
                              ? 'Al confirmar, solo se registra en historial sin sumar al saldo.'
                              : 'Al confirmar, sumará el monto al saldo de tu cuenta.',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                        value: alreadyInBalance,
                        activeColor: AppTheme.electricCyan,
                        onChanged: (v) => setModalState(() => alreadyInBalance = v),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.electricCyan,
                                side: BorderSide(color: AppTheme.electricCyan.withOpacity(0.5)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () async {
                                final amt = double.tryParse(amountCtrl.text.replaceAll(',', '').trim()) ?? occ.amount;
                                await provider.updatePayOccurrence(
                                  occ.copyWith(
                                    date: selectedDate,
                                    amount: amt < 0 ? 0 : amt,
                                    note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                                  ),
                                );
                                if (ctx.mounted) Navigator.pop(ctx);
                              },
                              child: const Text('Guardar Proyección', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.emeraldGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () async {
                                final amt = double.tryParse(amountCtrl.text.replaceAll(',', '').trim()) ?? occ.amount;
                                await provider.updatePayOccurrence(
                                  occ.copyWith(
                                    date: selectedDate,
                                    amount: amt < 0 ? 0 : amt,
                                    note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                                  ),
                                );
                                await provider.confirmPayOccurrence(
                                  occ.id,
                                  customAmount: amt,
                                  actualDate: selectedDate,
                                  alreadyInBalance: alreadyInBalance,
                                );
                                if (ctx.mounted) Navigator.pop(ctx);
                              },
                              child: const Text('Confirmar Cobro', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }),
                if (occ.status == PayOccurrenceStatus.projected) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: () async {
                        await provider.skipPayOccurrence(occ.id);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Marcar como No Recibido / Omitir', style: TextStyle(color: AppTheme.alertCoral, fontSize: 12)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        final occurrences = provider.getOccurrencesForIncome(income.id);
        final now = DateTime.now();
        final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);

        double totalProjected = 0;
        double totalConfirmed = 0;
        for (final o in occurrences) {
          if (o.status == PayOccurrenceStatus.confirmed) {
            totalConfirmed += o.amount;
            totalProjected += o.amount;
          } else if (o.status == PayOccurrenceStatus.projected) {
            totalProjected += o.amount;
          }
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('Calendario: ${income.name}', style: const TextStyle(fontSize: 17)),
          ),
          body: Column(
            children: [
              // Annual Projection Header
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Proyección Anual (12m)', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                          const SizedBox(height: 4),
                          Text(
                            CurrencyFormat.formatMXN(totalProjected, includeDecimals: false),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 32, color: AppTheme.border),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Confirmado / Cobrado', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                          const SizedBox(height: 4),
                          Text(
                            CurrencyFormat.formatMXN(totalConfirmed, includeDecimals: false),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.emeraldGreen),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Toca cualquier fecha para ajustar monto (horas extras / faltas) o cambiar fecha real:',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: occurrences.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final occ = occurrences[idx];
                    final isDue = occ.status == PayOccurrenceStatus.projected && !occ.date.isAfter(endOfToday);

                    final (String statusLabel, Color statusColor) = switch (occ.status) {
                      PayOccurrenceStatus.confirmed => ('Confirmado', AppTheme.emeraldGreen),
                      PayOccurrenceStatus.skipped => ('Omitido', AppTheme.textMuted),
                      PayOccurrenceStatus.projected =>
                        isDue ? ('Pendiente por confirmar', AppTheme.amberGold) : ('Proyectado', AppTheme.electricCyan),
                    };

                    return InkWell(
                      onTap: () => _openEditOccurrence(context, occ),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDue ? AppTheme.cardHighlight : AppTheme.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDue ? AppTheme.amberGold.withOpacity(0.6) : AppTheme.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        _formatDate(occ.date),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: occ.status == PayOccurrenceStatus.skipped
                                              ? AppTheme.textMuted
                                              : Colors.white,
                                          decoration: occ.status == PayOccurrenceStatus.skipped
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          statusLabel,
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (occ.note != null && occ.note!.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      occ.note!,
                                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Text(
                              CurrencyFormat.formatMXN(occ.amount),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: occ.status == PayOccurrenceStatus.confirmed
                                    ? AppTheme.emeraldGreen
                                    : (occ.status == PayOccurrenceStatus.skipped
                                        ? AppTheme.textMuted
                                        : Colors.white),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.edit_outlined, size: 15, color: AppTheme.textMuted),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

