import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_format.dart';
import '../../models/savings_rule.dart';
import '../../providers/finance_provider.dart';

class PendingTransfersSection extends StatelessWidget {
  final FinanceProvider provider;

  const PendingTransfersSection({super.key, required this.provider});

  void _showCustomAmountDialog(BuildContext context, PendingTransfer pending) {
    final ctrl = TextEditingController(text: pending.suggestedAmount.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('Transferir otro monto', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            prefixText: '\$ ',
            suffixText: 'MXN',
            filled: true,
            fillColor: AppTheme.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
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
                provider.confirmPendingTransfer(pending.id, customAmount: custom);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingList = provider.pendingTransfers;
    if (pendingList.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.savings_rounded, size: 18, color: AppTheme.emeraldGreen),
            SizedBox(width: 8),
            Text(
              'Ahorros Sugeridos por Confirmar',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...pendingList.map((p) {
          final sourceName = provider.accounts
                  .where((a) => a.id == p.sourceAccountId)
                  .map((a) => a.name)
                  .firstOrNull ??
              'Origen';
          final targetName = provider.accounts
                  .where((a) => a.id == p.targetAccountId)
                  .map((a) => a.name)
                  .firstOrNull ??
              'Ahorros';

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.cardHighlight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.emeraldGreen.withOpacity(0.45)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        p.ruleName,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                    Text(
                      CurrencyFormat.formatMXN(p.suggestedAmount),
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
                  '$sourceName → $targetName • ${p.reason}',
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
                        onPressed: () => provider.confirmPendingTransfer(p.id),
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
                      onPressed: () => _showCustomAmountDialog(context, p),
                      child: const Text('Otro monto', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 6),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.textMuted,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                      onPressed: () => provider.skipPendingTransfer(p.id),
                      child: const Text('Omitir', style: TextStyle(fontSize: 12)),
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

