import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_format.dart';
import '../../models/account.dart';
import '../../models/mini_goal.dart';
import '../../providers/finance_provider.dart';

class MiniGoalSheet extends StatefulWidget {
  final FinanceProvider provider;
  final MiniGoal? existingGoal;

  const MiniGoalSheet({
    super.key,
    required this.provider,
    this.existingGoal,
  });

  @override
  State<MiniGoalSheet> createState() => _MiniGoalSheetState();
}

class _MiniGoalSheetState extends State<MiniGoalSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _targetCtrl;
  late TextEditingController _savedCtrl;
  late TextEditingController _customIntervalCtrl;
  late DateTime _dueDate;
  DateTime? _endDate;
  late String _repeatPreset; // 'none', 'm3', 'm6', 'm12', 'custom'
  late String _customUnit; // 'days' or 'months'
  String? _selectedAccountId;
  String? _errorText;

  List<Account> get _accountCandidates => widget.provider.accounts
      .where((a) => a.type != AccountType.creditCard)
      .toList();

  @override
  void initState() {
    super.initState();
    final g = widget.existingGoal;
    _nameCtrl = TextEditingController(text: g?.name ?? '');
    _targetCtrl = TextEditingController(
      text: g != null ? g.targetAmount.toStringAsFixed(0) : '',
    );
    _savedCtrl = TextEditingController(
      text: g != null && g.savedAmount > 0
          ? g.savedAmount.toStringAsFixed(0)
          : '',
    );
    final now = DateTime.now();
    _dueDate = g?.dueDate ?? DateTime(now.year, now.month + 1, now.day);
    _endDate = g?.endDate;

    final candidates = _accountCandidates;
    if (g?.accountId != null &&
        candidates.any((a) => a.id == g!.accountId)) {
      _selectedAccountId = g!.accountId;
    } else if (candidates.isNotEmpty) {
      _selectedAccountId = candidates.first.id;
    }

    if (g == null) {
      _repeatPreset = 'none';
      _customUnit = 'days';
      _customIntervalCtrl = TextEditingController(text: '30');
    } else if (g.repeatDays > 0) {
      _repeatPreset = 'custom';
      _customUnit = 'days';
      _customIntervalCtrl =
          TextEditingController(text: g.repeatDays.toString());
    } else if (g.repeatMonths == 0) {
      _repeatPreset = 'none';
      _customUnit = 'months';
      _customIntervalCtrl = TextEditingController(text: '2');
    } else if (g.repeatMonths == 3) {
      _repeatPreset = 'm3';
      _customUnit = 'months';
      _customIntervalCtrl = TextEditingController(text: '3');
    } else if (g.repeatMonths == 6) {
      _repeatPreset = 'm6';
      _customUnit = 'months';
      _customIntervalCtrl = TextEditingController(text: '6');
    } else if (g.repeatMonths == 12) {
      _repeatPreset = 'm12';
      _customUnit = 'months';
      _customIntervalCtrl = TextEditingController(text: '12');
    } else {
      _repeatPreset = 'custom';
      _customUnit = 'months';
      _customIntervalCtrl =
          TextEditingController(text: g.repeatMonths.toString());
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    _savedCtrl.dispose();
    _customIntervalCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate.isBefore(now) ? now : _dueDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 15),
    );
    if (picked != null && mounted) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _pickEndDate() async {
    final base = _endDate ?? _dueDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: base.isBefore(_dueDate) ? _dueDate : base,
      firstDate: DateTime(_dueDate.year, _dueDate.month, _dueDate.day),
      lastDate: DateTime(_dueDate.year + 20),
    );
    if (picked != null && mounted) {
      setState(() => _endDate = picked);
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final target =
        double.tryParse(_targetCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
    final saved =
        double.tryParse(_savedCtrl.text.replaceAll(',', '').trim()) ?? 0.0;

    if (name.isEmpty || target <= 0) {
      setState(() => _errorText = 'Ingresa un nombre y un monto mayor a \$0.');
      return;
    }

    if (_selectedAccountId != null && saved > 0) {
      final acc = _accountCandidates
          .where((a) => a.id == _selectedAccountId)
          .firstOrNull;
      if (acc != null) {
        final alreadyEarmarked = widget.provider.earmarkedMiniGoalsForAccount(
          acc.id,
          excludeGoalId: widget.existingGoal?.id,
        );
        final available = (acc.balance - alreadyEarmarked)
            .clamp(0.0, double.infinity);
        if (saved > available + 0.01) {
          setState(() => _errorText =
              'En ${acc.name} solo tienes ${CurrencyFormat.formatMXN(available)} libres para apartar.');
          return;
        }
      }
    }

    int repeatMonths = 0;
    int repeatDays = 0;
    if (_repeatPreset == 'm3') {
      repeatMonths = 3;
    } else if (_repeatPreset == 'm6') {
      repeatMonths = 6;
    } else if (_repeatPreset == 'm12') {
      repeatMonths = 12;
    } else if (_repeatPreset == 'custom') {
      final n = int.tryParse(_customIntervalCtrl.text.trim()) ?? 0;
      if (n <= 0) {
        setState(() =>
            _errorText = 'Ingresa cada cuántos días o meses se repite.');
        return;
      }
      if (_customUnit == 'days') {
        repeatDays = n;
      } else {
        repeatMonths = n;
      }
    }

    final existing = widget.existingGoal;
    final goal = existing != null
        ? existing.copyWith(
            name: name,
            targetAmount: target,
            savedAmount: saved.clamp(0.0, target),
            dueDate: _dueDate,
            endDate: _endDate,
            clearEndDate: _endDate == null,
            repeatMonths: repeatMonths,
            repeatDays: repeatDays,
            accountId: _selectedAccountId,
            clearAccountId: _selectedAccountId == null,
          )
        : MiniGoal(
            id: 'mg_${DateTime.now().millisecondsSinceEpoch}',
            name: name,
            targetAmount: target,
            savedAmount: saved.clamp(0.0, target),
            dueDate: _dueDate,
            endDate: _endDate,
            repeatMonths: repeatMonths,
            repeatDays: repeatDays,
            accountId: _selectedAccountId,
          );

    if (existing != null) {
      await widget.provider.updateMiniGoal(goal);
    } else {
      await widget.provider.addMiniGoal(goal);
    }
    if (mounted) Navigator.pop(context);
  }

  Widget _fieldLabel(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.88;
    final accounts = _accountCandidates;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Container(
          decoration: const BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pinned header with close button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.existingGoal != null
                                ? 'Editar Mini-Meta'
                                : 'Nueva Mini-Meta',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Pagos periódicos o metas puntuales.',
                            style: TextStyle(
                                fontSize: 11.5, color: AppTheme.textSecondary),
                          ),
                        ],
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
              ),
              const Divider(color: AppTheme.border, height: 1),
              // Scrollable body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _fieldLabel(
                        'Nombre',
                        '¿Qué gasto o meta quieres cubrir?',
                      ),
                      TextField(
                        controller: _nameCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText:
                              'Ej. Seguro del auto, Plan de teléfono...',
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (accounts.isNotEmpty) ...[
                        _fieldLabel(
                          '¿En qué cuenta guardas este apartado?',
                          'El dinero apartado se reservará dentro del saldo real de esta cuenta.',
                        ),
                        DropdownButtonFormField<String>(
                          value: _selectedAccountId,
                          isExpanded: true,
                          dropdownColor: AppTheme.surface,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13.5),
                          items: accounts
                              .map((a) => DropdownMenuItem(
                                    value: a.id,
                                    child: Text(
                                      '${a.name} (${CurrencyFormat.formatMXN(a.balance, includeDecimals: false)})',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() {
                            _selectedAccountId = v;
                            _errorText = null;
                          }),
                        ),
                        const SizedBox(height: 14),
                      ],
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _fieldLabel(
                                  'Monto a pagar (\$)',
                                  'Total que cuesta este pago.',
                                ),
                                TextField(
                                  controller: _targetCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  style: const TextStyle(color: Colors.white),
                                  decoration:
                                      const InputDecoration(hintText: '0'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _fieldLabel(
                                  'Ya apartado (\$)',
                                  'Si ya separaste algo en esa cuenta.',
                                ),
                                TextField(
                                  controller: _savedCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  style: const TextStyle(color: Colors.white),
                                  decoration:
                                      const InputDecoration(hintText: '0'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _fieldLabel(
                        'Próxima fecha de pago',
                        'El día en que te toca hacer este pago (o cumplir la meta).',
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_today_rounded,
                              size: 15),
                          label: Text(
                            'Fecha: ${_dueDate.day}/${_dueDate.month}/${_dueDate.year}',
                            style: const TextStyle(fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: AppTheme.border),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _fieldLabel(
                        'Se repite',
                        'Cada cuánto vuelve a tocar o personalízalo en días o meses.',
                      ),
                      DropdownButtonFormField<String>(
                        value: _repeatPreset,
                        dropdownColor: AppTheme.surface,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13.5),
                        items: const [
                          DropdownMenuItem(
                              value: 'none', child: Text('Una sola vez')),
                          DropdownMenuItem(
                              value: 'm3', child: Text('Cada 3 meses')),
                          DropdownMenuItem(
                              value: 'm6', child: Text('Cada 6 meses')),
                          DropdownMenuItem(
                              value: 'm12', child: Text('Cada 12 meses')),
                          DropdownMenuItem(
                            value: 'custom',
                            child: Text('Personalizado (días o meses)'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _repeatPreset = v);
                        },
                      ),
                      if (_repeatPreset == 'custom') ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _customIntervalCtrl,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  labelText: 'Cada cuánto (número)',
                                  hintText: 'Ej. 23',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _customUnit,
                                dropdownColor: AppTheme.surface,
                                style: const TextStyle(color: Colors.white),
                                decoration:
                                    const InputDecoration(labelText: 'Unidad'),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'days', child: Text('Días')),
                                  DropdownMenuItem(
                                      value: 'months', child: Text('Meses')),
                                ],
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() => _customUnit = v);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 14),
                      _fieldLabel(
                        'Fecha fin (opcional)',
                        'Último día en que seguirá activo. Déjalo sin límite si es indefinido.',
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickEndDate,
                              icon: const Icon(Icons.event_available_rounded,
                                  size: 15),
                              label: Text(
                                _endDate != null
                                    ? 'Termina: ${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                                    : 'Sin fecha fin',
                                style: const TextStyle(fontSize: 12.5),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _endDate != null
                                    ? AppTheme.amberGold
                                    : AppTheme.textSecondary,
                                side: const BorderSide(color: AppTheme.border),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 11),
                              ),
                            ),
                          ),
                          if (_endDate != null) ...[
                            const SizedBox(width: 6),
                            IconButton(
                              onPressed: () => setState(() => _endDate = null),
                              icon: const Icon(Icons.close_rounded,
                                  size: 18, color: AppTheme.textMuted),
                              tooltip: 'Quitar fecha fin',
                            ),
                          ],
                        ],
                      ),
                      if (_errorText != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _errorText!,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.alertCoral),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Divider(color: AppTheme.border, height: 1),
              // Pinned footer with Cancelar + Guardar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary,
                          side: const BorderSide(color: AppTheme.border),
                          padding: const EdgeInsets.symmetric(vertical: 13),
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
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.electricCyan,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Guardar Mini-Meta'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
