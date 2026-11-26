import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/currency_format.dart';
import '../models/account.dart';
import '../models/recurring_income.dart';
import '../providers/finance_provider.dart';
import 'widgets/account_form_sheet.dart';
import 'widgets/recurring_income_sheet.dart';
import 'widgets/commitment_form_sheet.dart';
import 'widgets/savings_rule_sheet.dart';

class SetupWizardScreen extends StatefulWidget {
  final FinanceProvider provider;
  final VoidCallback onComplete;

  const SetupWizardScreen({
    super.key,
    required this.provider,
    required this.onComplete,
  });

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  int _step = 0;
  String? _activeBank;
  final TextEditingController _customBankCtrl = TextEditingController();

  static const List<String> _presetBanks = [
    'Banamex',
    'BBVA',
    'Nu México',
    'Santander',
    'Banorte',
    'Cetesdirecto',
    'Mercado Pago',
    'Efectivo',
  ];

  @override
  void dispose() {
    _customBankCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.provider,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Configuración Inicial • FMMF', style: TextStyle(fontSize: 17)),
            actions: [
              TextButton(
                onPressed: widget.onComplete,
                child: const Text('Ir a la App', style: TextStyle(color: AppTheme.textSecondary)),
              ),
            ],
          ),
          body: Column(
            children: [
              // Stepper Indicator
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    _buildStepPill(0, '1. Cuentas'),
                    const SizedBox(width: 8),
                    _buildStepPill(1, '2. Ingresos'),
                    const SizedBox(width: 8),
                    _buildStepPill(2, '3. Reglas y Fijos'),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: switch (_step) {
                    0 => _buildStep1Accounts(context),
                    1 => _buildStep2Incomes(context),
                    _ => _buildStep3RulesAndCommitments(context),
                  },
                ),
              ),
              // Bottom Navigation Bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppTheme.surface,
                  border: Border(top: BorderSide(color: AppTheme.border)),
                ),
                child: Row(
                  children: [
                    if (_step > 0)
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary,
                          side: const BorderSide(color: AppTheme.border),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => setState(() => _step--),
                        child: const Text('Atrás'),
                      ),
                    if (_step > 0) const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.emeraldGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          if (_step < 2) {
                            setState(() => _step++);
                          } else {
                            widget.onComplete();
                          }
                        },
                        child: Text(
                          _step < 2 ? 'Continuar →' : 'Finalizar y ver Resumen',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStepPill(int index, String label) {
    final isActive = _step == index;
    final isDone = _step > index;
    final color = isActive
        ? AppTheme.emeraldGreen
        : (isDone ? AppTheme.electricCyan : AppTheme.border);

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _step = index),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? color.withOpacity(0.18) : AppTheme.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isActive || isDone ? Colors.white : AppTheme.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1Accounts(BuildContext context) {
    // Group existing accounts case-insensitively by bank
    final Map<String, List<Account>> byBank = {};
    for (final acc in widget.provider.accounts) {
      final rawBank = acc.institution.trim().isEmpty ? 'Personal' : acc.institution.trim();
      final existingKey = byBank.keys.firstWhere(
        (k) => k.toLowerCase() == rawBank.toLowerCase(),
        orElse: () => rawBank,
      );
      byBank.putIfAbsent(existingKey, () => []).add(acc);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '¡Hola! Bienvenido a FMMF',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        const SizedBox(height: 6),
        const Text(
          'Paso 1: Configuremos uno de tus bancos o instituciones. Todo lo que agregues debajo vivirá bajo ese banco (débito, ahorros, tarjetas de crédito).',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 18),

        if (_activeBank == null) ...[
          const Text(
            'Elige o escribe tu banco / app:',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presetBanks.map((bank) {
              return ActionChip(
                label: Text(bank, style: const TextStyle(color: Colors.white, fontSize: 13)),
                backgroundColor: AppTheme.card,
                side: const BorderSide(color: AppTheme.border),
                onPressed: () => setState(() => _activeBank = bank),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customBankCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Otro banco o institución (ej. Hey Banco)',
                    hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.electricCyan,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final custom = _customBankCtrl.text.trim();
                  if (custom.isNotEmpty) {
                    setState(() {
                      _activeBank = custom;
                      _customBankCtrl.clear();
                    });
                  }
                },
                child: const Text('Usar'),
              ),
            ],
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.cardHighlight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.emeraldGreen.withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_balance, color: AppTheme.emeraldGreen, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _activeBank!,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () => setState(() => _activeBank = null),
                      child: const Text('Cambiar / Otro banco', style: TextStyle(color: AppTheme.electricCyan, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.emeraldGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.add),
                    label: Text(
                      'Agregar cuenta o tarjeta en $_activeBank',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => AccountFormSheet(
                          provider: widget.provider,
                          initialInstitution: _activeBank,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),
        if (byBank.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'Elige un banco arriba para comenzar a agregar tus cuentas.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
            ),
          )
        else
          ...byBank.entries.map((entry) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.electricCyan),
                      ),
                      Text(
                        '${entry.value.length} cuenta(s)',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...entry.value.map((acc) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(acc.name, style: const TextStyle(color: Colors.white, fontSize: 13)),
                            Text(
                              CurrencyFormat.formatMXN(acc.balance),
                              style: TextStyle(
                                color: acc.type == AccountType.creditCard ? AppTheme.alertCoral : Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildStep2Incomes(BuildContext context) {
    final canAdd = widget.provider.accounts.where((a) => a.type != AccountType.creditCard).isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Paso 2: ¿Cómo y cuándo te pagan?',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        const SizedBox(height: 6),
        const Text(
          'Configura tu sueldo o ingresos recurrentes (diario, semanal, quincenal, mensual, anual o calendario personalizado). Puedes saltarlo si prefieres registrar ingresos manualmente.',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.cardHighlight,
              foregroundColor: AppTheme.electricCyan,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: AppTheme.electricCyan.withOpacity(0.4)),
              ),
            ),
            icon: const Icon(Icons.payments_outlined),
            label: const Text('Agregar Ingreso Recurrente', style: TextStyle(fontWeight: FontWeight.w700)),
            onPressed: !canAdd
                ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: AppTheme.amberGold,
                        content: Text('Regresa al Paso 1 y agrega primero una cuenta de débito o ahorros.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                : () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => RecurringIncomeSheet(provider: widget.provider),
                    );
                  },
          ),
        ),
        const SizedBox(height: 18),
        ...widget.provider.recurringIncomes.map((inc) {
          final freqText = switch (inc.frequency) {
            IncomeFrequency.daily => 'Diario',
            IncomeFrequency.weekly => 'Semanal',
            IncomeFrequency.biweekly => 'Quincenal',
            IncomeFrequency.monthly => 'Mensual',
            IncomeFrequency.yearly => 'Anual',
            IncomeFrequency.custom => 'Calendario Personalizado',
          };
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(inc.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    Text(freqText, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
                Text(
                  '+${CurrencyFormat.formatMXN(inc.amount, includeDecimals: false)}',
                  style: const TextStyle(color: AppTheme.emeraldGreen, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStep3RulesAndCommitments(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Paso 3: Gastos Fijos y Reglas',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        const SizedBox(height: 6),
        const Text(
          'Agrega tus pagos fijos del mes (Renta, Internet) y opcionalmente reglas automáticas para apartar un % a tus Ahorros.',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.cardHighlight,
                  foregroundColor: AppTheme.amberGold,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: AppTheme.amberGold.withOpacity(0.4)),
                  ),
                ),
                icon: const Icon(Icons.calendar_month, size: 16),
                label: const Text('+ Gasto Fijo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => CommitmentFormSheet(provider: widget.provider),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.cardHighlight,
                  foregroundColor: AppTheme.emeraldGreen,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: AppTheme.emeraldGreen.withOpacity(0.4)),
                  ),
                ),
                icon: const Icon(Icons.autorenew, size: 16),
                label: const Text('+ Regla Ahorro', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                onPressed: widget.provider.accounts.length < 2
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: AppTheme.amberGold,
                            content: Text('Necesitas al menos 2 cuentas para crear una regla de ahorro.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    : () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => SavingsRuleSheet(provider: widget.provider),
                        );
                      },
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (widget.provider.commitments.isNotEmpty) ...[
          const Text('Gastos Fijos:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 6),
          ...widget.provider.commitments.map((c) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(c.name, style: const TextStyle(color: Colors.white, fontSize: 13)),
                trailing: Text(CurrencyFormat.formatMXN(c.amount, includeDecimals: false),
                    style: const TextStyle(color: AppTheme.amberGold, fontWeight: FontWeight.w700)),
              )),
        ],
        if (widget.provider.savingsRules.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text('Reglas de Ahorro:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 6),
          ...widget.provider.savingsRules.map((r) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(r.name, style: const TextStyle(color: Colors.white, fontSize: 13)),
                trailing: const Icon(Icons.check_circle, color: AppTheme.emeraldGreen, size: 18),
              )),
        ],
      ],
    );
  }
}

