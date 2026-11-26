import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/budget_commitment.dart';
import '../../providers/finance_provider.dart';

class CommitmentFormSheet extends StatefulWidget {
  final FinanceProvider provider;
  final BudgetCommitment? existingCommitment;

  const CommitmentFormSheet({
    super.key,
    required this.provider,
    this.existingCommitment,
  });

  @override
  State<CommitmentFormSheet> createState() => _CommitmentFormSheetState();
}

class _CommitmentFormSheetState extends State<CommitmentFormSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _dueDayCtrl;
  late String _category;
  late String _selectedAccountId;
  late bool _isPaidThisMonth;
  late bool _isAutopay;
  bool _toggledPaidManually = false;

  bool get _isEditing => widget.existingCommitment != null;

  @override
  void initState() {
    super.initState();
    final c = widget.existingCommitment;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _amountCtrl = TextEditingController(
      text: c != null ? c.amount.toStringAsFixed(2) : '',
    );
    _dueDayCtrl = TextEditingController(
      text: c != null ? c.dueDay.toString() : '1',
    );
    _category = c?.category ?? 'Servicios';
    final accounts = widget.provider.accounts;
    final hasExistingAcc = c != null && accounts.any((a) => a.id == c.accountId);
    _selectedAccountId = hasExistingAcc
        ? c.accountId
        : (accounts.isNotEmpty ? accounts.first.id : 'default');
    _isPaidThisMonth = c?.isPaidThisMonth ?? false;
    _isAutopay = c?.isAutopay ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _dueDayCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
    final dueDay = int.tryParse(_dueDayCtrl.text.trim()) ?? 1;

    if (name.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.alertCoral,
          content: Text('Ingresa nombre y monto válido.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final item = BudgetCommitment(
      id: widget.existingCommitment?.id ?? 'com_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      amount: amount,
      dueDay: dueDay.clamp(1, 31),
      category: _category,
      accountId: _selectedAccountId,
      isPaidThisMonth: _isPaidThisMonth,
      isAutopay: _isAutopay,
    );

    if (_isEditing) {
      await widget.provider.updateCommitment(item);
    } else {
      await widget.provider.addCommitment(item);
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!_isEditing) return;
    await widget.provider.deleteCommitment(widget.existingCommitment!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isEditing ? 'Editar Gasto Fijo' : 'Nuevo Gasto Fijo',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                if (_isEditing)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppTheme.alertCoral),
                    onPressed: _delete,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Concepto (ej. Renta, Internet, Gimnasio)',
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      prefixText: '\$ ',
                      suffixText: 'MXN',
                      labelText: 'Monto Mensual',
                      filled: true,
                      fillColor: AppTheme.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _dueDayCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Día de Pago',
                      filled: true,
                      fillColor: AppTheme.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (val) {
                      final day = int.tryParse(val.trim());
                      if (day != null && !_toggledPaidManually && day > DateTime.now().day) {
                        setState(() => _isPaidThisMonth = false);
                      }
                    },
                  ),
                ),
              ],
            ),
            if (widget.provider.accounts.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                'Cuenta o Tarjeta donde se cobra:',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.provider.accounts.map((acc) {
                  final selected = acc.id == _selectedAccountId;
                  return ChoiceChip(
                    avatar: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: acc.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    label: Text(acc.name),
                    selected: selected,
                    selectedColor: acc.color.withOpacity(0.25),
                    backgroundColor: AppTheme.surface,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: selected ? Colors.white : AppTheme.textSecondary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                    ),
                    onSelected: (_) => setState(() => _selectedAccountId = acc.id),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SwitchListTile(
                title: const Text(
                  'Pago domiciliado (automático)',
                  style: TextStyle(fontSize: 14, color: Colors.white),
                ),
                subtitle: Text(
                  _isAutopay
                      ? 'Se carga automáticamente a la cuenta/tarjeta seleccionada'
                      : 'Pago manual cada mes',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
                value: _isAutopay,
                activeColor: AppTheme.electricCyan,
                onChanged: (val) => setState(() => _isAutopay = val),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SwitchListTile(
                title: const Text(
                  'Pagado este mes',
                  style: TextStyle(fontSize: 14, color: Colors.white),
                ),
                subtitle: Text(
                  _isPaidThisMonth
                      ? 'Ya no se descuenta de tu Safe-to-Spend'
                      : 'Pendiente: reservado en tu Safe-to-Spend',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
                value: _isPaidThisMonth,
                activeColor: AppTheme.emeraldGreen,
                onChanged: (val) {
                  setState(() {
                    _isPaidThisMonth = val;
                    _toggledPaidManually = true;
                  });
                },
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.emeraldGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.check),
                label: Text(
                  _isEditing ? 'Guardar Cambios' : 'Agregar Gasto Fijo',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onPressed: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

