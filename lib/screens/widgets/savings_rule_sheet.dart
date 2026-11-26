import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/account.dart';
import '../../models/savings_rule.dart';
import '../../providers/finance_provider.dart';

class SavingsRuleSheet extends StatefulWidget {
  final FinanceProvider provider;
  final SavingsRule? existingRule;

  const SavingsRuleSheet({
    super.key,
    required this.provider,
    this.existingRule,
  });

  @override
  State<SavingsRuleSheet> createState() => _SavingsRuleSheetState();
}

class _SavingsRuleSheetState extends State<SavingsRuleSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _valueCtrl;
  late RoutingFrequency _frequency;
  String? _sourceAccountId;
  late String _targetAccountId;
  late bool _isActive;

  bool get _isEditing => widget.existingRule != null;

  @override
  void initState() {
    super.initState();
    final r = widget.existingRule;
    _frequency = r?.frequency ?? RoutingFrequency.onIncome;
    _nameCtrl = TextEditingController(text: r?.name ?? '');
    _valueCtrl = TextEditingController(
      text: r != null
          ? (r.frequency == RoutingFrequency.onIncome
              ? r.percentage.toStringAsFixed(0)
              : r.fixedAmount.toStringAsFixed(0))
          : '10',
    );
    _isActive = r?.isActive ?? true;
    _sourceAccountId = r?.sourceAccountId;

    final nonCreditAccounts = widget.provider.accounts
        .where((a) => a.type != AccountType.creditCard)
        .toList();
    final savingsFirst = nonCreditAccounts.where((a) => a.type == AccountType.savings).toList();

    _targetAccountId = r?.targetAccountId ??
        (savingsFirst.isNotEmpty
            ? savingsFirst.first.id
            : (nonCreditAccounts.isNotEmpty ? nonCreditAccounts.first.id : ''));

    if (_frequency != RoutingFrequency.onIncome && _sourceAccountId == null && nonCreditAccounts.isNotEmpty) {
      _sourceAccountId = nonCreditAccounts.first.id;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  String _freqLabel(RoutingFrequency f) {
    switch (f) {
      case RoutingFrequency.onIncome:
        return '% de cada Ingreso';
      case RoutingFrequency.daily:
        return 'Diario';
      case RoutingFrequency.weekly:
        return 'Semanal';
      case RoutingFrequency.monthly:
        return 'Mensual';
      case RoutingFrequency.yearly:
        return 'Anual';
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final val = double.tryParse(_valueCtrl.text.replaceAll(',', '').trim()) ?? 0.0;

    if (name.isEmpty || val <= 0 || _targetAccountId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.alertCoral,
          content: Text('Completa el nombre, cuenta destino y un valor mayor a 0.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_frequency != RoutingFrequency.onIncome && (_sourceAccountId == null || _sourceAccountId == _targetAccountId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.alertCoral,
          content: Text('Selecciona una cuenta origen distinta a la cuenta destino.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final rule = SavingsRule(
      id: widget.existingRule?.id ?? 'rule_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      targetAccountId: _targetAccountId,
      sourceAccountId: _sourceAccountId,
      frequency: _frequency,
      percentage: _frequency == RoutingFrequency.onIncome ? val.clamp(0.1, 100.0) : 0.0,
      fixedAmount: _frequency != RoutingFrequency.onIncome ? val : 0.0,
      isActive: _isActive,
      lastTriggeredAt: widget.existingRule?.lastTriggeredAt,
    );

    if (_isEditing) {
      await widget.provider.updateSavingsRule(rule);
    } else {
      await widget.provider.addSavingsRule(rule);
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!_isEditing) return;
    await widget.provider.deleteSavingsRule(widget.existingRule!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final nonCreditAccounts = widget.provider.accounts
        .where((a) => a.type != AccountType.creditCard)
        .toList();

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
                  _isEditing ? 'Editar Regla de Ahorro' : 'Nueva Regla de Ahorro',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                if (_isEditing)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppTheme.alertCoral),
                    onPressed: _delete,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'La app te sugerirá la transferencia en el período elegido para que tú la confirmes, ajustes o la omitas.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Nombre de la regla (ej. Ahorro Personal 10%)',
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),

            const Text('Frecuencia / Disparador', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: RoutingFrequency.values.map((f) {
                final selected = f == _frequency;
                return ChoiceChip(
                  label: Text(_freqLabel(f)),
                  selected: selected,
                  selectedColor: AppTheme.emeraldGreen.withOpacity(0.25),
                  backgroundColor: AppTheme.surface,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: selected ? Colors.white : AppTheme.textSecondary,
                  ),
                  onSelected: (_) {
                    setState(() {
                      _frequency = f;
                      if (f != RoutingFrequency.onIncome && _sourceAccountId == null && nonCreditAccounts.isNotEmpty) {
                        _sourceAccountId = nonCreditAccounts.first.id;
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _valueCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
              decoration: InputDecoration(
                prefixText: _frequency == RoutingFrequency.onIncome ? '' : '\$ ',
                suffixText: _frequency == RoutingFrequency.onIncome ? '% del ingreso' : 'MXN',
                labelText: _frequency == RoutingFrequency.onIncome
                    ? 'Porcentaje a apartar'
                    : 'Monto sugerido por período',
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),

            // Source Account
            const Text('Cuenta Origen', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String?>(
              value: _sourceAccountId,
              dropdownColor: AppTheme.surface,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: [
                if (_frequency == RoutingFrequency.onIncome)
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Cuenta donde caiga el ingreso (Automático)', style: TextStyle(color: AppTheme.electricCyan, fontSize: 13)),
                  ),
                ...nonCreditAccounts.map((acc) => DropdownMenuItem<String?>(
                      value: acc.id,
                      child: Text(acc.name, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    )),
              ],
              onChanged: (val) => setState(() => _sourceAccountId = val),
            ),
            const SizedBox(height: 12),

            // Target Account
            const Text('Cuenta Destino (Ahorros)', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: nonCreditAccounts.any((a) => a.id == _targetAccountId) ? _targetAccountId : null,
              dropdownColor: AppTheme.surface,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: nonCreditAccounts.map((acc) {
                return DropdownMenuItem(
                  value: acc.id,
                  child: Text(
                    '${acc.name} (${acc.type == AccountType.savings ? "Ahorros" : acc.institution})',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _targetAccountId = val);
              },
            ),
            const SizedBox(height: 18),

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
                  _isEditing ? 'Guardar Regla' : 'Crear Regla de Ahorro',
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

