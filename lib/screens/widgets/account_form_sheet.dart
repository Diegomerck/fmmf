import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/account.dart';
import '../../providers/finance_provider.dart';

class AccountFormSheet extends StatefulWidget {
  final FinanceProvider provider;
  final Account? existingAccount;
  final String? initialInstitution;

  const AccountFormSheet({
    super.key,
    required this.provider,
    this.existingAccount,
    this.initialInstitution,
  });

  @override
  State<AccountFormSheet> createState() => _AccountFormSheetState();
}

class _AccountFormSheetState extends State<AccountFormSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _institutionCtrl;
  late TextEditingController _balanceCtrl;
  late TextEditingController _yieldCtrl;
  late TextEditingController _goalCtrl;
  late TextEditingController _limitCtrl;
  late TextEditingController _cutoffCtrl;
  late TextEditingController _dueCtrl;
  late TextEditingController _availableCtrl;

  late AccountType _selectedType;
  late AccountPurpose _selectedPurpose;
  late String _selectedColorHex;
  bool _purposeManuallyChanged = false;
  bool _lastEditedAvailable = false;
  bool _isSyncingCreditFields = false;

  bool get _isEditing => widget.existingAccount != null;

  @override
  void initState() {
    super.initState();
    final acc = widget.existingAccount;
    _selectedType = acc?.type ?? AccountType.checking;
    _selectedPurpose = acc?.purpose ?? Account.defaultPurposeForType(_selectedType);
    _purposeManuallyChanged = acc != null;
    if (acc != null) {
      _selectedColorHex = acc.colorHex;
    } else {
      final used = widget.provider.accounts.map((a) => a.colorHex.toUpperCase()).toSet();
      _selectedColorHex = Account.colorPaletteHex.firstWhere(
        (c) => !used.contains(c.toUpperCase()),
        orElse: () => Account.colorPaletteHex[
            widget.provider.accounts.length % Account.colorPaletteHex.length],
      );
    }
    _nameCtrl = TextEditingController(text: acc?.name ?? '');
    _institutionCtrl = TextEditingController(
      text: acc?.institution ?? widget.initialInstitution ?? '',
    );
    _balanceCtrl = TextEditingController(
      text: acc != null ? acc.balance.toStringAsFixed(2) : '',
    );
    _yieldCtrl = TextEditingController(
      text: acc != null && acc.annualYieldRate > 0 ? acc.annualYieldRate.toString() : '',
    );
    _goalCtrl = TextEditingController(
      text: acc != null && acc.savingsGoal > 0 ? acc.savingsGoal.toStringAsFixed(0) : '',
    );
    _limitCtrl = TextEditingController(
      text: acc != null && acc.creditLimit > 0 ? acc.creditLimit.toStringAsFixed(0) : '',
    );
    _cutoffCtrl = TextEditingController(
      text: acc != null && acc.cutoffDay > 0 ? acc.cutoffDay.toString() : '24',
    );
    _dueCtrl = TextEditingController(
      text: acc != null && acc.paymentDueDay > 0 ? acc.paymentDueDay.toString() : '14',
    );
    final initialAvailable = (acc != null && acc.type == AccountType.creditCard && acc.creditLimit > 0)
        ? (acc.creditLimit - acc.balance).clamp(0.0, double.infinity).toStringAsFixed(2)
        : '';
    _availableCtrl = TextEditingController(text: initialAvailable);
  }

  double _parseNum(String s) => double.tryParse(s.replaceAll(',', '').trim()) ?? 0.0;

  void _onBalanceChanged(String _) {
    if (_isSyncingCreditFields || _selectedType != AccountType.creditCard) return;
    _lastEditedAvailable = false;
    final limit = _parseNum(_limitCtrl.text);
    if (limit <= 0) return;
    _isSyncingCreditFields = true;
    final debt = _parseNum(_balanceCtrl.text);
    _availableCtrl.text = (limit - debt).clamp(0.0, double.infinity).toStringAsFixed(2);
    _isSyncingCreditFields = false;
  }

  void _onAvailableChanged(String _) {
    if (_isSyncingCreditFields || _selectedType != AccountType.creditCard) return;
    _lastEditedAvailable = true;
    final limit = _parseNum(_limitCtrl.text);
    if (limit <= 0) return;
    _isSyncingCreditFields = true;
    final avail = _parseNum(_availableCtrl.text);
    _balanceCtrl.text = (limit - avail).clamp(0.0, double.infinity).toStringAsFixed(2);
    _isSyncingCreditFields = false;
  }

  void _onLimitChanged(String _) {
    if (_isSyncingCreditFields || _selectedType != AccountType.creditCard) return;
    final limit = _parseNum(_limitCtrl.text);
    if (limit <= 0) return;
    _isSyncingCreditFields = true;
    if (_lastEditedAvailable) {
      final avail = _parseNum(_availableCtrl.text);
      _balanceCtrl.text = (limit - avail).clamp(0.0, double.infinity).toStringAsFixed(2);
    } else {
      final debt = _parseNum(_balanceCtrl.text);
      _availableCtrl.text = (limit - debt).clamp(0.0, double.infinity).toStringAsFixed(2);
    }
    _isSyncingCreditFields = false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _institutionCtrl.dispose();
    _balanceCtrl.dispose();
    _yieldCtrl.dispose();
    _goalCtrl.dispose();
    _limitCtrl.dispose();
    _cutoffCtrl.dispose();
    _dueCtrl.dispose();
    _availableCtrl.dispose();
    super.dispose();
  }

  String _typeLabel(AccountType type) {
    switch (type) {
      case AccountType.checking:
        return 'Débito / Nómina';
      case AccountType.savings:
        return 'Ahorros';
      case AccountType.yieldVault:
        return 'Cajita / Rendimiento';
      case AccountType.investment:
        return 'Inversión / Bolsa';
      case AccountType.creditCard:
        return 'Tarjeta de Crédito';
      case AccountType.cash:
        return 'Efectivo';
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final institution = _institutionCtrl.text.trim();
    final balance = double.tryParse(_balanceCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
    final yieldRate = double.tryParse(_yieldCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
    final savingsGoal = double.tryParse(_goalCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
    final creditLimit = double.tryParse(_limitCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
    final cutoffDay = int.tryParse(_cutoffCtrl.text.trim()) ?? 0;
    final dueDay = int.tryParse(_dueCtrl.text.trim()) ?? 0;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.alertCoral,
          content: Text('Ingresa un nombre para la cuenta.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final account = Account(
      id: widget.existingAccount?.id ?? 'acc_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      institution: institution.isEmpty ? 'Personal' : institution,
      type: _selectedType,
      balance: balance < 0 ? 0.0 : balance,
      annualYieldRate: (_selectedType == AccountType.yieldVault || _selectedType == AccountType.investment)
          ? yieldRate
          : 0.0,
      savingsGoal: _selectedType == AccountType.savings ? savingsGoal : 0.0,
      creditLimit: _selectedType == AccountType.creditCard ? creditLimit : 0.0,
      cutoffDay: _selectedType == AccountType.creditCard ? cutoffDay.clamp(1, 31) : 0,
      paymentDueDay: _selectedType == AccountType.creditCard ? dueDay.clamp(1, 31) : 0,
      manualMonthlyDueOverride: widget.existingAccount?.manualMonthlyDueOverride,
      manualMonthlyDueAt: widget.existingAccount?.manualMonthlyDueAt,
      colorHex: _selectedColorHex,
      purpose: _selectedType == AccountType.creditCard
          ? AccountPurpose.general
          : _selectedPurpose,
    );

    if (_isEditing) {
      await widget.provider.updateAccount(account);
    } else {
      await widget.provider.addAccount(account);
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!_isEditing) return;
    await widget.provider.deleteAccount(widget.existingAccount!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isYield = _selectedType == AccountType.yieldVault || _selectedType == AccountType.investment;
    final isSavings = _selectedType == AccountType.savings;
    final isCredit = _selectedType == AccountType.creditCard;

    final String nameHint = switch (_selectedType) {
      AccountType.checking => 'Nombre (ej. BBVA Nómina)',
      AccountType.savings => 'Nombre (ej. Ahorro Personal)',
      AccountType.yieldVault => 'Nombre (ej. Nu Cajita, Cetes)',
      AccountType.investment => 'Nombre (ej. GBM+, Fintual)',
      AccountType.creditCard => 'Nombre (ej. Tarjeta Nu)',
      AccountType.cash => 'Nombre (ej. Efectivo)',
    };

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
                  _isEditing ? 'Editar Cuenta' : 'Nueva Cuenta',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                if (_isEditing)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppTheme.alertCoral),
                    tooltip: 'Eliminar cuenta',
                    onPressed: _delete,
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Type selector
            const Text('Tipo de Cuenta', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AccountType.values.map((t) {
                final selected = t == _selectedType;
                return ChoiceChip(
                  label: Text(_typeLabel(t)),
                  selected: selected,
                  selectedColor: AppTheme.emeraldGreen.withOpacity(0.25),
                  backgroundColor: AppTheme.surface,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: selected ? Colors.white : AppTheme.textSecondary,
                  ),
                  onSelected: (_) => setState(() {
                    _selectedType = t;
                    if (!_purposeManuallyChanged) {
                      _selectedPurpose = Account.defaultPurposeForType(t);
                    }
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Name & Institution
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: nameHint,
                      filled: true,
                      fillColor: AppTheme.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _institutionCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Banco / App',
                      filled: true,
                      fillColor: AppTheme.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            Builder(builder: (_) {
              final existingBanks = <String>{};
              for (final a in widget.provider.accounts) {
                final trimmed = a.institution.trim();
                if (trimmed.isNotEmpty &&
                    !existingBanks.any((b) => b.toLowerCase() == trimmed.toLowerCase())) {
                  existingBanks.add(trimmed);
                }
              }
              if (existingBanks.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isEditing ? 'Mover a otro banco:' : 'Bancos existentes:',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: existingBanks.map((bank) {
                        return ActionChip(
                          label: Text(bank, style: const TextStyle(fontSize: 11, color: AppTheme.electricCyan)),
                          backgroundColor: AppTheme.surface,
                          side: BorderSide(color: AppTheme.electricCyan.withOpacity(0.35)),
                          onPressed: () => setState(() => _institutionCtrl.text = bank),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            }),
            if (isCredit) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _limitCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      onChanged: _onLimitChanged,
                      decoration: InputDecoration(
                        prefixText: '\$ ',
                        labelText: 'Límite Crédito',
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _cutoffCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Día Corte',
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _dueCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Día Pago',
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),

            // Balance (or Bidirectional Debt <-> Available for Credit Cards)
            if (isCredit) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _balanceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.alertCoral),
                      onChanged: _onBalanceChanged,
                      decoration: InputDecoration(
                        prefixText: '\$ ',
                        labelText: 'Deuda (Utilizado)',
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.swap_horiz, size: 18, color: AppTheme.textMuted),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _availableCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.emeraldGreen),
                      onChanged: _onAvailableChanged,
                      decoration: InputDecoration(
                        prefixText: '\$ ',
                        labelText: 'Disponible',
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Captura tu deuda o tu crédito disponible; el otro se calcula automáticamente con tu límite.',
                style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
              ),
            ] else
              TextField(
                controller: _balanceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                decoration: InputDecoration(
                  prefixText: '\$ ',
                  suffixText: 'MXN',
                  labelText: 'Saldo Actual',
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),

            if (isSavings) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _goalCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  prefixText: '\$ ',
                  suffixText: 'MXN',
                  labelText: 'Meta de Ahorro (Opcional, ej. 50000)',
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],

            if (isYield) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _yieldCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  suffixText: '% Anual',
                  labelText: 'Tasa de Rendimiento (ej. 13.5)',
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],

            if (!isCredit) ...[
              const SizedBox(height: 16),
              const Text('¿Para qué planeas usar esta cuenta?', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  (AccountPurpose.debtPayment, 'Pago de Tarjetas'),
                  (AccountPurpose.fixedExpenses, 'Gastos Fijos'),
                  (AccountPurpose.general, 'Uso General'),
                  (AccountPurpose.protectedGoal, 'Ahorro Protegido'),
                ].map((entry) {
                  final p = entry.$1;
                  final label = entry.$2;
                  final selected = _selectedPurpose == p;
                  return ChoiceChip(
                    label: Text(label),
                    selected: selected,
                    selectedColor: AppTheme.electricCyan.withOpacity(0.22),
                    backgroundColor: AppTheme.surface,
                    labelStyle: TextStyle(
                      fontSize: 11.5,
                      color: selected ? Colors.white : AppTheme.textSecondary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                    ),
                    onSelected: (_) => setState(() {
                      _selectedPurpose = p;
                      _purposeManuallyChanged = true;
                    }),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 16),
            const Text('Color de la cuenta:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: Account.colorPaletteHex.map((hex) {
                final c = Account.parseColorHex(hex);
                final isSelected = _selectedColorHex.toUpperCase() == hex.toUpperCase();
                return GestureDetector(
                  onTap: () => setState(() => _selectedColorHex = hex),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 16, color: Colors.black)
                        : null,
                  ),
                );
              }).toList(),
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
                  _isEditing ? 'Guardar Cambios' : 'Agregar Cuenta',
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

