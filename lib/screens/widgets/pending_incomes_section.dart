import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_format.dart';
import '../../models/recurring_income.dart';
import '../../providers/finance_provider.dart';

class PendingIncomesSection extends StatelessWidget {
  final FinanceProvider provider;

  const PendingIncomesSection({super.key, required this.provider});

  void _showConfirmDialog(BuildContext context, ScheduledPayOccurrence occ, String incomeName) {
    final ctrl = TextEditingController(text: occ.amount.toStringAsFixed(2));
    final now = DateTime.now();
    final isPast = occ.date.isBefore(DateTime(now.year, now.month, now.day));
    bool alreadyInBalance = isPast;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: AppTheme.card,
          title: Text(
            'Confirmar: $incomeName',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  prefixText: '\$ ',
                  suffixText: 'MXN',
                  labelText: 'Monto recibido',
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('¿Ya está en tu saldo actual?', style: TextStyle(fontSize: 13, color: Colors.white)),
                subtitle: Text(
                  alreadyInBalance
                      ? 'Solo registra en historial/Resumen sin sumar al saldo.'
                      : 'Sumará el monto al saldo de tu cuenta y sugerirá ahorro.',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
                value: alreadyInBalance,
                activeColor: AppTheme.electricCyan,
                onChanged: (v) => setDlgState(() => alreadyInBalance = v),
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
              onPressed: () {
                final custom = double.tryParse(ctrl.text.replaceAll(',', '').trim());
                if (custom != null && custom >= 0) {
                  provider.confirmPayOccurrence(
                    occ.id,
                    customAmount: custom,
                    alreadyInBalance: alreadyInBalance,
                  );
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Confirmar Ingreso'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dueList = provider.duePayOccurrences;
    if (dueList.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.payments_rounded, size: 18, color: AppTheme.electricCyan),
            SizedBox(width: 8),
            Text(
              'Pagos / Quincenas por Confirmar',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...dueList.map((occ) {
          final inc = provider.recurringIncomes.where((i) => i.id == occ.incomeId).firstOrNull;
          if (inc == null) return const SizedBox.shrink();

          final accName = provider.accounts
                  .where((a) => a.id == inc.accountId)
                  .map((a) => a.name)
                  .firstOrNull ??
              'Cuenta';

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.cardHighlight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.electricCyan.withOpacity(0.45)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        inc.name,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                    Text(
                      '+${CurrencyFormat.formatMXN(occ.amount)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.emeraldGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Fecha: ${occ.date.day}/${occ.date.month}/${occ.date.year} • Depósito a $accName${occ.note != null ? " • ${occ.note}" : ""}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.emeraldGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Confirmar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        onPressed: () => _showConfirmDialog(context, occ, inc.name),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.electricCyan,
                        side: BorderSide(color: AppTheme.electricCyan.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _showConfirmDialog(context, occ, inc.name),
                      child: const Text('Editar', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 6),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.alertCoral,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                      onPressed: () => provider.skipPayOccurrence(occ.id),
                      child: const Text('No recibí', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 10),
      ],
    );
  }
}
