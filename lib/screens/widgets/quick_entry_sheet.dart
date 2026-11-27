import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/account.dart';
import '../../models/credit_installment.dart';
import '../../models/transaction.dart';
import '../../providers/finance_provider.dart';
import 'category_form_dialog.dart';

class QuickEntrySheet extends StatefulWidget {
  final FinanceProvider provider;
  final String? initialAccountId;
  final bool lockAccount;

  const QuickEntrySheet({
    super.key,
    required this.provider,
    this.initialAccountId,
    this.lockAccount = false,
  });

  @override
  State<QuickEntrySheet> createState() => _QuickEntrySheetState();
}

class _QuickEntrySheetState extends State<QuickEntrySheet> {
  final TextEditingController _smartInputCtrl = TextEditingController();
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _interestCtrl = TextEditingController(text: '0');
  final TextEditingController _paidMonthsCtrl = TextEditingController(text: '0');

  bool _isNaturalInput = false; // Default to clear Guided Mode with Gasto/Ingreso/Transferencia
  String _selectedCategory = 'Comida';
  MovementType _selectedType = MovementType.expense;
  late String _selectedAccountId;
  late String _targetAccountId;
  DateTime _selectedDate = DateTime.now();
  int _installmentMonths = 1; // 1 = Contado, >1 = MSI/MCI
  bool _isInterestFree = true;
  bool _alreadyInBalance = false;
  bool _applyInCurrentPeriod = false;
  bool _manualCategoryOverride = false;
  bool _autoMatchedCategory = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl.addListener(_onTitleChanged);
    final accounts = widget.provider.accounts;
    if (widget.initialAccountId != null &&
        accounts.any((a) => a.id == widget.initialAccountId)) {
      _selectedAccountId = widget.initialAccountId!;
    } else {
      _selectedAccountId = accounts.isNotEmpty ? accounts.first.id : '';
    }
    _targetAccountId =
        accounts.where((a) => a.id != _selectedAccountId).firstOrNull?.id ??
            _selectedAccountId;
  }

  void _onTitleChanged() {
    if (_selectedType == MovementType.transfer || _manualCategoryOverride) return;
    final matched = widget.provider.matchCategoryByKeywords(
      _titleCtrl.text,
      isIncome: _selectedType == MovementType.income,
    );
    if (matched != null &&
        (matched.name != _selectedCategory || !_autoMatchedCategory)) {
      setState(() {
        _selectedCategory = matched.name;
        _autoMatchedCategory = true;
      });
    } else if (matched == null && _autoMatchedCategory) {
      setState(() => _autoMatchedCategory = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.removeListener(_onTitleChanged);
    _smartInputCtrl.dispose();
    _amountCtrl.dispose();
    _titleCtrl.dispose();
    _interestCtrl.dispose();
    _paidMonthsCtrl.dispose();
    super.dispose();
  }

  void _onTypeChanged(MovementType newType) {
    setState(() {
      _selectedType = newType;
      _manualCategoryOverride = false;
      _autoMatchedCategory = false;
      if (newType == MovementType.expense) {
        _selectedCategory =
            widget.provider.expenseCategories.firstOrNull?.name ?? 'Comida';
      } else if (newType == MovementType.income) {
        _selectedCategory =
            widget.provider.incomeCategories.firstOrNull?.name ?? 'Sueldo';
      } else {
        _selectedCategory = 'Transferencia';
      }
    });
    _onTitleChanged();
  }

  void _submitSmartInput() async {
    if (widget.provider.accounts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.amberGold,
            content: Text('Primero agrega una cuenta en la pestaña "Cuentas".'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    final text = _smartInputCtrl.text.trim();
    if (text.isEmpty) return;

    final success = await widget.provider.parseAndAddQuickEntry(text);
    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.emeraldGreen,
            content: Text('Movimiento registrado: "$text"'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.alertCoral,
            content: Text('Ingresa un monto válido. Ej: "250 Tacos Nu"'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  DateTime _currentPeriodStartForCutoff(int cutoffDay) {
    final now = DateTime.now();
    final safeCutoff = cutoffDay.clamp(1, 28);
    if (now.day > safeCutoff) {
      return DateTime(now.year, now.month, safeCutoff + 1);
    }
    final prevMonth = DateTime(now.year, now.month - 1, 1);
    final maxDay = DateTime(prevMonth.year, prevMonth.month + 1, 0).day;
    final startDay = (safeCutoff + 1) > maxDay ? maxDay : (safeCutoff + 1);
    return DateTime(prevMonth.year, prevMonth.month, startDay);
  }

  void _submitManual() async {
    if (widget.provider.accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.amberGold,
          content: Text('Primero agrega una cuenta en la pestaña "Cuentas".'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '').trim());
    final rawTitle = _titleCtrl.text.trim();
    final title = rawTitle.isEmpty
        ? (_selectedType == MovementType.transfer ? 'Transferencia' : _selectedCategory)
        : rawTitle;

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.alertCoral,
          content: Text('Por favor ingresa un monto mayor a 0.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_selectedType == MovementType.transfer && _selectedAccountId == _targetAccountId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.alertCoral,
          content: Text('La cuenta origen y destino deben ser diferentes.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final selectedAcc = widget.provider.accounts.where((a) => a.id == _selectedAccountId).firstOrNull;
    var effectiveDate = _selectedDate;
    if (_alreadyInBalance &&
        selectedAcc?.manualMonthlyDueAt != null &&
        effectiveDate.isAfter(selectedAcc!.manualMonthlyDueAt!)) {
      effectiveDate = selectedAcc.manualMonthlyDueAt!.subtract(const Duration(seconds: 1));
    }

    if (_selectedType == MovementType.expense &&
        selectedAcc?.type == AccountType.creditCard &&
        _installmentMonths > 1) {
      final interest = _isInterestFree
          ? 0.0
          : (double.tryParse(_interestCtrl.text.replaceAll(',', '').trim()) ?? 0.0);
      final paidMonths = (int.tryParse(_paidMonthsCtrl.text.trim()) ?? 0).clamp(0, _installmentMonths);
      await widget.provider.addInstallmentPlan(
        CreditInstallmentPlan(
          id: 'msi_${DateTime.now().millisecondsSinceEpoch}',
          accountId: _selectedAccountId,
          title: title,
          principalAmount: amount,
          interestAmount: interest,
          totalMonths: _installmentMonths,
          paidMonths: paidMonths,
          startDate: effectiveDate,
        ),
        isNewPurchase: !_alreadyInBalance,
      );
    } else {
      final currentPeriodStart = _currentPeriodStartForCutoff(selectedAcc?.cutoffDay ?? 15);
      final isBeforeCurrentPeriod = _selectedDate.isBefore(currentPeriodStart);
      await widget.provider.addTransaction(
        title: title,
        amount: amount,
        type: _selectedType == MovementType.income && _selectedCategory == 'Rendimientos'
            ? MovementType.yieldAccrual
            : _selectedType,
        category: _selectedCategory,
        accountId: _selectedAccountId,
        targetAccountId: _selectedType == MovementType.transfer ? _targetAccountId : null,
        date: effectiveDate,
        billingDate: (_applyInCurrentPeriod && isBeforeCurrentPeriod) ? currentPeriodStart : null,
        skipBalanceUpdate: _alreadyInBalance,
        triggerSavingsRules: !_alreadyInBalance,
      );
    }

    List<String> learnedKeywords = const [];
    if (_selectedType != MovementType.transfer) {
      learnedKeywords = await widget.provider.recordCategoryUsageAndAutoLearn(
        description: title,
        categoryName: _selectedCategory,
        isIncome: _selectedType == MovementType.income,
      );
    }

    if (mounted) {
      Navigator.pop(context);
      final learnedMsg = learnedKeywords.isNotEmpty
          ? ' • Auto-aprendido: ${learnedKeywords.map((w) => '"$w"').join(", ")} → $_selectedCategory'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.emeraldGreen,
          content: Text('Registrado: $title (\$$amount MXN)$learnedMsg'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCategories = _selectedType == MovementType.income
        ? widget.provider.incomeCategories
        : widget.provider.expenseCategories;

    final availableAccounts = _selectedType == MovementType.income
        ? widget.provider.accounts.where((a) => a.type != AccountType.creditCard).toList()
        : widget.provider.accounts;

    final safeSourceId = availableAccounts.any((a) => a.id == _selectedAccountId)
        ? _selectedAccountId
        : (availableAccounts.isNotEmpty ? availableAccounts.first.id : null);

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
                const Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.bolt, color: AppTheme.emeraldGreen),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Nuevo Movimiento',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    setState(() {
                      _isNaturalInput = !_isNaturalInput;
                    });
                  },
                  child: Text(
                    _isNaturalInput ? 'Modo Guiado' : 'Modo Texto Rápido',
                    style: const TextStyle(color: AppTheme.electricCyan, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isNaturalInput) ...[
              const Text(
                'Escribe el monto, concepto y cuenta en una sola línea:',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _smartInputCtrl,
                autofocus: true,
                style: const TextStyle(fontSize: 16, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'ej. 250 Tacos Nu  ó  18500 Sueldo BBVA',
                  hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppTheme.emeraldGreen, width: 2),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward_rounded, color: AppTheme.emeraldGreen),
                    onPressed: _submitSmartInput,
                  ),
                ),
                onSubmitted: (_) => _submitSmartInput(),
              ),
              const SizedBox(height: 14),
              const Text(
                'Atajos rápidos:',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildQuickSnippet('250 Tacos Nu'),
                  _buildQuickSnippet('60 Cafe Efectivo'),
                  _buildQuickSnippet('650 Gasolina BBVA'),
                  _buildQuickSnippet('15000 Sueldo BBVA'),
                ],
              ),
            ] else ...[
              // Explicit Movement Type Selector: Gasto | Ingreso | Transferencia
              Row(
                children: [
                  Expanded(
                    child: _buildTypeButton(
                      label: 'Gasto',
                      icon: Icons.arrow_upward_rounded,
                      type: MovementType.expense,
                      activeColor: AppTheme.alertCoral,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTypeButton(
                      label: 'Ingreso',
                      icon: Icons.arrow_downward_rounded,
                      type: MovementType.income,
                      activeColor: AppTheme.emeraldGreen,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTypeButton(
                      label: 'Transferencia',
                      icon: Icons.swap_horiz_rounded,
                      type: MovementType.transfer,
                      activeColor: AppTheme.electricCyan,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Amount & Concept
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                      decoration: InputDecoration(
                        prefixText: '\$ ',
                        labelText: 'Monto MXN',
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _titleCtrl,
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                      decoration: InputDecoration(
                        labelText: _selectedType == MovementType.income
                            ? 'Concepto (ej. Nómina, Bono)'
                            : (_selectedType == MovementType.transfer
                                ? 'Nota (ej. Ahorro semanal)'
                                : 'Concepto (ej. Tacos, Gas)'),
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),

              if (_selectedType != MovementType.transfer) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Text('Categoría:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    if (_autoMatchedCategory) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.electricCyan.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.electricCyan.withOpacity(0.45)),
                        ),
                        child: const Text(
                          'Auto por palabra clave',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.electricCyan,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: activeCategories.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) {
                      if (idx == activeCategories.length) {
                        return ActionChip(
                          avatar: const Icon(Icons.add,
                              size: 16, color: AppTheme.electricCyan),
                          label: const Text('Nueva'),
                          backgroundColor: AppTheme.surface,
                          side: BorderSide(
                              color: AppTheme.electricCyan.withOpacity(0.45)),
                          labelStyle: const TextStyle(
                            color: AppTheme.electricCyan,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          onPressed: () async {
                            final created = await showCategoryFormDialog(
                              context,
                              initialIsIncome:
                                  _selectedType == MovementType.income,
                              allowTypeToggle: false,
                            );
                            if (created != null) {
                              await widget.provider.addCategory(created);
                              if (mounted) {
                                setState(
                                    () => _selectedCategory = created.name);
                              }
                            }
                          },
                        );
                      }
                      final cat = activeCategories[idx];
                      final isSelected = cat.name == _selectedCategory;
                      final chipColor = cat.color;
                      return ChoiceChip(
                        avatar: Icon(
                          cat.iconData,
                          size: 15,
                          color: isSelected ? Colors.white : chipColor,
                        ),
                        label: Text(cat.name),
                        selected: isSelected,
                        selectedColor: chipColor.withOpacity(0.32),
                        backgroundColor: AppTheme.surface,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                        onSelected: (_) => setState(() {
                              _selectedCategory = cat.name;
                              _manualCategoryOverride = true;
                              _autoMatchedCategory = false;
                            }),
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 14),
              if (widget.lockAccount) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.electricCyan.withOpacity(0.35)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.credit_card, size: 16, color: AppTheme.electricCyan),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          () {
                            final acc = availableAccounts.where((a) => a.id == safeSourceId).firstOrNull;
                            return acc == null ? 'Tarjeta seleccionada' : 'Tarjeta: ${acc.name} (${acc.institution})';
                          }(),
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Text(
                  _selectedType == MovementType.income
                      ? 'Cuenta donde se deposita:'
                      : (_selectedType == MovementType.transfer ? 'Cuenta Origen:' : 'Cuenta de pago:'),
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: safeSourceId,
                  dropdownColor: AppTheme.surface,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: availableAccounts.map((acc) {
                    return DropdownMenuItem(
                      value: acc.id,
                      child: Text(
                        '${acc.name} (${acc.institution})',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedAccountId = val);
                  },
                ),
              ],

              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (picked != null) {
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    final pickedDay = DateTime(picked.year, picked.month, picked.day);
                    final isToday = pickedDay == today;
                    final nextDate = isToday ? now : pickedDay;
                    final selectedAcc = widget.provider.accounts
                        .where((a) => a.id == _selectedAccountId)
                        .firstOrNull;
                    final autoAlreadyInBalance =
                        selectedAcc?.type == AccountType.creditCard &&
                        pickedDay.isBefore(today) &&
                        selectedAcc?.manualMonthlyDueAt != null;
                    setState(() {
                      _selectedDate = nextDate;
                      if (autoAlreadyInBalance) {
                        _alreadyInBalance = true;
                      } else if (isToday) {
                        _alreadyInBalance = false;
                      }
                    });
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Fecha del movimiento:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      Row(
                        children: [
                          Text(
                            '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
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

              // MSI / MCI option when paying with a Credit Card
              if (_selectedType == MovementType.expense &&
                  widget.provider.accounts.any((a) => a.id == safeSourceId && a.type == AccountType.creditCard)) ...[
                const SizedBox(height: 12),
                const Text('Forma de pago en Tarjeta:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [1, 3, 6, 9, 12, 18].map((m) {
                    final selected = _installmentMonths == m;
                    return ChoiceChip(
                      label: Text(m == 1 ? 'Contado (1 pago)' : '$m meses'),
                      selected: selected,
                      selectedColor: AppTheme.electricCyan.withOpacity(0.25),
                      backgroundColor: AppTheme.surface,
                      labelStyle: TextStyle(fontSize: 11, color: selected ? Colors.white : AppTheme.textSecondary),
                      onSelected: (_) => setState(() => _installmentMonths = m),
                    );
                  }).toList(),
                ),
                if (_installmentMonths == 1)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Pago único: se incluirá al 100% en tu próximo corte.',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ),
                if (_installmentMonths > 1) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('MSI (Sin Interés)'),
                        selected: _isInterestFree,
                        selectedColor: AppTheme.emeraldGreen.withOpacity(0.25),
                        backgroundColor: AppTheme.surface,
                        labelStyle: TextStyle(fontSize: 11, color: _isInterestFree ? Colors.white : AppTheme.textSecondary),
                        onSelected: (_) => setState(() => _isInterestFree = true),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('MCI (Con Interés)'),
                        selected: !_isInterestFree,
                        selectedColor: AppTheme.amberGold.withOpacity(0.25),
                        backgroundColor: AppTheme.surface,
                        labelStyle: TextStyle(fontSize: 11, color: !_isInterestFree ? Colors.white : AppTheme.textSecondary),
                        onSelected: (_) => setState(() => _isInterestFree = false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _paidMonthsCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Meses ya pagados',
                            filled: true,
                            fillColor: AppTheme.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      if (!_isInterestFree) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _interestCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: AppTheme.amberGold, fontSize: 14),
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
                ],
                const SizedBox(height: 6),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('¿Ya está incluido en tu saldo actual?', style: TextStyle(fontSize: 12, color: Colors.white)),
                  subtitle: Text(
                    _alreadyInBalance
                        ? 'Cargo histórico: no sumará deuda extra.'
                        : 'Compra nueva: se sumará al saldo de tu tarjeta.',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                  value: _alreadyInBalance,
                  activeColor: AppTheme.electricCyan,
                  onChanged: (v) => setState(() => _alreadyInBalance = v),
                ),
                Builder(builder: (_) {
                  final cardAcc = widget.provider.accounts.where((a) => a.id == safeSourceId).firstOrNull;
                  if (cardAcc == null || _installmentMonths > 1) return const SizedBox.shrink();
                  final periodStart = _currentPeriodStartForCutoff(cardAcc.cutoffDay);
                  if (!_selectedDate.isBefore(periodStart)) return const SizedBox.shrink();
                  return SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Procesado después del corte (incluir en Período Actual)',
                      style: TextStyle(fontSize: 12, color: Colors.white),
                    ),
                    subtitle: const Text(
                      'Mantiene la fecha real de compra pero lo agrupa en el período actual.',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                    value: _applyInCurrentPeriod,
                    activeColor: AppTheme.amberGold,
                    onChanged: (v) => setState(() => _applyInCurrentPeriod = v),
                  );
                }),
              ],

              if (_selectedType == MovementType.transfer) ...[
                const SizedBox(height: 12),
                const Text('Cuenta Destino:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: widget.provider.accounts.any((a) => a.id == _targetAccountId)
                      ? _targetAccountId
                      : null,
                  dropdownColor: AppTheme.surface,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: widget.provider.accounts.map((acc) {
                    return DropdownMenuItem(
                      value: acc.id,
                      child: Text(
                        '${acc.name} (${acc.institution})',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _targetAccountId = val);
                  },
                ),
              ],

              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedType == MovementType.income
                        ? AppTheme.emeraldGreen
                        : (_selectedType == MovementType.transfer
                            ? AppTheme.electricCyan
                            : AppTheme.alertCoral),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.check),
                  label: Text(
                    _selectedType == MovementType.income
                        ? 'Registrar Ingreso'
                        : (_selectedType == MovementType.transfer
                            ? 'Registrar Transferencia'
                            : 'Registrar Gasto'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onPressed: _submitManual,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTypeButton({
    required String label,
    required IconData icon,
    required MovementType type,
    required Color activeColor,
  }) {
    final isSelected = _selectedType == type;
    return InkWell(
      onTap: () => _onTypeChanged(type),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.2) : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : AppTheme.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: isSelected ? activeColor : AppTheme.textMuted),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickSnippet(String text) {
    return InkWell(
      onTap: () {
        _smartInputCtrl.text = text;
        _submitSmartInput();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 12, color: AppTheme.electricCyan),
        ),
      ),
    );
  }
}
