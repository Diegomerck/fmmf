import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_format.dart';
import '../../models/account.dart';
import '../../models/transaction.dart';
import '../../providers/finance_provider.dart';
import 'widgets/confirm_delete_dialog.dart';
import 'widgets/pending_incomes_section.dart';

enum _MovementsViewMode { chronological, byAccount, entryOrder }

class TransactionsTab extends StatefulWidget {
  final FinanceProvider provider;

  const TransactionsTab({super.key, required this.provider});

  @override
  State<TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends State<TransactionsTab> {
  String _filter = 'Todos'; // 'Todos', 'Gastos', 'Ingresos', 'Transferencias', 'Rendimientos'
  String? _selectedAccountId;
  _MovementsViewMode _viewMode = _MovementsViewMode.chronological;
  String _searchQuery = '';

  IconData _accountIcon(AccountType? type) {
    return switch (type) {
      AccountType.creditCard => Icons.credit_card,
      AccountType.savings => Icons.savings_outlined,
      AccountType.yieldVault => Icons.trending_up,
      AccountType.investment => Icons.show_chart,
      AccountType.cash => Icons.payments_outlined,
      AccountType.checking || null => Icons.account_balance,
    };
  }

  Widget _accountSticker(Account? acc, {String fallback = 'Cuenta'}) {
    final color = acc?.color ?? AppTheme.electricCyan;
    final label = acc?.name ?? fallback;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.55), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_accountIcon(acc?.type), size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovementCard(Transaction tx, Map<String, Account> accountMap, {bool isCompact = false}) {
    final isPositive = tx.type == MovementType.income || tx.type == MovementType.yieldAccrual;
    final srcAcc = accountMap[tx.accountId];
    final targetAcc = tx.targetAccountId != null ? accountMap[tx.targetAccountId!] : null;
    final accentColor = srcAcc?.color ?? AppTheme.electricCyan;
    final dateStr = isCompact
        ? '${tx.date.day}/${tx.date.month}/${tx.date.year % 100}'
        : '${tx.date.day}/${tx.date.month}/${tx.date.year}';

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(isCompact ? 11 : 14),
        border: Border.all(color: accentColor.withOpacity(0.32)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: accentColor),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 9 : 12,
                  vertical: isCompact ? 7 : 10,
                ),
                child: Row(
                  children: [
                    Container(
                      width: isCompact ? 26 : 32,
                      height: isCompact ? 26 : 32,
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPositive
                            ? Icons.arrow_downward_rounded
                            : (tx.type == MovementType.transfer
                                ? Icons.swap_horiz_rounded
                                : Icons.arrow_upward_rounded),
                        size: isCompact ? 13 : 15,
                        color: isPositive
                            ? AppTheme.emeraldGreen
                            : (tx.type == MovementType.transfer ? accentColor : AppTheme.alertCoral),
                      ),
                    ),
                    SizedBox(width: isCompact ? 8 : 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: isCompact ? 12.5 : 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: isCompact ? 2 : 4),
                          Wrap(
                            spacing: 5,
                            runSpacing: 3,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _accountSticker(srcAcc),
                              if (targetAcc != null) ...[
                                const Icon(Icons.arrow_forward, size: 10, color: AppTheme.textMuted),
                                _accountSticker(targetAcc),
                              ],
                              Text(
                                isCompact ? dateStr : '${tx.category} • $dateStr',
                                style: TextStyle(
                                  fontSize: isCompact ? 10 : 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          if (!isCompact && tx.note != null && tx.note!.trim().isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              tx.note!.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${isPositive ? "+" : (tx.type == MovementType.transfer ? "" : "-")}${CurrencyFormat.formatMXN(tx.amount)}',
                      style: TextStyle(
                        fontSize: isCompact ? 12.5 : 14,
                        fontWeight: FontWeight.w700,
                        color: isPositive ? AppTheme.emeraldGreen : Colors.white,
                      ),
                    ),
                    SizedBox(width: isCompact ? 2 : 4),
                    IconButton(
                      icon: Icon(Icons.delete_outline, size: isCompact ? 16 : 18, color: AppTheme.textMuted),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(
                        minWidth: isCompact ? 26 : 36,
                        minHeight: isCompact ? 26 : 36,
                      ),
                      tooltip: 'Eliminar movimiento',
                      onPressed: () async {
                        final confirmed = await showConfirmDeleteDialog(
                          context,
                          title: '¿Eliminar movimiento?',
                          message:
                              'Se eliminará "${tx.title}" (${CurrencyFormat.formatMXN(tx.amount)}) y se revertirá su efecto en el saldo de la cuenta.',
                        );
                        if (confirmed) {
                          await widget.provider.deleteTransaction(tx.id);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accounts = widget.provider.accounts;
    final accountMap = {for (final a in accounts) a.id: a};

    final filtered = widget.provider.transactions.where((tx) {
      if (_filter == 'Gastos' && tx.type != MovementType.expense) return false;
      if (_filter == 'Ingresos' && tx.type != MovementType.income) return false;
      if (_filter == 'Transferencias' && tx.type != MovementType.transfer) return false;
      if (_filter == 'Rendimientos' && tx.type != MovementType.yieldAccrual) return false;

      if (_selectedAccountId != null &&
          tx.accountId != _selectedAccountId &&
          tx.targetAccountId != _selectedAccountId) {
        return false;
      }

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final accName = accountMap[tx.accountId]?.name.toLowerCase() ?? '';
        return tx.title.toLowerCase().contains(q) ||
            tx.category.toLowerCase().contains(q) ||
            accName.contains(q);
      }
      return true;
    }).toList();

    if (_viewMode == _MovementsViewMode.chronological) {
      filtered.sort((a, b) => b.date.compareTo(a.date));
    }

    // Group by account if _viewMode == byAccount
    final Map<String, List<Transaction>> byAccountGroups = {};
    if (_viewMode == _MovementsViewMode.byAccount) {
      final sortedCopy = [...filtered]..sort((a, b) => b.date.compareTo(a.date));
      for (final tx in sortedCopy) {
        byAccountGroups.putIfAbsent(tx.accountId, () => []).add(tx);
      }
    }

    final isCompact = MediaQuery.sizeOf(context).width < 520;

    return Padding(
      padding: EdgeInsets.fromLTRB(isCompact ? 10 : 16, isCompact ? 10 : 16, isCompact ? 10 : 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Bar
          TextField(
            style: TextStyle(color: Colors.white, fontSize: isCompact ? 13 : 14),
            decoration: InputDecoration(
              isDense: isCompact,
              hintText: 'Buscar por concepto, categoría o cuenta...',
              hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: isCompact ? 12 : 13),
              prefixIcon: Icon(Icons.search, color: AppTheme.textMuted, size: isCompact ? 18 : 20),
              filled: true,
              fillColor: AppTheme.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              contentPadding: EdgeInsets.symmetric(vertical: isCompact ? 8 : 12),
            ),
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
          ),
          SizedBox(height: isCompact ? 7 : 10),

          // View Mode & Type Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _viewChip('Cronológica', Icons.schedule, _MovementsViewMode.chronological, isCompact: isCompact),
                const SizedBox(width: 6),
                _viewChip('Por Cuenta', Icons.account_balance_wallet_outlined, _MovementsViewMode.byAccount, isCompact: isCompact),
                const SizedBox(width: 6),
                _viewChip('Registro', Icons.history, _MovementsViewMode.entryOrder, isCompact: isCompact),
                const SizedBox(width: 10),
                Container(width: 1, height: 20, color: AppTheme.border),
                const SizedBox(width: 10),
                ...['Todos', 'Gastos', 'Ingresos', 'Transferencias', 'Rendimientos'].map((f) {
                  final isSelected = _filter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      visualDensity: isCompact ? VisualDensity.compact : VisualDensity.standard,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      label: Text(f),
                      selected: isSelected,
                      selectedColor: AppTheme.emeraldGreen.withOpacity(0.25),
                      backgroundColor: AppTheme.card,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppTheme.textSecondary,
                        fontSize: isCompact ? 11 : 11.5,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                      ),
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  );
                }),
              ],
            ),
          ),

          if (accounts.isNotEmpty) ...[
            SizedBox(height: isCompact ? 6 : 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    visualDensity: isCompact ? VisualDensity.compact : VisualDensity.standard,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    label: const Text('Todas'),
                    selected: _selectedAccountId == null,
                    selectedColor: AppTheme.electricCyan.withOpacity(0.2),
                    backgroundColor: AppTheme.card,
                    labelStyle: TextStyle(
                      fontSize: isCompact ? 10.5 : 11,
                      color: _selectedAccountId == null ? Colors.white : AppTheme.textSecondary,
                    ),
                    onSelected: (_) => setState(() => _selectedAccountId = null),
                  ),
                  const SizedBox(width: 6),
                  ...accounts.map((acc) {
                    final isSelected = _selectedAccountId == acc.id;
                    final c = acc.color;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        visualDensity: isCompact ? VisualDensity.compact : VisualDensity.standard,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        avatar: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                        ),
                        label: Text(acc.name),
                        selected: isSelected,
                        selectedColor: c.withOpacity(0.22),
                        backgroundColor: AppTheme.card,
                        side: BorderSide(color: isSelected ? c : AppTheme.border),
                        labelStyle: TextStyle(
                          fontSize: isCompact ? 10.5 : 11,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                          color: isSelected ? Colors.white : AppTheme.textSecondary,
                        ),
                        onSelected: (_) => setState(
                          () => _selectedAccountId = isSelected ? null : acc.id,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
          SizedBox(height: isCompact ? 8 : 12),

          // Pending Incomes to Confirm
          PendingIncomesSection(provider: widget.provider),

          // Transactions List
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text('No hay movimientos que coincidan.', style: TextStyle(color: AppTheme.textMuted)),
                  )
                : _viewMode == _MovementsViewMode.byAccount
                    ? ListView(
                        padding: const EdgeInsets.only(bottom: 76),
                        children: byAccountGroups.entries.map((entry) {
                          final acc = accountMap[entry.key];
                          final c = acc?.color ?? AppTheme.electricCyan;
                          final groupTxs = entry.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: c.withOpacity(0.35)),
                            ),
                            child: Theme(
                              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                initiallyExpanded: true,
                                tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                                childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                                iconColor: c,
                                collapsedIconColor: AppTheme.textSecondary,
                                title: Row(
                                  children: [
                                    _accountSticker(acc),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${groupTxs.length} mov.',
                                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                                children: groupTxs
                                    .map((tx) => Padding(
                                          padding: EdgeInsets.only(bottom: isCompact ? 6 : 8),
                                          child: _buildMovementCard(tx, accountMap, isCompact: isCompact),
                                        ))
                                    .toList(),
                              ),
                            ),
                          );
                        }).toList(),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 76),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => SizedBox(height: isCompact ? 6 : 8),
                        itemBuilder: (context, idx) => _buildMovementCard(
                          filtered[idx],
                          accountMap,
                          isCompact: isCompact,
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _viewChip(String label, IconData icon, _MovementsViewMode mode, {bool isCompact = false}) {
    final isSelected = _viewMode == mode;
    return ChoiceChip(
      visualDensity: isCompact ? VisualDensity.compact : VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      avatar: Icon(icon, size: 13, color: isSelected ? Colors.black : AppTheme.electricCyan),
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.electricCyan,
      backgroundColor: AppTheme.card,
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : AppTheme.textSecondary,
        fontSize: isCompact ? 11 : 11.5,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
      ),
      onSelected: (_) => setState(() => _viewMode = mode),
    );
  }
}
