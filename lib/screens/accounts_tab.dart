import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/currency_format.dart';
import '../models/account.dart';
import '../providers/finance_provider.dart';
import 'credit_card_detail_screen.dart';
import 'widgets/account_form_sheet.dart';

class AccountsTab extends StatefulWidget {
  final FinanceProvider provider;

  const AccountsTab({super.key, required this.provider});

  @override
  State<AccountsTab> createState() => _AccountsTabState();
}

class _AccountsTabState extends State<AccountsTab> {
  bool _groupByBank = true; // Default: grouped under each Bank / Institution

  void _openAccountForm(BuildContext context, [Account? existing, String? initialInstitution]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AccountFormSheet(
        provider: widget.provider,
        existingAccount: existing,
        initialInstitution: initialInstitution,
      ),
    );
  }

  String _typeBadge(AccountType type) {
    switch (type) {
      case AccountType.checking:
        return 'Débito';
      case AccountType.savings:
        return 'Ahorros';
      case AccountType.yieldVault:
        return 'Rendimiento';
      case AccountType.investment:
        return 'Inversión';
      case AccountType.creditCard:
        return 'Crédito';
      case AccountType.cash:
        return 'Efectivo';
      case AccountType.vouchers:
        return 'Vales';
      case AccountType.savingsFund:
        return 'Fondo Ahorro';
    }
  }

  @override
  Widget build(BuildContext context) {
    final analysis = widget.provider.analysis;
    final accounts = widget.provider.accounts;

    final savingsAccounts = accounts.where((a) => a.type == AccountType.savings).toList();
    final yieldAccounts = accounts
        .where((a) => a.type == AccountType.yieldVault || a.type == AccountType.investment)
        .toList();
    final checkingAndCash = accounts
        .where((a) => a.type == AccountType.checking || a.type == AccountType.cash)
        .toList();
    final creditCards = accounts.where((a) => a.type == AccountType.creditCard).toList();
    final voucherAccounts = accounts.where((a) => a.type == AccountType.vouchers).toList();
    final savingsFundAccounts = accounts.where((a) => a.type == AccountType.savingsFund).toList();

    // Case-insensitive grouping by Bank / Institution
    final Map<String, List<Account>> byBank = {};
    for (final acc in accounts) {
      final rawBank = acc.institution.trim().isEmpty ? 'Personal' : acc.institution.trim();
      final existingKey = byBank.keys.firstWhere(
        (k) => k.toLowerCase() == rawBank.toLowerCase(),
        orElse: () => rawBank,
      );
      byBank.putIfAbsent(existingKey, () => []).add(acc);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Controls: View Mode Toggle + Add Account
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildToggleChip('Por Banco', _groupByBank, () => setState(() => _groupByBank = true)),
                    _buildToggleChip('Por Tipo', !_groupByBank, () => setState(() => _groupByBank = false)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.emeraldGreen.withOpacity(0.18),
                  foregroundColor: AppTheme.emeraldGreen,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: AppTheme.emeraldGreen.withOpacity(0.4)),
                  ),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Agregar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                onPressed: () => _openAccountForm(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Passive Yield Banner
          if (analysis.monthlyPassiveYield > 0) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.purpleGlow.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Rendimiento Pasivo Mensual', style: TextStyle(fontSize: 11, color: Colors.white70)),
                      SizedBox(height: 2),
                      Text('Tu dinero generando dinero', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                    ],
                  ),
                  Text(
                    '+${CurrencyFormat.formatMXN(analysis.monthlyPassiveYield)}/mes',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.emeraldGreen),
                  ),
                ],
              ),
            ),
          ],

          if (accounts.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined, size: 40, color: AppTheme.textMuted),
                  const SizedBox(height: 12),
                  const Text(
                    'Aún no tienes cuentas registradas',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Agrega tu cuenta de nómina, ahorros, cajita de rendimiento, efectivo o tarjeta de crédito para comenzar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.emeraldGreen,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Crear mi primera cuenta'),
                    onPressed: () => _openAccountForm(context),
                  ),
                ],
              ),
            )
          else if (_groupByBank) ...[
            // GROUPED BY BANK / INSTITUTION
            ...byBank.entries.map(
              (entry) => _buildBankGroup(
                context,
                entry.key,
                entry.value,
                byBank.keys.where((k) => k != entry.key).toList(),
              ),
            ),
          ] else ...[
            // GROUPED BY TYPE
            if (savingsAccounts.isNotEmpty) ...[
              _buildSectionHeader('Cuentas de Ahorro (Ahorros)', Icons.account_balance_wallet, AppTheme.emeraldGreen),
              const SizedBox(height: 8),
              ...savingsAccounts.map((a) => _buildAccountCard(context, a)),
              const SizedBox(height: 18),
            ],
            if (yieldAccounts.isNotEmpty) ...[
              _buildSectionHeader('Cuentas de Rendimiento e Inversión', Icons.savings_outlined, AppTheme.purpleGlow),
              const SizedBox(height: 8),
              ...yieldAccounts.map((a) => _buildAccountCard(context, a)),
              const SizedBox(height: 18),
            ],
            if (checkingAndCash.isNotEmpty) ...[
              _buildSectionHeader('Cuentas de Débito y Efectivo', Icons.account_balance_wallet_outlined, AppTheme.electricCyan),
              const SizedBox(height: 8),
              ...checkingAndCash.map((a) => _buildAccountCard(context, a)),
              const SizedBox(height: 18),
            ],
            if (creditCards.isNotEmpty) ...[
              _buildSectionHeader('Tarjetas de Crédito (Deudas y Cortes)', Icons.credit_card_outlined, AppTheme.alertCoral),
              const SizedBox(height: 8),
              ...creditCards.map((a) => _buildCreditCardCard(context, a)),
              const SizedBox(height: 18),
            ],
            if (voucherAccounts.isNotEmpty) ...[
              _buildSectionHeader('Vales y Beneficios', Icons.confirmation_number_outlined, AppTheme.amberGold),
              const SizedBox(height: 8),
              ...voucherAccounts.map((a) => _buildAccountCard(context, a)),
              const SizedBox(height: 18),
            ],
            if (savingsFundAccounts.isNotEmpty) ...[
              _buildSectionHeader('Fondos / Cajas de Ahorro', Icons.lock_clock_outlined, AppTheme.electricCyan),
              const SizedBox(height: 8),
              ...savingsFundAccounts.map((a) => _buildAccountCard(context, a)),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildToggleChip(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppTheme.emeraldGreen.withOpacity(0.22) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  void _showRenameBankDialog(BuildContext context, String bankName) {
    final ctrl = TextEditingController(text: bankName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('Renombrar Banco', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Nuevo nombre del banco',
            filled: true,
            fillColor: AppTheme.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emeraldGreen, foregroundColor: Colors.white),
            onPressed: () async {
              final nextName = ctrl.text.trim();
              if (nextName.isNotEmpty) {
                await widget.provider.renameOrMergeBank(bankName, nextName);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showMergeBankDialog(BuildContext context, String fromBank, List<String> otherBanks) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: Text('Fusionar "$fromBank" con...', style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Todas las cuentas de este grupo se moverán al banco destino:',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            ...otherBanks.map((target) => ListTile(
                  leading: const Icon(Icons.account_balance, color: AppTheme.electricCyan),
                  title: Text(target, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  onTap: () async {
                    await widget.provider.renameOrMergeBank(fromBank, target);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _buildBankGroup(
    BuildContext context,
    String bankName,
    List<Account> bankAccounts,
    List<String> otherBanks,
  ) {
    double netBankBalance = 0;
    for (final a in bankAccounts) {
      if (!a.includeInGeneralFinances) continue;
      if (a.type == AccountType.creditCard) {
        netBankBalance -= a.balance;
      } else {
        netBankBalance += a.balance;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.account_balance, size: 18, color: AppTheme.electricCyan),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        bankName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Text(
                    CurrencyFormat.formatMXN(netBankBalance, includeDecimals: false),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: netBankBalance < 0 ? AppTheme.alertCoral : AppTheme.emeraldGreen,
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => _openAccountForm(context, null, bankName),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.emeraldGreen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 14, color: AppTheme.emeraldGreen),
                          SizedBox(width: 2),
                          Text('Cuenta', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.emeraldGreen)),
                        ],
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18, color: AppTheme.textSecondary),
                    color: AppTheme.card,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onSelected: (val) {
                      if (val == 'rename') {
                        _showRenameBankDialog(context, bankName);
                      } else if (val == 'merge') {
                        _showMergeBankDialog(context, bankName, otherBanks);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'rename',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 16, color: AppTheme.electricCyan),
                            SizedBox(width: 8),
                            Text('Renombrar banco', style: TextStyle(color: Colors.white, fontSize: 13)),
                          ],
                        ),
                      ),
                      if (otherBanks.isNotEmpty)
                        const PopupMenuItem(
                          value: 'merge',
                          child: Row(
                            children: [
                              Icon(Icons.merge_type, size: 16, color: AppTheme.emeraldGreen),
                              SizedBox(width: 8),
                              Text('Fusionar con otro banco', style: TextStyle(color: Colors.white, fontSize: 13)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Builder(
            builder: (_) {
              final hasCredit = bankAccounts.any((a) => a.type == AccountType.creditCard);
              final String summaryText;
              if (netBankBalance < 0) {
                summaryText =
                    'Balance neto (débito + ahorro − tarjetas): ${CurrencyFormat.formatMXN(netBankBalance, includeDecimals: false)}. Si usaras tu dinero aquí para pagar tus tarjetas, faltarían ${CurrencyFormat.formatMXN(netBankBalance.abs(), includeDecimals: false)}.';
              } else if (hasCredit) {
                summaryText =
                    'Balance neto (débito + ahorro − tarjetas): quedarían ${CurrencyFormat.formatMXN(netBankBalance, includeDecimals: false)} libres si liquidaras tus tarjetas de este banco.';
              } else {
                summaryText =
                    'Balance neto total disponible en este banco.';
              }
              return Text(
                summaryText,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                  height: 1.3,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          ..._buildBankSubSections(context, bankAccounts),
        ],
      ),
    );
  }

  List<Widget> _buildBankSubSections(BuildContext context, List<Account> bankAccounts) {
    final debit = bankAccounts.where((a) => a.type == AccountType.checking || a.type == AccountType.cash).toList();
    final credit = bankAccounts.where((a) => a.type == AccountType.creditCard).toList();
    final invest = bankAccounts.where((a) => a.type == AccountType.yieldVault || a.type == AccountType.investment).toList();
    final savings = bankAccounts.where((a) => a.type == AccountType.savings).toList();

    final List<Widget> widgets = [];

    if (debit.isNotEmpty) {
      final sum = debit.fold<double>(0.0, (s, a) => s + a.balance);
      widgets.add(_buildSubHeader('Cuentas de débito', debit.length, sum, AppTheme.electricCyan));
      widgets.addAll(debit.map((a) => _buildAccountCard(context, a, showTypeBadge: false)));
      widgets.add(const SizedBox(height: 8));
    }

    if (credit.isNotEmpty) {
      final sum = credit.fold<double>(0.0, (s, a) => s - a.balance);
      widgets.add(_buildSubHeader('Tarjetas de crédito', credit.length, sum, AppTheme.alertCoral));
      widgets.addAll(credit.map((a) => _buildCreditCardCard(context, a, showTypeBadge: false)));
      widgets.add(const SizedBox(height: 8));
    }

    if (invest.isNotEmpty) {
      final sum = invest.fold<double>(0.0, (s, a) => s + a.balance);
      widgets.add(_buildSubHeader('Inversiones y rendimientos', invest.length, sum, AppTheme.purpleGlow));
      widgets.addAll(invest.map((a) => _buildAccountCard(context, a, showTypeBadge: false)));
      widgets.add(const SizedBox(height: 8));
    }

    if (savings.isNotEmpty) {
      final sum = savings.fold<double>(0.0, (s, a) => s + a.balance);
      widgets.add(_buildSubHeader('Bolsas de ahorro', savings.length, sum, AppTheme.emeraldGreen));
      widgets.addAll(savings.map((a) => _buildAccountCard(context, a, showTypeBadge: false)));
      widgets.add(const SizedBox(height: 8));
    }

    final vouchers = bankAccounts.where((a) => a.type == AccountType.vouchers).toList();
    if (vouchers.isNotEmpty) {
      final sum = vouchers.fold<double>(0.0, (s, a) => s + a.balance);
      widgets.add(_buildSubHeader('Vales y beneficios', vouchers.length, sum, AppTheme.amberGold));
      widgets.addAll(vouchers.map((a) => _buildAccountCard(context, a, showTypeBadge: false)));
      widgets.add(const SizedBox(height: 8));
    }

    final funds = bankAccounts.where((a) => a.type == AccountType.savingsFund).toList();
    if (funds.isNotEmpty) {
      final sum = funds.fold<double>(0.0, (s, a) => s + a.balance);
      widgets.add(_buildSubHeader('Fondo / Caja de ahorro', funds.length, sum, AppTheme.electricCyan));
      widgets.addAll(funds.map((a) => _buildAccountCard(context, a, showTypeBadge: false)));
    }

    return widgets;
  }

  Widget _buildSubHeader(String title, int count, double subtotal, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$title ($count)',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
          ),
          Text(
            CurrencyFormat.formatMXN(subtotal),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: subtotal < 0 ? AppTheme.alertCoral : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildAccountCard(BuildContext context, Account acc, {bool showTypeBadge = false}) {
    final hasYield = acc.annualYieldRate > 0;
    final hasGoal = acc.type == AccountType.savings && acc.savingsGoal > 0;
    final isCompact = MediaQuery.sizeOf(context).width < 520;
    final accColor = acc.color;

    return InkWell(
      onTap: () => _openAccountForm(context, acc),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: EdgeInsets.only(bottom: isCompact ? 6 : 8),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accColor.withOpacity(0.35)),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: accColor),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 12 : 14,
                    vertical: isCompact ? 10 : 14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsets.only(right: 6),
                                      decoration: BoxDecoration(
                                        color: accColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    Flexible(
                                      child: Text(
                                        acc.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: isCompact ? 13.5 : 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    if (showTypeBadge) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.surface,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          _typeBadge(acc.type),
                                          style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (!showTypeBadge) ...[
                                  const SizedBox(height: 2),
                                  Text(acc.institution, style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                                ],
                                if (acc.purpose == AccountPurpose.debtPayment ||
                                    acc.purpose == AccountPurpose.fixedExpenses) ...[
                                  const SizedBox(height: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (acc.purpose == AccountPurpose.debtPayment
                                              ? AppTheme.electricCyan
                                              : AppTheme.amberGold)
                                          .withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      acc.purpose == AccountPurpose.debtPayment
                                          ? 'Destinada a Tarjetas'
                                          : 'Destinada a Gastos Fijos',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: acc.purpose == AccountPurpose.debtPayment
                                            ? AppTheme.electricCyan
                                            : AppTheme.amberGold,
                                      ),
                                    ),
                                  ),
                                ],
                                if (hasYield) ...[
                                  const SizedBox(height: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.purpleGlow.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Tasa: ${CurrencyFormat.formatRate(acc.annualYieldRate)} anual (+${CurrencyFormat.formatMXN(acc.monthlyYieldGenerated, includeDecimals: false)}/mes)',
                                      style: const TextStyle(fontSize: 10.5, color: AppTheme.purpleGlow, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                                if (!acc.includeInGeneralFinances ||
                                    acc.allowedCategories.isNotEmpty ||
                                    acc.restrictionNote.isNotEmpty) ...[
                                  const SizedBox(height: 5),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      if (!acc.includeInGeneralFinances)
                                        _buildTagChip('Excluida de Margen Libre', AppTheme.amberGold),
                                      if (acc.restrictionNote.isNotEmpty)
                                        _buildTagChip(acc.restrictionNote, AppTheme.electricCyan),
                                      if (acc.allowedCategories.isNotEmpty)
                                        _buildTagChip('Cubre: ${acc.allowedCategories.join(", ")}', AppTheme.emeraldGreen),
                                    ],
                                  ),
                                ],
                                if (acc.type == AccountType.savingsFund ||
                                    acc.releaseDate != null ||
                                    acc.contributionMultiplier != 1.0) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Al liberar${acc.releaseDate != null ? " (${acc.releaseDate!.day}/${acc.releaseDate!.month}/${acc.releaseDate!.year})" : ""}: ${CurrencyFormat.formatMXN(acc.projectedReleaseAmount)} (${acc.contributionMultiplier == acc.contributionMultiplier.roundToDouble() ? acc.contributionMultiplier.toStringAsFixed(0) : acc.contributionMultiplier}×)',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.electricCyan,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      InkWell(
                                        onTap: () => _showContributionDialog(context, acc),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppTheme.emeraldGreen.withOpacity(0.16),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AppTheme.emeraldGreen.withOpacity(0.45)),
                                          ),
                                          child: const Text(
                                            '+ Aportación',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.emeraldGreen),
                                          ),
                                        ),
                                      ),
                                      if (acc.balance > 0)
                                        InkWell(
                                          onTap: () => _showReleaseFundDialog(context, acc),
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppTheme.electricCyan.withOpacity(0.16),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: AppTheme.electricCyan.withOpacity(0.45)),
                                            ),
                                            child: const Text(
                                              'Liberar a cuenta',
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.electricCyan),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            CurrencyFormat.formatMXN(acc.balance),
                            style: TextStyle(
                              fontSize: isCompact ? 14 : 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      if (hasGoal) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Meta: ${CurrencyFormat.formatMXN(acc.savingsGoal, includeDecimals: false)}',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                            Text(
                              '${(acc.goalProgress * 100).toStringAsFixed(0)}%',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: accColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: acc.goalProgress,
                            minHeight: 5,
                            backgroundColor: AppTheme.surface,
                            valueColor: AlwaysStoppedAnimation<Color>(accColor),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreditCardCard(BuildContext context, Account acc, {bool showTypeBadge = false}) {
    final now = DateTime.now();
    final daysToCutoff = acc.cutoffDay > now.day ? (acc.cutoffDay - now.day) : (30 - now.day + acc.cutoffDay);
    final monthlyDue = widget.provider.getCardMonthlyPaymentDue(acc.id);
    final plansCount = widget.provider.getPlansForCard(acc.id).where((p) => !p.isCompleted).length;
    final isCompact = MediaQuery.sizeOf(context).width < 520;
    final accColor = acc.color;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreditCardDetailScreen(provider: widget.provider, cardId: acc.id),
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: EdgeInsets.only(bottom: isCompact ? 6 : 8),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accColor.withOpacity(0.35)),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: accColor),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 12 : 14,
                    vertical: isCompact ? 10 : 14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: accColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    acc.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: isCompact ? 13.5 : 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                if (showTypeBadge) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.alertCoral.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text('Crédito', style: TextStyle(fontSize: 10, color: AppTheme.alertCoral)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            CurrencyFormat.formatMXN(acc.balance),
                            style: TextStyle(
                              fontSize: isCompact ? 14 : 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.alertCoral,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Pago del mes: ${CurrencyFormat.formatMXN(monthlyDue)}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.electricCyan),
                          ),
                          if (plansCount > 0)
                            Text(
                              '$plansCount plan(es) a meses',
                              style: const TextStyle(fontSize: 11, color: AppTheme.amberGold),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Límite: ${CurrencyFormat.formatMXN(acc.creditLimit, includeDecimals: false)} • Corte: Día ${acc.cutoffDay} (en $daysToCutoff días) • Toca para ver MSI / Edo. Cta.',
                        style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTagChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  void _showContributionDialog(BuildContext context, Account acc) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: Text('Confirmar aportación • ${acc.name}',
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Registra lo descontado en tu recibo de nómina. No se restará de tu cuenta bancaria.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                prefixText: '\$ ',
                labelText: 'Monto aportado (MXN)',
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.emeraldGreen,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              final amt = double.tryParse(ctrl.text.replaceAll(',', '').trim()) ?? 0.0;
              Navigator.pop(ctx);
              if (amt > 0) {
                await widget.provider.addSavingsFundContribution(acc.id, amt);
              }
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  void _showReleaseFundDialog(BuildContext context, Account acc) {
    final targets = widget.provider.accounts
        .where((a) => a.id != acc.id && a.type != AccountType.creditCard)
        .toList();
    String? selectedTarget = targets.any((a) => a.id == acc.releaseTargetAccountId)
        ? acc.releaseTargetAccountId
        : (targets.isNotEmpty ? targets.first.id : null);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.card,
          title: Text('Liberar ${acc.name}',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Aportado: ${CurrencyFormat.formatMXN(acc.balance)}\nTotal a depositar (${acc.contributionMultiplier}×): ${CurrencyFormat.formatMXN(acc.projectedReleaseAmount)}',
                style: const TextStyle(fontSize: 13, color: Colors.white, height: 1.4),
              ),
              const SizedBox(height: 12),
              if (targets.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: selectedTarget,
                  dropdownColor: AppTheme.card,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Depositar en cuenta',
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: targets
                      .map((a) => DropdownMenuItem(
                            value: a.id,
                            child: Text('${a.name} (${a.institution})'),
                          ))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedTarget = v),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.electricCyan,
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await widget.provider.releaseSavingsFund(acc.id, targetAccountId: selectedTarget);
              },
              child: const Text('Liberar y Depositar'),
            ),
          ],
        ),
      ),
    );
  }
}
