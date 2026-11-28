import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_format.dart';
import '../../models/account.dart';
import '../../models/mini_goal.dart';
import '../../providers/finance_provider.dart';

class MiniGoalTransferSheet extends StatefulWidget {
  final FinanceProvider provider;
  final MiniGoal goal;
  final double suggestedAmount;

  const MiniGoalTransferSheet({
    super.key,
    required this.provider,
    required this.goal,
    required this.suggestedAmount,
  });

  @override
  State<MiniGoalTransferSheet> createState() => _MiniGoalTransferSheetState();
}

class _MiniGoalTransferSheetState extends State<MiniGoalTransferSheet> {
  late String _sourceId;
  late TextEditingController _amountCtrl;
  String? _errorText;

  List<Account> get _sourceCandidates => widget.provider.accounts
      .where((a) => a.type != AccountType.creditCard && a.balance > 0)
      .toList();

  double _availableIn(Account acc) {
    final earmarked = widget.provider.earmarkedMiniGoalsForAccount(acc.id);
    return (acc.balance - earmarked).clamp(0.0, double.infinity);
  }

  @override
  void initState() {
    super.initState();
    final sources = _sourceCandidates;
    if (widget.goal.accountId != null &&
        sources.any((a) => a.id == widget.goal.accountId)) {
      _sourceId = widget.goal.accountId!;
    } else {
      _sourceId = sources.isNotEmpty ? sources.first.id : '';
    }
    final sel = sources.where((a) => a.id == _sourceId).firstOrNull;
    final maxAvail = sel != null ? _availableIn(sel) : 0.0;
    final initial = widget.suggestedAmount.clamp(0.0, maxAvail);
    _amountCtrl = TextEditingController(
      text: initial > 0 ? initial.toStringAsFixed(0) : '',
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
    final destAcc = widget.provider.accounts
        .where((a) => a.id == widget.goal.accountId)
        .firstOrNull;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Transferir desde',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded,
                      color: AppTheme.textSecondary),
                  tooltip: 'Cerrar',
                ),
              ],
            ),
            if (sources.isEmpty || destAcc == null) ...[
              const SizedBox(height: 6),
              const Text(
                'No tienes cuentas con saldo disponible para apartar en este momento.',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ),
            ] else ...[
              Text(
                'Hacia: ${destAcc.name} • ${widget.goal.name}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.amberGold,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Selecciona la cuenta de origen:',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: sources.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: AppTheme.border, height: 1),
                    itemBuilder: (_, i) {
                      final a = sources[i];
                      final avail = _availableIn(a);
                      final isSame = a.id == destAcc.id;
                      final selected = a.id == _sourceId;
                      return InkWell(
                        onTap: () => setState(() {
                          _sourceId = a.id;
                          _errorText = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          color: selected
                              ? AppTheme.amberGold.withOpacity(0.14)
                              : Colors.transparent,
                          child: Row(
                            children: [
                              Icon(
                                selected
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                                size: 17,
                                color: selected
                                    ? AppTheme.amberGold
                                    : AppTheme.textMuted,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  isSame
                                      ? '${a.name} (misma cuenta)'
                                      : a.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.normal,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${CurrencyFormat.formatMXN(avail, includeDecimals: false)} libres',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? AppTheme.amberGold
                                      : AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Builder(builder: (context) {
                final sel = sources.where((a) => a.id == _sourceId).firstOrNull ??
                    sources.first;
                final avail = _availableIn(sel);
                final isSame = sel.id == destAcc.id;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _amountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        labelText: 'Monto (\$ MXN)',
                        helperText:
                            'Libres en ${sel.name}: ${CurrencyFormat.formatMXN(avail)}',
                        helperStyle: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary),
                        errorText: _errorText,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textSecondary,
                              side: const BorderSide(color: AppTheme.border),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () async {
                              final amt = double.tryParse(_amountCtrl.text
                                      .replaceAll(',', '')
                                      .trim()) ??
                                  0.0;
                              if (amt <= 0) {
                                setState(() => _errorText =
                                    'Ingresa un monto mayor a \$0.');
                                return;
                              }
                              if (amt > avail + 0.01) {
                                setState(() => _errorText =
                                    'Supera el saldo libre en ${sel.name}.');
                                return;
                              }
                              await widget.provider.addSavingsToMiniGoal(
                                widget.goal.id,
                                amt,
                                fromAccountId: isSame ? null : sel.id,
                              );
                              if (context.mounted) Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.amberGold,
                              foregroundColor: Colors.black,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              isSame
                                  ? 'Confirmar apartado'
                                  : 'Confirmar transferencia',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

