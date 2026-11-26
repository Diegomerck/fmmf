import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/account.dart';
import '../../models/recurring_income.dart';
import '../../providers/finance_provider.dart';

class RecurringIncomeSheet extends StatefulWidget {
  final FinanceProvider provider;
  final RecurringIncome? existingIncome;

  const RecurringIncomeSheet({
    super.key,
    required this.provider,
    this.existingIncome,
  });

  @override
  State<RecurringIncomeSheet> createState() => _RecurringIncomeSheetState();
}

class _RecurringIncomeSheetState extends State<RecurringIncomeSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _payDayCtrl;
  late IncomeFrequency _frequency;
  late String _accountId;
  final List<DateTime> _customDates = [];

  bool get _isEditing => widget.existingIncome != null;

  @override
  void initState() {
    super.initState();
    final inc = widget.existingIncome;
    _nameCtrl = TextEditingController(text: inc?.name ?? '');
    _amountCtrl = TextEditingController(
      text: inc != null ? inc.amount.toStringAsFixed(2) : '',
    );
    _payDayCtrl = TextEditingController(
      text: inc != null ? inc.payDay.toString() : '15',
    );
    _frequency = inc?.frequency ?? IncomeFrequency.biweekly;

    if (inc != null && inc.frequency == IncomeFrequency.custom) {
      final occs = widget.provider.getOccurrencesForIncome(inc.id);
      _customDates.addAll(occs.map((o) => o.date));
    }

    final nonCredit = widget.provider.accounts
        .where((a) => a.type != AccountType.creditCard)
        .toList();
    _accountId = inc?.accountId ?? (nonCredit.isNotEmpty ? nonCredit.first.id : '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _payDayCtrl.dispose();
    super.dispose();
  }

  String _freqLabel(IncomeFrequency f) {
    switch (f) {
      case IncomeFrequency.daily:
        return 'Diario';
      case IncomeFrequency.weekly:
        return 'Semanal';
      case IncomeFrequency.biweekly:
        return 'Quincenal';
      case IncomeFrequency.monthly:
        return 'Mensual';
      case IncomeFrequency.yearly:
        return 'Anual';
      case IncomeFrequency.custom:
        return 'Calendario Personalizado';
    }
  }

  Future<void> _pickCustomDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      final norm = DateTime(picked.year, picked.month, picked.day);
      final exists = _customDates.any(
        (d) => d.year == norm.year && d.month == norm.month && d.day == norm.day,
      );
      if (!exists) {
        setState(() {
          _customDates.add(norm);
          _customDates.sort();
        });
      }
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
    final payDay = int.tryParse(_payDayCtrl.text.trim()) ?? 15;

    if (name.isEmpty || amount <= 0 || _accountId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.alertCoral,
          content: Text('Completa el nombre, monto válido y cuenta destino.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_frequency == IncomeFrequency.custom && _customDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.alertCoral,
          content: Text('Agrega al menos una fecha en tu calendario personalizado.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final item = RecurringIncome(
      id: widget.existingIncome?.id ?? 'inc_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      amount: amount,
      frequency: _frequency,
      payDay: payDay.clamp(1, 31),
      accountId: _accountId,
      isActive: widget.existingIncome?.isActive ?? true,
      lastLoggedAt: widget.existingIncome?.lastLoggedAt,
    );

    if (_isEditing) {
      await widget.provider.updateRecurringIncome(
        item,
        customDates: _frequency == IncomeFrequency.custom ? _customDates : null,
      );
    } else {
      await widget.provider.addRecurringIncome(
        item,
        customDates: _frequency == IncomeFrequency.custom ? _customDates : null,
      );
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!_isEditing) return;
    await widget.provider.deleteRecurringIncome(widget.existingIncome!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final nonCredit = widget.provider.accounts
        .where((a) => a.type != AccountType.creditCard)
        .toList();

    final standardFrequencies = [
      IncomeFrequency.daily,
      IncomeFrequency.weekly,
      IncomeFrequency.biweekly,
      IncomeFrequency.monthly,
      IncomeFrequency.yearly,
    ];

    final showPayDayField = _frequency == IncomeFrequency.biweekly ||
        _frequency == IncomeFrequency.monthly ||
        _frequency == IncomeFrequency.yearly;

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
                  _isEditing ? 'Editar Ingreso Recurrente' : 'Nuevo Ingreso Recurrente',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                if (_isEditing)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppTheme.alertCoral),
                    onPressed: _delete,
                  ),
              ],
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Concepto (ej. Nómina Empleo, Freelance)',
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
                      labelText: 'Monto Base Neto',
                      filled: true,
                      fillColor: AppTheme.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                if (showPayDayField) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _payDayCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Día de pago',
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),

            const Text('Frecuencia estándar:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: standardFrequencies.map((f) {
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
                  onSelected: (_) => setState(() => _frequency = f),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),

            // Secondary optional custom schedule toggle
            ChoiceChip(
              avatar: Icon(
                Icons.calendar_month_outlined,
                size: 16,
                color: _frequency == IncomeFrequency.custom ? AppTheme.electricCyan : AppTheme.textMuted,
              ),
              label: const Text('Opción avanzada: Calendario Personalizado'),
              selected: _frequency == IncomeFrequency.custom,
              selectedColor: AppTheme.electricCyan.withOpacity(0.2),
              backgroundColor: AppTheme.surface,
              labelStyle: TextStyle(
                fontSize: 12,
                color: _frequency == IncomeFrequency.custom ? Colors.white : AppTheme.textSecondary,
              ),
              onSelected: (_) => setState(() => _frequency = IncomeFrequency.custom),
            ),

            if (_frequency == IncomeFrequency.custom) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Fechas seleccionadas (${_customDates.length})',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 16, color: AppTheme.electricCyan),
                          label: const Text('Agregar Fecha', style: TextStyle(color: AppTheme.electricCyan, fontSize: 12)),
                          onPressed: _pickCustomDate,
                        ),
                      ],
                    ),
                    if (_customDates.isEmpty)
                      const Text(
                        'Toca "Agregar Fecha" para elegir los días exactos en que te pagan.',
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      )
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _customDates.map((d) {
                          return Chip(
                            label: Text('${d.day}/${d.month}/${d.year}', style: const TextStyle(fontSize: 11, color: Colors.white)),
                            backgroundColor: AppTheme.card,
                            deleteIconColor: AppTheme.alertCoral,
                            onDeleted: () => setState(() => _customDates.remove(d)),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),

            const Text('Cuenta donde se deposita:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: nonCredit.any((a) => a.id == _accountId) ? _accountId : null,
              dropdownColor: AppTheme.surface,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: nonCredit.map((acc) {
                return DropdownMenuItem(
                  value: acc.id,
                  child: Text(
                    '${acc.name} (${acc.institution})',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _accountId = val);
              },
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
                  _isEditing ? 'Guardar Cambios' : 'Guardar Ingreso Recurrente',
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
