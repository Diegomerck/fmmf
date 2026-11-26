import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_format.dart';
import '../../models/account.dart';
import '../../models/credit_installment.dart';
import '../../providers/finance_provider.dart';

class InstallmentPlanSheet extends StatefulWidget {
  final FinanceProvider provider;
  final Account card;
  final CreditInstallmentPlan? existingPlan;

  const InstallmentPlanSheet({
    super.key,
    required this.provider,
    required this.card,
    this.existingPlan,
  });

  @override
  State<InstallmentPlanSheet> createState() => _InstallmentPlanSheetState();
}

class _InstallmentPlanSheetState extends State<InstallmentPlanSheet> {
  late TextEditingController _titleCtrl;
  late TextEditingController _customNameCtrl;
  late TextEditingController _principalCtrl;
  late TextEditingController _interestCtrl;
  late TextEditingController _monthsCtrl;
  late TextEditingController _paidMonthsCtrl;

  DateTime _startDate = DateTime.now();
  bool _isInterestFree = true;
  bool _alreadyInCardBalance = true;

  bool get _isEditing => widget.existingPlan != null;

  @override
  void initState() {
    super.initState();
    final p = widget.existingPlan;
    _titleCtrl = TextEditingController(text: p?.title ?? '');
    _customNameCtrl = TextEditingController(text: p?.customName ?? '');
    _principalCtrl = TextEditingController(text: p != null ? p.principalAmount.toStringAsFixed(2) : '');
    _interestCtrl = TextEditingController(text: p != null && p.interestAmount > 0 ? p.interestAmount.toStringAsFixed(2) : '0');
    _monthsCtrl = TextEditingController(text: p != null ? p.totalMonths.toString() : '6');
    _paidMonthsCtrl = TextEditingController(text: p != null ? p.paidMonths.toString() : '0');
    _startDate = p?.startDate ?? DateTime.now();
    _isInterestFree = p?.isInterestFree ?? true;
    _alreadyInCardBalance = widget.card.balance > 0;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _customNameCtrl.dispose();
    _principalCtrl.dispose();
    _interestCtrl.dispose();
    _monthsCtrl.dispose();
    _paidMonthsCtrl.dispose();
    super.dispose();
  }

  double get _previewPrincipal => double.tryParse(_principalCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
  double get _previewInterest => _isInterestFree ? 0.0 : (double.tryParse(_interestCtrl.text.replaceAll(',', '').trim()) ?? 0.0);
  int get _previewMonths => (int.tryParse(_monthsCtrl.text.trim()) ?? 1).clamp(1, 120);
  double get _previewMonthly => (_previewPrincipal + _previewInterest) / _previewMonths;

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final principal = _previewPrincipal;
    final interest = _previewInterest;
    final months = _previewMonths;
    final paidMonths = (int.tryParse(_paidMonthsCtrl.text.trim()) ?? 0).clamp(0, months);

    if (title.isEmpty || principal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.alertCoral,
          content: Text('Ingresa un concepto y monto válido.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final customName = _customNameCtrl.text.trim();
    final plan = CreditInstallmentPlan(
      id: widget.existingPlan?.id ?? 'msi_${DateTime.now().millisecondsSinceEpoch}',
      accountId: widget.card.id,
      title: title,
      customName: customName.isEmpty ? null : customName,
      principalAmount: principal,
      interestAmount: interest,
      totalMonths: months,
      paidMonths: paidMonths,
      startDate: _startDate,
    );

    if (_isEditing) {
      await widget.provider.updateInstallmentPlan(plan);
    } else {
      await widget.provider.addInstallmentPlan(
        plan,
        isNewPurchase: !_alreadyInCardBalance,
      );
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!_isEditing) return;
    await widget.provider.deleteInstallmentPlan(widget.existingPlan!.id);
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
                  _isEditing ? 'Editar Compra a Meses' : 'Compra a Meses (${widget.card.name})',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
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
              controller: _customNameCtrl,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                labelText: '¿Qué compraste? (Nombre personalizado, ej. Monitor LG)',
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _titleCtrl,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Descripción en banco / comercio (ej. AMAZON A MESES)',
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),

            // Original purchase date picker
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                );
                if (picked != null) {
                  final now = DateTime.now();
                  final elapsed = ((now.year - picked.year) * 12 + (now.month - picked.month)).clamp(0, _previewMonths);
                  setState(() {
                    _startDate = picked;
                    if (!_isEditing && elapsed > 0) {
                      _paidMonthsCtrl.text = elapsed.toString();
                    }
                  });
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Fecha original de compra:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    Row(
                      children: [
                        Text(
                          '${_startDate.day}/${_startDate.month}/${_startDate.year}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.electricCyan),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.calendar_today, size: 15, color: AppTheme.electricCyan),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Sin Intereses (MSI)'),
                    selected: _isInterestFree,
                    selectedColor: AppTheme.emeraldGreen.withOpacity(0.25),
                    backgroundColor: AppTheme.surface,
                    labelStyle: TextStyle(color: _isInterestFree ? Colors.white : AppTheme.textSecondary, fontSize: 12),
                    onSelected: (_) => setState(() => _isInterestFree = true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Con Intereses (MCI)'),
                    selected: !_isInterestFree,
                    selectedColor: AppTheme.amberGold.withOpacity(0.25),
                    backgroundColor: AppTheme.surface,
                    labelStyle: TextStyle(color: !_isInterestFree ? Colors.white : AppTheme.textSecondary, fontSize: 12),
                    onSelected: (_) => setState(() => _isInterestFree = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _principalCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      prefixText: '\$ ',
                      labelText: 'Precio del artículo',
                      filled: true,
                      fillColor: AppTheme.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                if (!_isInterestFree) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _interestCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: AppTheme.amberGold, fontWeight: FontWeight.w700),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        prefixText: '\$ ',
                        labelText: 'Interés total',
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Months quick chips + custom
            const Text('Plazo (meses):', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [3, 6, 9, 12, 18, 24].map((m) {
                final selected = _monthsCtrl.text.trim() == m.toString();
                return ChoiceChip(
                  label: Text('$m m'),
                  selected: selected,
                  selectedColor: AppTheme.electricCyan.withOpacity(0.25),
                  backgroundColor: AppTheme.surface,
                  labelStyle: TextStyle(fontSize: 12, color: selected ? Colors.white : AppTheme.textSecondary),
                  onSelected: (_) => setState(() => _monthsCtrl.text = m.toString()),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _monthsCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Total meses',
                      filled: true,
                      fillColor: AppTheme.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _paidMonthsCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Meses ya pagados',
                      filled: true,
                      fillColor: AppTheme.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),

            if (!_isEditing) ...[
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('¿Ya está incluido en el saldo actual?', style: TextStyle(fontSize: 13, color: Colors.white)),
                subtitle: Text(
                  _alreadyInCardBalance
                      ? 'No suma deuda extra; desglosa tu saldo actual en mensualidades.'
                      : 'Compra nueva: sumará el monto total a tu deuda de tarjeta.',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
                value: _alreadyInCardBalance,
                activeColor: AppTheme.emeraldGreen,
                onChanged: (val) => setState(() => _alreadyInCardBalance = val),
              ),
            ],

            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Mensualidad:', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  Text(
                    '${CurrencyFormat.formatMXN(_previewMonthly)} / mes',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.electricCyan),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

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
                  _isEditing ? 'Guardar Cambios' : 'Guardar Plan a Meses',
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

