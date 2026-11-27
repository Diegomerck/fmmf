import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/currency_format.dart';
import '../models/account.dart';
import '../providers/finance_provider.dart';

class FundingPriorityScreen extends StatefulWidget {
  final FinanceProvider provider;

  const FundingPriorityScreen({super.key, required this.provider});

  @override
  State<FundingPriorityScreen> createState() => _FundingPriorityScreenState();
}

class _FundingPriorityScreenState extends State<FundingPriorityScreen> {
  late List<Account> _ordered;

  @override
  void initState() {
    super.initState();
    _ordered = List<Account>.from(widget.provider.orderedFundingAccounts);
  }

  Future<void> _saveOrder() async {
    await widget.provider.updateFundingPriority(
      _ordered.map((a) => a.id).toList(),
    );
  }

  Future<void> _move(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _ordered.removeAt(oldIndex);
      _ordered.insert(newIndex, item);
    });
    await _saveOrder();
  }

  String _purposeLabel(AccountPurpose p) {
    switch (p) {
      case AccountPurpose.debtPayment:
        return 'Destinada a Tarjetas';
      case AccountPurpose.fixedExpenses:
        return 'Destinada a Gastos Fijos';
      case AccountPurpose.protectedGoal:
        return 'Ahorro protegido';
      case AccountPurpose.general:
        return 'Uso general';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Prioridad para Cubrir Faltantes'),
        backgroundColor: AppTheme.surface,
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline,
                    color: AppTheme.amberGold, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Si algún mes te falta dinero para cubrir tus pagos, la app te sugerirá tomar fondos en este orden: primero el #1 y hasta el final tu ahorro más protegido.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _ordered.isEmpty
                ? const Center(
                    child: Text(
                      'Agrega al menos una cuenta de débito o ahorro.',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    buildDefaultDragHandles: false,
                    itemCount: _ordered.length,
                    onReorder: _move,
                    itemBuilder: (context, index) {
                      final acc = _ordered[index];
                      final isLast = index == _ordered.length - 1;
                      return Container(
                        key: ValueKey(acc.id),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isLast
                                ? AppTheme.amberGold.withOpacity(0.35)
                                : AppTheme.border,
                          ),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: acc.color.withOpacity(0.18),
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: acc.color,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  acc.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isLast && _ordered.length > 1)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color:
                                        AppTheme.amberGold.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Último recurso',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.amberGold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            '${_purposeLabel(acc.purpose)} • ${CurrencyFormat.formatMXN(acc.balance, includeDecimals: false)}',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_upward, size: 18),
                                color: index > 0
                                    ? AppTheme.textSecondary
                                    : AppTheme.textMuted.withOpacity(0.3),
                                onPressed: index > 0
                                    ? () => _move(index, index - 1)
                                    : null,
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.arrow_downward, size: 18),
                                color: index < _ordered.length - 1
                                    ? AppTheme.textSecondary
                                    : AppTheme.textMuted.withOpacity(0.3),
                                onPressed: index < _ordered.length - 1
                                    ? () => _move(index, index + 2)
                                    : null,
                              ),
                              ReorderableDragStartListener(
                                index: index,
                                child: const Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: Icon(Icons.drag_handle,
                                      color: AppTheme.textMuted),
                                ),
                              ),
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
  }
}

